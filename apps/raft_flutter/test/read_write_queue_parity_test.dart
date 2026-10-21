import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/read_write_queue.dart';
import 'package:raft_flutter/data/workspace_controller.dart';

/// Source messageStore read write path: the queued read cursor (retry,
/// coalescing), the 30 s local-read floor, the manual-unread skip and the
/// "mark as unread" answer held until a snapshot catches up.
class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://public-fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice', 'displayName': 'Alice'});
    selectServer('s');
  }
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  final calls = <String>[];
  final readBodies = <dynamic>[];
  final pendingReads = <Completer<dynamic>>[];
  bool holdReads = false, failReads = false;
  dynamic unreadSnapshot = {
    'channels': {'c': 3},
  };
  dynamic unreadAnswer = {
    'unreadCount': 1,
    'readStateVersion': 5,
    'maxReadSeq': 0,
  };
  List<Map<String, dynamic>> pageRows = [message('m', 1), message('n', 2)];
  final channelRows = [
    RaftChannel({'id': 'c', 'name': 'design', 'joined': true}),
  ];

  static Map<String, dynamic> message(String id, int seq) => {
    'id': id,
    'channelId': 'c',
    'serverId': 's',
    'seq': '$seq',
    'content': 'Public fixture $id',
    'senderId': 'other',
    'senderType': 'user',
    'createdAt': '2026-10-08T00:00:00Z',
  };

  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  void connect() {}
  @override
  void joinChannel(String id) {}
  @override
  Future<List<RaftRecord>> servers() async => [
    RaftRecord({'id': 's', 'name': 'Fixture', 'role': 'owner'}),
  ];
  @override
  Future<List<RaftChannel>> channels({bool dm = false}) async =>
      dm ? [] : channelRows;
  @override
  Future<Map<String, dynamic>> messagePage(
    String id, {
    int limit = 50,
    BigInt? before,
    BigInt? after,
  }) async => {'messages': pageRows, 'threadSummariesByParentMessageId': {}};

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    calls.add('GET:$path');
    if (path == '/channels/unread') return unreadSnapshot;
    if (path.endsWith('/sidebar-order')) {
      return {'pinned': [], 'customSections': [], 'sectionPlacements': []};
    }
    if (path.endsWith('/setup-projection')) {
      return {'phase': 'complete', 'surface': 'complete', 'blocksChat': false};
    }
    if (path == '/auth/providers') return {'providers': []};
    if (path == '/auth/identities') {
      return {'passwordConfigured': true, 'identities': []};
    }
    return [];
  }

  @override
  Future<dynamic> post(String path, {dynamic data}) async {
    calls.add('POST:$path');
    if (path.endsWith('/read')) {
      readBodies.add(data['seq']);
      if (holdReads) {
        final c = Completer<dynamic>();
        pendingReads.add(c);
        return c.future;
      }
      if (failReads) throw const RaftApiException('boom', status: 500);
      return {'maxReadSeq': int.parse('${data['seq']}'), 'readStateVersion': 3};
    }
    if (path.endsWith('/unread')) return unreadAnswer;
    if (path == '/feature-flags/evaluate') return {'evaluations': []};
    return {};
  }

  int get reads => readBodies.length;
  int get snapshots => calls.where((c) => c == 'GET:/channels/unread').length;
}

Future<WorkspaceController> _open(_Client c) async {
  final w = WorkspaceController(c, mobileNavigation: true);
  await w.bootstrap();
  w.setForeground(true);
  addTearDown(() async {
    w.dispose();
    await c.stream.close();
  });
  return w;
}

Future<void> _settle() async {
  for (var i = 0; i < 4; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('[BP-READ-006] a read the network dropped is kept and sent again with the same cursor on the next refresh', () async {
    final c = _Client();
    final w = await _open(c);
    c.failReads = true;
    await w.selectChannel(w.channels.single);
    expect(c.readBodies, ['2']);
    // Local clear does not depend on the POST (Source markCurrentChannelRead).
    expect(w.conversationReads.unread['c'], 0);
    expect(w.conversationReads.queue.pending('c')?.seq, BigInt.two);
    c.failReads = false;
    await w.refreshUnread();
    expect(c.readBodies, ['2', '2']);
    expect(w.conversationReads.queue.pending('c'), isNull);
    // The retry went out before the snapshot was requested.
    final calls = c.calls;
    expect(
      calls.lastIndexOf('POST:/channels/c/read') <
          calls.lastIndexOf('GET:/channels/unread'),
      isTrue,
    );
  });

  test('[BP-READ-007] one read POST per conversation is in flight; a newer cursor goes out once, afterwards', () async {
    final q = ReadWriteQueue();
    PendingRead read(int seq) => PendingRead(
      seq: BigInt.from(seq),
      wireSeq: seq,
      origin: 'o',
      principal: 'p',
      serverId: 's',
      generation: 0,
      window: 0,
    );
    final sent = <BigInt>[], gates = <Completer<bool>>[];
    Future<bool> send(PendingRead r) {
      sent.add(r.seq);
      final gate = Completer<bool>();
      gates.add(gate);
      return gate.future;
    }

    q.remember('c', read(5));
    final first = q.flush('c', send);
    final again = q.flush('c', send);
    expect(identical(first, again), isTrue);
    q.remember('c', read(9));
    final third = q.flush('c', send);
    expect(identical(first, third), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(sent, [BigInt.from(5)]);
    gates.removeAt(0).complete(true);
    await Future<void>.delayed(Duration.zero);
    // Exactly one trailing POST, with the final cursor.
    expect(sent, [BigInt.from(5), BigInt.from(9)]);
    gates.removeAt(0).complete(true);
    await first;
    expect(sent, hasLength(2));
    expect(q.pending('c'), isNull);
    expect(q.inFlight('c'), isNull);
  });

  test(
    '[BP-READ-007] two reads of the same window share one request',
    () async {
      final c = _Client()..holdReads = true;
      final w = await _open(c);
      final open = w.selectChannel(w.channels.single);
      await _settle();
      final second = w.markRead('c');
      await _settle();
      expect(c.reads, 1);
      c.holdReads = false;
      c.pendingReads.single.complete({'maxReadSeq': 2, 'readStateVersion': 3});
      await open;
      await second;
      expect(c.reads, 1);
      expect(w.conversationReads.queue.pending('c'), isNull);
    },
  );

  test('[BP-READ-008] for 30 s after a local read a stale snapshot cannot repaint the cleared count', () async {
    final c = _Client();
    final w = await _open(c);
    await w.selectChannel(w.channels.single);
    expect(w.conversationReads.unread['c'], 0);
    c.unreadSnapshot = {
      'channels': {
        'c': {
          'unreadCount': 3,
          'hasMention': true,
          'hasNew': false,
          'readState': {
            'kind': 'present',
            'maxReadSeq': '1',
            'readStateVersion': 2,
          },
        },
      },
    };
    await w.refreshUnread();
    expect(w.conversationReads.unread['c'], 0);
    expect(w.conversationReads.mentions, isEmpty);
    // A live message past the read cursor lifts the floor.
    w.conversationReads.setTimelineAtBottom('c', false);
    c.stream.add(RaftEvent('message:new', _Client.message('later', 3)));
    await _settle();
    await w.refreshUnread();
    expect(w.conversationReads.unread['c'], 3);
  });

  test('[BP-READ-008] the floor is 30 s long, never lowers, and ends at a newer message', () {
    var now = DateTime(2026, 10, 21, 12);
    final q = ReadWriteQueue(now: () => now);
    PendingRead read(int seq) => PendingRead(
      seq: BigInt.from(seq),
      wireSeq: seq,
      origin: 'o',
      principal: 'p',
      serverId: 's',
      generation: 0,
      window: 0,
    );
    q.remember('c', read(5));
    expect(q.isSuppressed('c'), isTrue);
    now = now.add(const Duration(seconds: 29));
    expect(q.isSuppressed('c'), isTrue);
    q.remember('c', read(4));
    expect(q.pending('c')?.seq, BigInt.from(5));
    now = now.add(const Duration(seconds: 2));
    expect(q.isSuppressed('c'), isTrue, reason: 'the second read extended it');
    now = now.add(const Duration(seconds: 30));
    expect(q.isSuppressed('c'), isFalse);
    q.remember('c', read(9));
    q.forgetSuppressionIfNewer('c', BigInt.from(9));
    expect(q.isSuppressed('c'), isTrue);
    q.forgetSuppressionIfNewer('c', BigInt.from(10));
    expect(q.isSuppressed('c'), isFalse);
  });

  test('[BP-READ-005] a conversation marked unread while open is not read again by the open that follows, once', () async {
    final c = _Client();
    final w = await _open(c);
    await w.selectChannel(w.channels.single);
    expect(c.reads, 1);
    c.unreadSnapshot = {
      'channels': {'c': 1},
    };
    await w.conversationReads.markUnread('c');
    expect(w.conversationReads.unread['c'], 1);
    expect(w.conversationReads.queue.skipsInitialAutoRead('c'), isTrue);
    w.setSection('home');
    await w.selectChannel(w.channels.single);
    await _settle();
    expect(c.reads, 1, reason: 'the skip spared the second open');
    expect(w.conversationReads.unread['c'], 1);
    expect(w.conversationReads.queue.skipsInitialAutoRead('c'), isFalse);
    // Consumed once: the next open reads as usual.
    w.setSection('home');
    await w.selectChannel(w.channels.single);
    await _settle();
    expect(c.reads, 2);
    expect(w.conversationReads.unread['c'], 0);
  });

  test('[BP-READ-005] opening another conversation drops the skip', () async {
    final c = _Client();
    final w = await _open(c);
    c.channelRows.add(RaftChannel({'id': 'd', 'name': 'ops', 'joined': true}));
    await w.refreshChannels();
    await w.selectChannel(w.channels.first);
    await w.conversationReads.markUnread('c');
    expect(w.conversationReads.queue.skipsInitialAutoRead('c'), isTrue);
    await w.selectChannel(w.channels.last);
    expect(w.conversationReads.queue.skipsInitialAutoRead('c'), isFalse);
  });

  test('[BP-READ-033] mark as unread shows the server count, not an invented badge, and holds it until a snapshot catches up', () async {
    final c = _Client();
    final w = await _open(c);
    await w.selectChannel(w.channels.single);
    expect(w.conversationReads.unread['c'], 0);
    // No eligible message: the server answers 0 and no badge appears.
    c.unreadAnswer = {'unreadCount': 0, 'readStateVersion': 4, 'maxReadSeq': 2};
    c.unreadSnapshot = {
      'channels': {'c': 0},
    };
    await w.conversationReads.markUnread('c');
    expect(w.conversationReads.unread['c'], 0);
    // An eligible message: the answer's count shows even while the snapshot
    // still describes the older cursor.
    c.unreadAnswer = {'unreadCount': 2, 'readStateVersion': 6, 'maxReadSeq': 0};
    c.unreadSnapshot = {
      'channels': {
        'c': {
          'unreadCount': 0,
          'readState': {
            'kind': 'present',
            'maxReadSeq': '2',
            'readStateVersion': 4,
          },
        },
      },
    };
    await w.conversationReads.markUnread('c');
    expect(w.conversationReads.unread['c'], 2);
    // A snapshot at the new version replaces the held count.
    c.unreadSnapshot = {
      'channels': {
        'c': {
          'unreadCount': 2,
          'readState': {
            'kind': 'present',
            'maxReadSeq': '0',
            'readStateVersion': 6,
          },
        },
      },
    };
    await w.refreshUnread();
    expect(w.conversationReads.unread['c'], 2);
    expect(w.conversationReads.queue.receipt('c'), isNull);
  });

  test('[BP-READ-033] mark as unread settles a read already in flight first and drops the queued cursor', () async {
    final c = _Client()..holdReads = true;
    final w = await _open(c);
    final open = w.selectChannel(w.channels.single);
    await _settle();
    expect(c.reads, 1);
    final unread = w.conversationReads.markUnread('c');
    await _settle();
    expect(c.calls.where((x) => x == 'POST:/channels/c/unread'), isEmpty);
    expect(w.conversationReads.queue.pending('c'), isNull);
    c.pendingReads.single.complete({'maxReadSeq': 2, 'readStateVersion': 3});
    await unread;
    await open;
    expect(c.calls.where((x) => x == 'POST:/channels/c/unread'), hasLength(1));
    expect(
      c.calls.indexOf('POST:/channels/c/unread') >
          c.calls.indexOf('POST:/channels/c/read'),
      isTrue,
    );
  });

  test('[BP-READ-032] a read-all answer clears the row, drops the queued cursor and starts the 30 s floor', () async {
    final c = _Client()..failReads = true;
    final w = await _open(c);
    await w.selectChannel(w.channels.single);
    expect(w.conversationReads.queue.pending('c'), isNotNull);
    w.conversationReads.unread = {'c': 4};
    expect(
      w.conversationReads.acceptReadAllAck(
        'c',
        {'seq': 2, 'maxReadSeq': 2, 'readStateVersion': 9},
        serverId: 's',
        principalId: 'alice',
      ),
      isTrue,
    );
    expect(w.conversationReads.unread['c'], 0);
    expect(w.conversationReads.queue.pending('c'), isNull);
    c.unreadSnapshot = {
      'channels': {
        'c': {
          'unreadCount': 4,
          'readState': {
            'kind': 'present',
            'maxReadSeq': '1',
            'readStateVersion': 2,
          },
        },
      },
    };
    await w.refreshUnread();
    expect(w.conversationReads.unread['c'], 0);
  });
}
