import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/user_activity.dart';
import 'package:raft_flutter/data/workspace_cache.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/data/workspace_message_windows.dart';

RaftChannel _channel(String id) =>
    RaftChannel({'id': id, 'name': id, 'serverId': 's1', 'joined': true});

Map<String, dynamic> _row(String id, Object seq) => {
  'id': id,
  'channelId': 'c1',
  'serverId': 's1',
  'seq': seq,
  'senderId': 'bob',
  'senderType': 'user',
  'content': 'Public fixture $id',
  'createdAt': '2026-10-10T00:00:00Z',
};

class _Cache implements WorkspaceCache {
  final writes = <(String, String, String, dynamic)>[];
  @override
  Future<dynamic> read(o, p, s, String kind, String id) async => null;
  @override
  Future<void> write(o, p, s, String kind, String id, value) async {
    writes.add((p, s, kind, value));
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
  final bodies = <dynamic>[];
  final countersAtPost = <int>[];
  int Function()? counter;
  Completer<dynamic>? pendingRead;
  Completer<Map<String, dynamic>>? pendingPage;
  bool failRead = false;
  dynamic unreadValue = {
    'channels': {'c1': 7},
  };
  List<Map<String, dynamic>> rows = [_row('m5', '5')];
  Future<void>? _closing;
  @override
  Stream<RaftEvent> get events => bus.stream;
  @override
  void connect() {}
  @override
  void joinChannel(String id) {}
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    calls.add('GET:$path');
    return path == '/channels/unread' ? unreadValue : <String, dynamic>{};
  }

  @override
  Future<Map<String, dynamic>> messagePage(
    String id, {
    int limit = 50,
    BigInt? before,
    BigInt? after,
  }) async {
    calls.add('PAGE:$id');
    if (pendingPage != null) return pendingPage!.future;
    return {'messages': rows, 'threadSummariesByParentMessageId': {}};
  }

  @override
  Future<dynamic> post(String path, {dynamic data}) async {
    calls.add('POST:$path');
    if (path.endsWith('/read')) {
      bodies.add(data);
      countersAtPost.add(counter?.call() ?? -1);
      if (pendingRead != null) return pendingRead!.future;
      if (failRead) {
        throw const RaftApiException('fixture read failed', status: 500);
      }
      return {'maxReadSeq': int.parse('${data['seq']}'), 'readStateVersion': 1};
    }
    return {};
  }

  @override
  Future<void> dispose() => _closing ??= _close();
  Future<void> _close() async {
    await bus.close();
    await super.dispose();
  }

  int get reads => bodies.length;
}

class _Workspace extends WorkspaceController {
  _Workspace(
    super.client, {
    required super.cache,
    super.presentationSource,
    super.mobileNavigation,
  }) : super(ownsClient: false);
  int notifications = 0, refreshes = 0, markEntrypoints = 0;
  bool closed = false;
  Future<void>? lastReconcile, lastMarkRead;
  @override
  void notifyListeners() {
    notifications++;
    super.notifyListeners();
  }

  @override
  Future<void> refreshUnread() {
    refreshes++;
    return lastReconcile = super.refreshUnread();
  }

  @override
  Future<void> markRead(String id) {
    markEntrypoints++;
    return lastMarkRead = super.markRead(id);
  }

  @override
  Future<void> prefetchLikelyChannels({int limit = 6}) async {}
  @override
  void dispose() {
    if (closed) return;
    closed = true;
    super.dispose();
  }
}

class _Fixture {
  _Fixture({bool mobile = true, Object seq = '5'}) {
    root = make(mobile: mobile);
    root.messageDomain.ledger.ingest([
      _row('m5', seq),
      _row('retained-but-hidden', 99),
    ], expectedGeneration: root.messageDomain.ledger.generation);
    root.messageDomain.visibleIds['c1'] = {'m5'};
    root.unread = {'c1': 3};
    root.mentions = {'c1'};
    root.newFlags = {'c1'};
    root.conversationReads.latestActivity['c1'] = BigInt.from(5);
    client.counter = () => root.conversationReads.readPosts['c1'] ?? 0;
    addTearDown(() async {
      for (final page in pages.reversed) {
        if (!page.closed) await page.flushCache();
        page.dispose();
      }
      await client.dispose();
    });
  }
  final client = _Client(), cache = _Cache();
  final pages = <_Workspace>[];
  late final _Workspace root;
  _Workspace make({WorkspaceController? source, bool mobile = true}) {
    final w = _Workspace(
      client,
      cache: cache,
      presentationSource: source,
      mobileNavigation: mobile,
    );
    pages.add(w);
    w.server = RaftRecord({'id': 's1', 'role': 'owner'});
    w.channels = [_channel('c1'), _channel('c2')];
    w.channel = w.channels.first;
    if (source == null) w.messageDomain.ledger.switchServer('s1');
    w.section = 'chat';
    w.notifications = 0;
    return w;
  }

  void leave() {
    root.channel = root.channels.last;
    root.section = 'chat';
    root.messageWindows.channelGeneration++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(RaftUserActivity.forget);
  tearDown(() {
    RaftUserActivity.forget();
    RaftUserActivity.clock = DateTime.now;
  });

  for (final boundary in [
    'disk-only',
    'layout-hidden',
    'tab-hidden',
    'background',
    'outside-scope',
    'context',
  ]) {
    test('B1 $boundary never posts or implicitly clears unread', () async {
      final f = _Fixture(), w = f.root;
      var id = 'c1';
      switch (boundary) {
        case 'disk-only':
          w.messageWindows.setDiskOnly(liveWindowWrite, 'c1', true);
        case 'layout-hidden':
          w.setConversationPresentation(Object(), main: false, thread: true);
        case 'tab-hidden':
          w.setChatTabPresentation(Object(), false);
        case 'background':
          w.setForeground(false);
        case 'outside-scope':
          id = 'c2';
        case 'context':
          w.messageDomain.state.hasNewer = true;
      }
      await w.markRead(id);
      await w.flushCache();
      expect(f.client.reads, 0);
      expect(w.conversationReads.readPosts, isEmpty);
      expect(w.unread['c1'], 3);
      expect(w.mentions, {'c1'});
      expect(w.newFlags, {'c1'});
      expect(f.cache.writes, isEmpty);
      expect(w.notifications, 0);
    });
  }

  for (final seq in <Object>[5, '5']) {
    test(
      'B2 counter precedes POST and the visible wire seq keeps its ${seq.runtimeType}',
      () async {
        final f = _Fixture(seq: seq), w = f.root;
        f.client.pendingRead = Completer<dynamic>();
        final read = w.markRead('c1');
        expect(f.client.reads, 1);
        expect(f.client.countersAtPost, [1]);
        expect(f.client.bodies.single, {'seq': seq});
        expect(f.client.bodies.single['seq'].runtimeType, seq.runtimeType);
        expect(w.unread['c1'], 3);
        expect(w.notifications, 0);
        f.client.pendingRead!.complete({
          'maxReadSeq': 5,
          'readStateVersion': 1,
        });
        await read;
        expect(w.conversationReads.readPosts['c1'], 1);
        expect(f.client.reads, 1);
      },
    );
  }

  test('B2 an empty visible window has no receipt despite held rows', () async {
    final f = _Fixture(), w = f.root;
    w.messageDomain.visibleIds['c1'] = {};
    await w.markRead('c1');
    expect(f.client.reads, 0);
    expect(w.unread['c1'], 3);
    expect(w.conversationReads.readPosts, isEmpty);
  });

  test('B3 current ACK clears all indicators and persists frontier before unread once', () async {
    final f = _Fixture(), w = f.root;
    await w.markRead('c1');
    await w.flushCache();
    expect(w.unread['c1'], 0);
    expect(w.mentions, isEmpty);
    expect(w.newFlags, isEmpty);
    expect(w.readState.state('s1', 'alice', 'c1')?['maxReadSeq'], 5);
    expect(w.notifications, 1);
    expect(w.refreshes, 0);
    expect(f.cache.writes.map((e) => e.$3), ['read-frontiers', 'unread']);
    expect(
      f.cache.writes.every((e) => e.$1 == 'alice' && e.$2 == 's1'),
      isTrue,
    );
  });

  test('B3 a malformed current ACK retains the existing clear-without-frontier behavior', () async {
    final f = _Fixture(), w = f.root;
    f.client.pendingRead = Completer<dynamic>();
    final read = w.markRead('c1');
    f.client.pendingRead!.complete({'maxReadSeq': '5', 'readStateVersion': 1});
    await read;
    await w.flushCache();
    expect(w.readState.state('s1', 'alice', 'c1'), isNull);
    expect(w.unread['c1'], 0);
    expect(w.mentions, isEmpty);
    expect(w.newFlags, isEmpty);
    expect(w.notifications, 1);
    expect(w.refreshes, 0);
  });

  test('B4 an ACK after leaving clears only the covered old scope', () async {
    final f = _Fixture(), w = f.root;
    // This case's held scope ends at the receipt, unlike the hidden row in B2.
    w.messageDomain.ledger.revokeChannel('c1');
    w.messageDomain.ledger.ingest([
      _row('m5', 5),
    ], expectedGeneration: w.messageDomain.ledger.generation);
    f.client.pendingRead = Completer<dynamic>();
    final read = w.markRead('c1');
    f.leave();
    w.unread['c2'] = 9;
    f.client.pendingRead!.complete({'maxReadSeq': 5, 'readStateVersion': 2});
    await read;
    await w.flushCache();
    expect(w.unread, {'c1': 0, 'c2': 9});
    expect(w.mentions, isEmpty);
    expect(w.readState.state('s1', 'alice', 'c1')?['maxReadSeq'], 5);
    expect(w.refreshes, 0);
    expect(w.notifications, 1);
  });

  test(
    'B4 a later message survives the old ACK and requests one reconcile',
    () async {
      final f = _Fixture(), w = f.root;
      w.messageDomain.ledger.revokeChannel('c1');
      w.messageDomain.ledger.ingest([
        _row('m5', 5),
      ], expectedGeneration: w.messageDomain.ledger.generation);
      f.client.pendingRead = Completer<dynamic>();
      final read = w.markRead('c1');
      f.leave();
      w.messageDomain.ledger.ingest([
        _row('m6', 6),
      ], expectedGeneration: w.messageDomain.ledger.generation);
      w.conversationReads.latestActivity['c1'] = BigInt.from(6);
      f.client.unreadValue = {
        'channels': {'c1': 1},
      };
      f.client.pendingRead!.complete({'maxReadSeq': 5, 'readStateVersion': 2});
      await read;
      await w.lastReconcile;
      expect(w.unread['c1'], 1);
      expect(w.readState.state('s1', 'alice', 'c1')?['maxReadSeq'], 5);
      expect(w.refreshes, 1);
      expect(
        f.client.calls.where((c) => c == 'GET:/channels/unread'),
        hasLength(1),
      );
    },
  );

  for (final fence in ['account', 'server', 'generation', 'revocation']) {
    test('B5 late ACK is fenced by $fence', () async {
      final f = _Fixture(), w = f.root;
      f.client.pendingRead = Completer<dynamic>();
      final read = w.markRead('c1');
      switch (fence) {
        case 'account':
          f.client.user = RaftRecord({'id': 'carol'});
        case 'server':
          f.client.selectServer('s2');
        case 'generation':
          w.messageDomain.ledger.switchServer('s2');
        case 'revocation':
          w.sessionScope.revokeChannel('c1');
      }
      await w.flushCache();
      final writes = f.cache.writes.length, notifications = w.notifications;
      f.client.pendingRead!.complete({'maxReadSeq': 5, 'readStateVersion': 7});
      await read;
      await w.flushCache();
      expect(w.readState.state('s1', 'alice', 'c1'), isNull);
      expect(w.readState.state('s2', 'alice', 'c1'), isNull);
      expect(w.readState.state('s1', 'carol', 'c1'), isNull);
      expect(f.cache.writes.length, writes);
      expect(w.notifications, notifications);
      expect(w.refreshes, 0);
      expect(f.client.reads, 1);
    });
  }

  test(
    'B5 failed POST keeps its count and reconciles once without retry',
    () async {
      final f = _Fixture(), w = f.root;
      f.client.failRead = true;
      await w.markRead('c1');
      await w.lastReconcile;
      expect(f.client.countersAtPost, [1]);
      expect(f.client.reads, 1);
      expect(w.conversationReads.readPosts['c1'], 1);
      expect(w.refreshes, 1);
      expect(w.unread['c1'], 7);
      expect(w.readState.state('s1', 'alice', 'c1'), isNull);
    },
  );

  test('B5 failed POST after disposal cannot reconcile', () async {
    final f = _Fixture(), w = f.root;
    f.client.pendingRead = Completer<dynamic>();
    final read = w.markRead('c1');
    w.dispose();
    f.client.pendingRead!.completeError(
      const RaftApiException('fixture', status: 500),
    );
    await read;
    expect(w.refreshes, 0);
    expect(f.client.reads, 1);
  });

  for (final policy in [
    'phone-bottom',
    'phone-away',
    'desktop-idle',
    'desktop-recent',
  ]) {
    test('B6 live arrival honors $policy timeline policy', () async {
      final f = _Fixture(mobile: policy.startsWith('phone')), w = f.root;
      w.setTimelineAtBottom('c1', policy != 'phone-away');
      if (policy == 'desktop-recent') RaftUserActivity.mark();
      f.client.bus.add(RaftEvent('message:new', _row('m6', 6)));
      await w.lastMarkRead;
      final autoRead = policy == 'phone-bottom' || policy == 'desktop-recent';
      expect(f.client.reads, autoRead ? 1 : 0);
      expect(w.unread['c1'], autoRead ? 0 : 4);
      expect(
        w.conversationReads.scrolledAway.away('c1'),
        policy == 'phone-away',
      );
    });
  }

  test(
    'B7 invalid read-all facts and identities preserve projection and disk',
    () async {
      final f = _Fixture(), w = f.root;
      for (final receipt in <dynamic>[
        null,
        [],
        {},
        {'maxReadSeq': -1, 'readStateVersion': 1},
        {'maxReadSeq': '05', 'readStateVersion': 1},
        {'seq': '5', 'readStateVersion': 1},
      ]) {
        expect(
          w.acceptReadAllAck(
            'c1',
            receipt,
            serverId: 's1',
            principalId: 'alice',
          ),
          isFalse,
        );
      }
      for (final identity in [('s2', 'alice'), ('s1', 'carol')]) {
        expect(
          w.acceptReadAllAck(
            'c1',
            {'maxReadSeq': 5, 'readStateVersion': 1},
            serverId: identity.$1,
            principalId: identity.$2,
          ),
          isFalse,
        );
      }
      await w.flushCache();
      expect(w.unread['c1'], 3);
      expect(w.mentions, {'c1'});
      expect(w.newFlags, {'c1'});
      expect(w.notifications, 0);
      expect(f.cache.writes, isEmpty);
      expect(f.client.reads, 0);
    },
  );

  test('B7 read-all accepts legacy seq without sending another POST', () async {
    final f = _Fixture(), w = f.root;
    expect(
      w.acceptReadAllAck(
        'c1',
        {'seq': 5, 'readStateVersion': 4},
        serverId: 's1',
        principalId: 'alice',
      ),
      isTrue,
    );
    await w.flushCache();
    expect(w.readState.state('s1', 'alice', 'c1')?['readStateVersion'], 4);
    expect(w.unread['c1'], 0);
    expect(w.mentions, isEmpty);
    expect(w.newFlags, isEmpty);
    expect(w.notifications, 1);
    expect(f.cache.writes.map((e) => e.$3), ['read-frontiers', 'unread']);
    expect(f.client.reads, 0);
  });

  test('B8 borrowed markRead dispatches private I/O to the original window receiver once', () async {
    final f = _Fixture(), source = f.root, page = f.make(source: f.root);
    page.unread = {'c1': 8};
    await page.markRead('c1');
    expect(f.client.reads, 1);
    expect(source.markEntrypoints, 0);
    expect(page.markEntrypoints, 1);
    expect(source.conversationReads.readPosts['c1'], 1);
    expect(page.conversationReads.readPosts, isEmpty);
    expect(source.unread['c1'], 0);
    expect(page.unread['c1'], 8);
    expect(identical(page.readState, source.readState), isTrue);
  });

  test('B8 selectChannel clears optimistically and a sent receipt suppresses finally reconcile', () async {
    final f = _Fixture(), w = f.root;
    f.client.pendingPage = Completer<Map<String, dynamic>>();
    final open = w.selectChannel(w.channels.first);
    expect(w.unread['c1'], 0);
    expect(w.mentions, isEmpty);
    expect(f.client.reads, 0);
    f.client.pendingPage!.complete({
      'messages': [_row('m5', 5)],
      'threadSummariesByParentMessageId': {},
    });
    await open;
    expect(f.client.reads, 1);
    expect(f.client.countersAtPost, [1]);
    expect(w.refreshes, 0);
  });

  test(
    'B8 selectChannel finally restores unread when no visible receipt was sent',
    () async {
      final f = _Fixture(), w = f.root;
      // No prior visible rows may remain after this fresh empty page.
      w.messageWindows.visibleIds.clear();
      f.client.rows = [];
      final open = w.selectChannel(w.channels.first);
      expect(w.unread['c1'], 0);
      await open;
      await w.lastReconcile;
      expect(f.client.reads, 0);
      expect(w.conversationReads.readPosts, isEmpty);
      expect(w.refreshes, 1);
      expect(w.unread['c1'], 7);
    },
  );
}
