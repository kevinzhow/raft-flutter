import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_cache.dart';
import 'package:raft_flutter/data/workspace_controller.dart';

RaftChannel _channel(
  String id, {
  bool joined = true,
  String type = 'channel',
}) => RaftChannel({
  'id': id,
  'name': id,
  'serverId': 's1',
  'type': type,
  'joined': joined,
});

Map<String, dynamic> _message(
  String id,
  String channel,
  Object seq, {
  String sender = 'bob',
  List<dynamic>? mentions,
}) => {
  'id': id,
  'channelId': channel,
  'serverId': 's1',
  'seq': seq,
  'senderType': 'user',
  'senderId': sender,
  'content': 'Public fixture $id',
  'createdAt': '2026-10-10T00:00:00Z',
  'mentions': ?mentions,
};

Map<String, dynamic> _frontier(int read, int version, int latest) => {
  'kind': 'present',
  'maxReadSeq': '$read',
  'readStateVersion': version,
  'latestActivity': {'seq': '$latest'},
};

class _Cache implements WorkspaceCache {
  final writes = <String>[];
  final saved = <String, dynamic>{};
  @override
  Future<dynamic> read(o, p, s, String kind, String id) async => null;
  @override
  Future<void> write(o, p, s, String kind, String id, value) async {
    writes.add(kind);
    saved[kind] = value;
  }

  @override
  Future<void> revokeChannel(o, p, s, String id) async {}
  @override
  Future<void> revokeServer(o, p, s) async {}
  @override
  Future<void> clearAccount(o, p) async {}
  @override
  Future<List<Map<String, dynamic>>> readTranslations(o, p, s) async => [];
  @override
  Future<void> writeTranslations(o, p, s, entries) async {}
  @override
  Future<void> close() async {}
}

class _Client extends RaftClient {
  _Client()
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice'});
    selectServer('s1');
  }
  final bus = StreamController<RaftEvent>.broadcast(sync: true);
  final calls = <String>[];
  dynamic unreadValue = {'channels': <String, dynamic>{}};
  bool failUnread = false;
  Future<void>? _closing;
  @override
  Stream<RaftEvent> get events => bus.stream;
  void emit(String name, dynamic value) => bus.add(RaftEvent(name, value));
  @override
  void connect() {}
  @override
  void joinChannel(String id) {}
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    calls.add('GET:$path');
    if (path == '/channels/unread') {
      if (failUnread) throw const RaftApiException('fixture', status: 500);
      return unreadValue;
    }
    return {};
  }

  @override
  Future<Map<String, dynamic>> messagePage(
    String id, {
    int limit = 50,
    BigInt? before,
    BigInt? after,
  }) async => {
    'messages': [_message('initial-$id', id, 1)],
    'threadSummariesByParentMessageId': {},
  };
  @override
  Future<dynamic> post(String path, {dynamic data}) async {
    calls.add('POST:$path');
    return {};
  }

  @override
  Future<void> dispose() => _closing ??= _close();
  Future<void> _close() async {
    await bus.close();
    await super.dispose();
  }
}

class _Workspace extends WorkspaceController {
  _Workspace(super.client, {required super.cache, super.presentationSource})
    : super(ownsClient: presentationSource == null, mobileNavigation: true);
  int notifications = 0, refreshes = 0, unreadCommands = 0, prefetches = 0;
  final reads = <String>[];
  @override
  void notifyListeners() {
    notifications++;
    super.notifyListeners();
  }

  @override
  Future<void> refreshUnread() {
    refreshes++;
    return super.refreshUnread();
  }

  @override
  void markUnreadLocally(String id) {
    unreadCommands++;
    super.markUnreadLocally(id);
  }

  @override
  Future<void> prefetchLikelyChannels({int limit = 6}) async => prefetches++;
  @override
  Future<void> markRead(String id) async => reads.add(id);
}

class _Fixture {
  _Fixture() {
    root = make();
    addTearDown(() async {
      for (final w in pages.reversed) {
        await w.flushCache();
        w.dispose();
      }
      await client.dispose();
    });
  }
  final client = _Client(), cache = _Cache();
  final pages = <_Workspace>[];
  late final _Workspace root;
  _Workspace make({WorkspaceController? source}) {
    final w = _Workspace(client, cache: cache, presentationSource: source);
    pages.add(w);
    w.server = RaftRecord({'id': 's1', 'role': 'owner'});
    w.channels = [
      _channel('c1'),
      _channel('c2'),
      _channel('public', joined: false),
    ];
    w.dms = [_channel('dm', type: 'dm')];
    w.channel = w.channels.first;
    if (source == null) w.messageDomain.ledger.switchServer('s1');
    w.notifyListeners();
    w.notifications = 0;
    return w;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('A1 collection assignments and mutations keep aliases without notifying or I/O', () async {
    final f = _Fixture(), w = f.root;
    final counts = <String, int>{'c2': 3},
        mentions = <String>{'c2'},
        flags = <String>{'public'};
    w.unread = counts;
    w.mentions = mentions;
    w.newFlags = flags;
    counts['dm'] = 4;
    mentions.add('dm');
    flags.add('c2');
    expect(identical(w.unread, counts), isTrue);
    expect(identical(w.mentions, mentions), isTrue);
    expect(identical(w.newFlags, flags), isTrue);
    expect(w.unread, {'c2': 3, 'dm': 4});
    expect(w.notifications, 0);
    await w.flushCache();
    expect(f.cache.writes, isEmpty);
    expect(f.client.calls, isEmpty);
  });

  test('A2 borrowed cursors share the source ledger while projections remain receiver local', () {
    final f = _Fixture(), source = f.root;
    final borrower = f.make(source: source), independent = f.make();
    expect(identical(source.readState, source.readState), isTrue);
    expect(identical(borrower.readState, source.readState), isTrue);
    expect(identical(independent.readState, source.readState), isFalse);
    expect(
      identical(source.sessionScope.binding.readState, source.readState),
      isTrue,
    );
    expect(
      identical(borrower.sessionScope.binding.readState, source.readState),
      isTrue,
    );
    source.unread['c2'] = 8;
    borrower.unread['c2'] = 2;
    independent.unread['c2'] = 5;
    expect(
      [source.unread['c2'], borrower.unread['c2'], independent.unread['c2']],
      [8, 2, 5],
    );
    expect(source.mentions, isNot(same(borrower.mentions)));
    expect(source.newFlags, isNot(same(borrower.newFlags)));
  });

  test('A3 borrowed commands retain source overrides exactly once', () async {
    final f = _Fixture(), source = f.root, borrower = f.make(source: f.root);
    f.client.unreadValue = {
      'channels': {'c2': 4},
    };
    borrower.unread = {'local': 2};
    await borrower.refreshUnread();
    expect([borrower.refreshes, source.refreshes], [1, 1]);
    expect(f.client.calls, ['GET:/channels/unread']);
    expect(source.unread, {'c2': 4});
    expect(borrower.unread, {'local': 2});
    borrower.markUnreadLocally('dm');
    expect([borrower.unreadCommands, source.unreadCommands], [1, 1]);
    expect(source.unread['dm'], 1);
    expect(borrower.unread.containsKey('dm'), isFalse);
    expect(source.notifications, 2);
    expect(borrower.notifications, 0);
  });

  test(
    'A4 an older in-flight snapshot keeps a later positive acknowledgement',
    () async {
      final f = _Fixture(), w = f.root, pending = Completer<dynamic>();
      f.client.unreadValue = pending.future;
      final refresh = w.refreshUnread();
      expect(
        w.acceptReadAllAck(
          'c2',
          {'maxReadSeq': 20, 'readStateVersion': 2},
          serverId: 's1',
          principalId: 'alice',
        ),
        isTrue,
      );
      pending.complete({
        'channels': {
          'c2': {'unreadCount': 7, 'readState': _frontier(3, 1, 20)},
        },
      });
      await refresh;
      expect(w.readState.state('s1', 'alice', 'c2')!['maxReadSeq'], 20);
      expect(w.unread['c2'], 0);
    },
  );

  test('A4 absence keeps the cursor but retains the snapshot count without latest activity', () async {
    final f = _Fixture(), w = f.root;
    w.acceptReadAllAck(
      'c2',
      {'maxReadSeq': 20, 'readStateVersion': 2},
      serverId: 's1',
      principalId: 'alice',
    );
    f.client.unreadValue = {
      'channels': {
        'c2': {
          'unreadCount': 7,
          'readState': {'kind': 'absent'},
        },
      },
    };
    await w.refreshUnread();
    expect(w.readState.state('s1', 'alice', 'c2')!['maxReadSeq'], 20);
    expect(w.unread['c2'], 7);
  });

  test(
    'A4 corrupt rows and transport failure preserve accepted counts',
    () async {
      final f = _Fixture(), w = f.root;
      w.unread = {'c2': 6};
      f.client.unreadValue = {
        'channels': {
          'c2': {
            'unreadCount': 99,
            'readState': {'kind': 'corrupt'},
          },
        },
      };
      await w.refreshUnread();
      expect(w.unread, {'c2': 6});
      final notifications = w.notifications, prefetches = w.prefetches;
      f.client.failUnread = true;
      await w.refreshUnread();
      expect(w.unread, {'c2': 6});
      expect(w.notifications, notifications);
      expect(w.prefetches, prefetches);
    },
  );

  test(
    'A4 a response from a retired account cannot publish or persist',
    () async {
      final f = _Fixture(), w = f.root, pending = Completer<dynamic>();
      w.unread = {'held': 4};
      f.client.unreadValue = pending.future;
      final refresh = w.refreshUnread();
      f.client.user = RaftRecord({'id': 'other'});
      pending.complete({
        'channels': {'c2': 99},
      });
      await refresh;
      await w.flushCache();
      expect(w.unread, {'held': 4});
      expect(w.notifications, 0);
      expect(f.cache.writes, isEmpty);
    },
  );

  for (final seq in <Object>[600, '600']) {
    test('A5 numeric/string seq $seq respects a prior read frontier', () {
      final f = _Fixture(), w = f.root;
      w.unread = {'c2': 0};
      w.acceptReadAllAck(
        'c2',
        {'maxReadSeq': 610, 'readStateVersion': 1},
        serverId: 's1',
        principalId: 'alice',
      );
      f.client.emit('message:new', _message('old', 'c2', seq));
      expect(w.unread['c2'], 0);
      f.client.emit(
        'message:new',
        _message('fresh', 'c2', seq is int ? 620 : '620'),
      );
      expect(w.unread['c2'], 1);
    });
  }

  test('A5 live counts exclude own and unjoined messages and include DMs and tracked scopes', () {
    final f = _Fixture(), w = f.root;
    w.unread = {'c2': 0, 'thread': 2};
    f.client.emit('message:new', _message('own', 'c2', 10, sender: 'alice'));
    f.client.emit('message:new', _message('unjoined', 'public', 11));
    f.client.emit('message:new', _message('untracked', 'unknown', 12));
    f.client.emit('message:new', _message('dm', 'dm', 13));
    f.client.emit('message:new', _message('thread', 'thread', 14));
    expect(w.unread, {'c2': 0, 'thread': 3, 'dm': 1});
    expect(w.prefetches, 2);
  });

  test('A5 own live activity advances the latest bound before its unread is filtered', () {
    final f = _Fixture(), w = f.root;
    w.unread = {'c2': 4};
    f.client.emit('message:new', _message('own', 'c2', 10, sender: 'alice'));
    w.messageDomain.ledger.switchServer('temporary');
    w.messageDomain.ledger.switchServer('s1');
    expect(w.messageDomain.ledger.messages('c2'), isEmpty);
    f.client.emit('read_state:updated', {
      'serverId': 's1',
      'scopeId': 'c2',
      'maxReadSeq': 10,
      'readStateVersion': 1,
    });
    expect(w.unread['c2'], 0);
  });

  test(
    'A6 snapshot flags retain current fully-read and hasNew combination',
    () async {
      final f = _Fixture(), w = f.root;
      f.client.unreadValue = {
        'channels': {
          'c2': {
            'unreadCount': 7,
            'hasMention': true,
            'hasNew': true,
            'readState': _frontier(20, 1, 20),
          },
          'dm': {
            'unreadCount': 3,
            'hasMention': true,
            'hasNew': false,
            'readState': _frontier(1, 1, 4),
          },
          'public': 2,
        },
      };
      await w.refreshUnread();
      expect(w.unread, {'c2': 0, 'dm': 3, 'public': 2});
      expect(w.mentions, {'dm'});
      expect(w.newFlags, {'c2'});
      expect(w.notifications, 1);
      expect(w.prefetches, 1);
    },
  );

  test('A6 only structured user mentions set the marker and read projection clears both flags', () {
    final f = _Fixture(), w = f.root;
    f.client.emit(
      'message:new',
      _message(
        'not-user',
        'c2',
        2,
        mentions: [
          {'type': 'agent', 'id': 'alice'},
        ],
      ),
    );
    expect(w.mentions, isEmpty);
    f.client.emit(
      'message:new',
      _message(
        'user',
        'c2',
        3,
        mentions: [
          {'type': 'user', 'id': 'alice'},
        ],
      ),
    );
    expect(w.mentions, {'c2'});
    w.newFlags = {'c2'};
    f.client.emit('read_state:updated', {
      'serverId': 's1',
      'scopeId': 'c2',
      'maxReadSeq': 3,
      'readStateVersion': 1,
    });
    expect(w.unread['c2'], 0);
    expect(w.mentions, isEmpty);
    expect(w.newFlags, isEmpty);
  });

  test('A7 projection reset clears badges but the ledger resets in its own session phase', () {
    final f = _Fixture(), w = f.root;
    w.unread = {'c2': 3};
    w.mentions = {'c2'};
    w.newFlags = {'public'};
    w.acceptReadAllAck(
      'c2',
      {'maxReadSeq': 20, 'readStateVersion': 2},
      serverId: 's1',
      principalId: 'alice',
    );
    final state = w.readState;
    w.resetServerProjection();
    expect(w.unread, isEmpty);
    expect(w.mentions, isEmpty);
    expect(w.newFlags, isEmpty);
    expect(identical(w.readState, state), isTrue);
    expect(state.state('s1', 'alice', 'c2')!['maxReadSeq'], 20);
  });

  test('A7 projection reset retains the scrolled-away decision until the timeline changes it', () async {
    final f = _Fixture(), w = f.root;
    final channel = w.channels.first;
    await w.selectChannel(channel, autoRead: false);
    w.setTimelineAtBottom(channel.id, false);
    w.resetServerProjection();
    w.channels = [channel];
    w.channel = channel;
    w.reads.clear();
    f.client.emit('message:new', _message('above-bottom', 'c1', 2));
    expect(w.reads, isEmpty);
    expect(w.unread['c1'], 1);
    w.setTimelineAtBottom(channel.id, true);
    f.client.emit('message:new', _message('at-bottom', 'c1', 3));
    expect(w.reads, ['c1']);
  });

  test('A8 persistence writes the effective cursor before the unread snapshot without notifying', () async {
    final f = _Fixture(), w = f.root;
    w.unread = {'c2': 3};
    w.readState.consumeUpdate(
      {
        'serverId': 's1',
        'scopeId': 'c2',
        'maxReadSeq': 20,
        'readStateVersion': 2,
      },
      serverId: 's1',
      principalId: 'alice',
    );
    w.persistSessionReadState();
    await w.flushCache();
    expect(f.cache.writes, ['read-frontiers', 'unread']);
    expect(
      f.cache.saved['read-frontiers'],
      w.readState.exportFor('s1', 'alice'),
    );
    expect(f.cache.saved['unread'], {'c2': 3});
    expect(w.notifications, 0);
    final borrower = f.make(source: w);
    borrower.unread = {'borrowed-local': 4};
    f.cache.writes.clear();
    borrower.persistSessionReadState();
    await borrower.flushCache();
    expect(f.cache.writes, ['read-frontiers', 'unread']);
    expect(
      f.cache.saved['read-frontiers'],
      w.readState.exportFor('s1', 'alice'),
    );
    expect(f.cache.saved['unread'], {'borrowed-local': 4});
  });
}
