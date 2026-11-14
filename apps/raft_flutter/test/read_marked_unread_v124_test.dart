import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/mark_unread_outcome.dart';
import 'package:raft_flutter/features/marked_unread_sync.dart';
import 'package:raft_flutter/data/workspace_controller.dart';

/// Web v1.24 marked-unread (store/markedUnreadStore.ts, readStateSync.ts):
/// Mark as Unread with nothing countable marks the conversation with no
/// number, ordered by read-state version against reads from every carrier.
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

Map<String, dynamic> _snapshot(int version, {bool marked = false}) => {
  'channels': {
    'c': {
      'unreadCount': 0,
      'readState': {
        'kind': 'present',
        'maxReadSeq': '2',
        'readStateVersion': version,
        if (marked) 'markedUnread': true,
      },
    },
  },
};

void _readState(_Client c, int version, {bool marked = false}) => c.stream.add(
  RaftEvent('read_state:updated', {
    'serverId': 's',
    'scopeId': 'c',
    'maxReadSeq': 2,
    'readStateVersion': version,
    if (marked) 'markedUnread': true,
  }),
);

void main() {
  test('resolveMarkUnreadOutcome follows the server outcome, else infers it as Web did before it', () {
    expect(
      resolveMarkUnreadOutcome({'outcome': 'marked', 'unreadCount': 3}),
      MarkUnreadOutcome.marked,
    );
    expect(
      resolveMarkUnreadOutcome({'unreadCount': 2}),
      MarkUnreadOutcome.counted,
    );
    expect(
      resolveMarkUnreadOutcome({'unreadCount': 0, 'markedUnread': true}),
      MarkUnreadOutcome.marked,
    );
    expect(
      resolveMarkUnreadOutcome({'unreadCount': 0}),
      MarkUnreadOutcome.nothing,
    );
    expect(resolveMarkUnreadOutcome(null), MarkUnreadOutcome.nothing);
  });

  test('[BP-READ-033] a marked answer shows the mark with no count and keeps the open conversation unread', () async {
    final c = _Client();
    final w = await _open(c);
    await w.selectChannel(w.channels.single);
    c.unreadAnswer = {
      'ok': true,
      'unreadCount': 0,
      'maxReadSeq': 2,
      'readStateVersion': 7,
      'markedUnread': true,
      'outcome': 'marked',
    };
    c.unreadSnapshot = _snapshot(7, marked: true);
    await w.conversationReads.markUnread('c');
    expect(w.conversationReads.unread['c'], 0);
    expect(w.conversationReads.marks.contains('c'), isTrue);
    // Source markUnread: `outcome !== "nothing"` keeps the manual-unread skip.
    expect(w.conversationReads.queue.skipsInitialAutoRead('c'), isTrue);
  });

  test('[BP-READ-005] an older server (no outcome, no mark) leaves the conversation read and unmarked', () async {
    final c = _Client();
    final w = await _open(c);
    await w.selectChannel(w.channels.single);
    c.unreadAnswer = {'unreadCount': 0, 'readStateVersion': 4, 'maxReadSeq': 2};
    c.unreadSnapshot = _snapshot(4);
    await w.conversationReads.markUnread('c');
    expect(w.conversationReads.marks.contains('c'), isFalse);
    expect(w.conversationReads.queue.skipsInitialAutoRead('c'), isFalse);
  });

  test('[BP-READ-029] snapshots order the mark by version: the same version only adds it, a newer one replaces it, absent clears it', () async {
    final c = _Client();
    final w = await _open(c);
    c.unreadSnapshot = _snapshot(5, marked: true);
    await w.refreshUnread();
    expect(w.conversationReads.marks.contains('c'), isTrue);
    // A carrier that omits the flag at the same version does not clear it.
    c.unreadSnapshot = _snapshot(5);
    await w.refreshUnread();
    expect(w.conversationReads.marks.contains('c'), isTrue);
    // A newer read state without the flag (a read elsewhere) clears it.
    c.unreadSnapshot = _snapshot(6);
    await w.refreshUnread();
    expect(w.conversationReads.marks.contains('c'), isFalse);
    // An older answer cannot bring it back.
    c.unreadSnapshot = _snapshot(5, marked: true);
    await w.refreshUnread();
    expect(w.conversationReads.marks.contains('c'), isFalse);
    c.unreadSnapshot = _snapshot(8, marked: true);
    await w.refreshUnread();
    expect(w.conversationReads.marks.contains('c'), isTrue);
    c.unreadSnapshot = {
      'channels': {
        'c': {
          'unreadCount': 0,
          'readState': {'kind': 'absent'},
        },
      },
    };
    await w.refreshUnread();
    expect(w.conversationReads.marks.contains('c'), isFalse);
  });

  test('[BP-READ-030] read_state:updated carries the mark; a later read without it clears it, a stale one is ignored', () async {
    final c = _Client();
    final w = await _open(c);
    MarkedUnreadSync.of(w);
    var notified = 0;
    w.addListener(() => notified++);
    _readState(c, 9, marked: true);
    expect(w.conversationReads.marks.contains('c'), isTrue);
    expect(notified, greaterThan(0));
    _readState(c, 8);
    expect(w.conversationReads.marks.contains('c'), isTrue);
    _readState(c, 10);
    expect(w.conversationReads.marks.contains('c'), isFalse);
    // Another server's frame is not this server's mark.
    c.stream.add(
      RaftEvent('read_state:updated_bulk', {
        'serverId': 'other',
        'scopes': [
          {
            'scopeId': 'c',
            'maxReadSeq': 2,
            'readStateVersion': 11,
            'markedUnread': true,
          },
        ],
      }),
    );
    expect(w.conversationReads.marks.contains('c'), isFalse);
    c.stream.add(
      RaftEvent('read_state:updated_bulk', {
        'serverId': 's',
        'scopes': [
          {
            'scopeId': 'c',
            'maxReadSeq': 2,
            'readStateVersion': 11,
            'markedUnread': true,
          },
        ],
      }),
    );
    expect(w.conversationReads.marks.contains('c'), isTrue);
  });

  test('[BP-READ-006] a read write going out clears the mark at once (Source flushPendingRead)', () async {
    final c = _Client()..holdReads = true;
    final w = await _open(c);
    c.unreadSnapshot = _snapshot(5, marked: true);
    await w.refreshUnread();
    expect(w.conversationReads.marks.contains('c'), isTrue);
    final open = w.selectChannel(w.channels.single);
    await _settle();
    expect(c.reads, 1);
    expect(w.conversationReads.marks.contains('c'), isFalse);
    c.pendingReads.single.complete({'maxReadSeq': 2, 'readStateVersion': 6});
    await open;
    expect(w.conversationReads.marks.contains('c'), isFalse);
  });

  test('[BP-READ-032] a read-all receipt clears the mark', () async {
    final c = _Client();
    final w = await _open(c);
    c.unreadSnapshot = _snapshot(5, marked: true);
    await w.refreshUnread();
    expect(
      w.conversationReads.acceptReadAllAck(
        'c',
        {'seq': 2, 'maxReadSeq': 2, 'readStateVersion': 6},
        serverId: 's',
        principalId: 'alice',
      ),
      isTrue,
    );
    expect(w.conversationReads.marks.contains('c'), isFalse);
  });
}
