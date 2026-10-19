import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/user_activity.dart';
import 'package:raft_flutter/data/workspace_cache.dart';
import 'package:raft_flutter/data/workspace_controller.dart';

Map<String, dynamic> _row(String channel, int seq) => {
  'id': '$channel-$seq',
  'channelId': channel,
  'serverId': 's1',
  'seq': '$seq',
  'senderId': 'bob',
  'senderType': 'user',
  'content': 'Public presentation fixture $channel $seq',
  'createdAt': '2026-10-17T00:00:00Z',
};

class _Cache implements WorkspaceCache {
  final writes = <(String, String)>[];
  @override
  Future<dynamic> read(o, p, s, String kind, String id) async => null;
  @override
  Future<void> write(o, p, s, String kind, String id, value) async {
    writes.add((kind, id));
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
        origin: 'https://presentation.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice'});
    selectServer('s1');
  }
  final bus = StreamController<RaftEvent>.broadcast(sync: true);
  final calls = <String>[];
  final receipts = <String>[];
  Future<void>? closing;
  @override
  Stream<RaftEvent> get events => bus.stream;
  @override
  void connect() {}
  @override
  void joinChannel(String id) {}
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    calls.add('GET:$path');
    return <String, dynamic>{};
  }

  @override
  Future<Map<String, dynamic>> messagePage(
    String id, {
    int limit = 50,
    BigInt? before,
    BigInt? after,
  }) async {
    calls.add('PAGE:$id');
    return {
      'messages': [_row(id, 5)],
      'threadSummariesByParentMessageId': {},
    };
  }

  @override
  Future<dynamic> post(String path, {dynamic data}) async {
    calls.add('POST:$path');
    if (path.endsWith('/read')) {
      receipts.add(path);
      return {'maxReadSeq': int.parse('${data['seq']}'), 'readStateVersion': 1};
    }
    return {};
  }

  @override
  Future<void> dispose() => closing ??= _close();
  Future<void> _close() async {
    await bus.close();
    await super.dispose();
  }
}

// Observe the original public dispatch. No product-only test API is needed.
class _Workspace extends WorkspaceController {
  _Workspace(
    super.client, {
    required super.cache,
    super.presentationSource,
    super.mobileNavigation,
  }) : super(ownsClient: false);
  final dispatch = <String>[];
  void Function(String)? beforeDispatch;
  int notifications = 0;
  bool closed = false;
  @override
  void notifyListeners() {
    notifications++;
    super.notifyListeners();
  }

  @override
  void setChatTabPresentation(Object owner, bool visible) {
    dispatch.add('set-tab');
    beforeDispatch?.call('set-tab');
    super.setChatTabPresentation(owner, visible);
  }

  @override
  void releaseChatTabPresentation(Object owner) {
    dispatch.add('release-tab');
    beforeDispatch?.call('release-tab');
    super.releaseChatTabPresentation(owner);
  }

  @override
  void setConversationPresentation(
    Object owner, {
    required bool main,
    required bool thread,
  }) {
    dispatch.add('set-conversation');
    beforeDispatch?.call('set-conversation');
    super.setConversationPresentation(owner, main: main, thread: thread);
  }

  @override
  void releaseConversationPresentation(Object owner) {
    dispatch.add('release-conversation');
    beforeDispatch?.call('release-conversation');
    super.releaseConversationPresentation(owner);
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

class _EqualOwner {
  @override
  bool operator ==(Object other) => other is _EqualOwner;
  @override
  int get hashCode => 1;
}

class _Fixture {
  _Fixture({bool mobile = false}) {
    root = make(mobile: mobile);
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
  _Workspace make({WorkspaceController? source, bool mobile = false}) {
    final w = _Workspace(
      client,
      cache: cache,
      presentationSource: source,
      mobileNavigation: mobile,
    );
    pages.add(w);
    w.server = RaftRecord({'id': 's1', 'slug': 'test', 'role': 'owner'});
    w.channels = [
      for (final id in ['c1', 'c2'])
        RaftChannel({'id': id, 'type': 'private', 'joined': true}),
    ];
    w.channel = w.channels.first;
    if (source == null) w.messageDomain.ledger.switchServer('s1');
    w.messageDomain.ledger.ingest([
      _row('c1', 5),
      _row('c2', 5),
      _row('thread', 5),
    ], expectedGeneration: w.messageDomain.ledger.generation);
    w.messageDomain.visibleIds['c1'] = {'c1-5'};
    w.messageDomain.visibleIds['c2'] = {'c2-5'};
    w.messageDomain.visibleIds['thread'] = {'thread-5'};
    w.messageDomain.state.threadParent = RaftMessage(_row('c1', 5));
    w.threadChannelId = 'thread';
    w.section = 'chat';
    w.navigation.navigate(w.location.withQuery({'thread': 'c1:c1-5'}));
    w.notifications = 0;
    return w;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(RaftUserActivity.forget);
  tearDown(RaftUserActivity.forget);

  test(
    'P1 default visible windows and owner writes have no I/O or notification',
    () async {
      final f = _Fixture(), w = f.root;
      final before = List.of(f.client.calls), owner = Object();
      expect(w.messageDomain.messageWindow!.visible, isTrue);
      expect(w.messageDomain.threadWindow!.visible, isTrue);
      expect(w.presentationActive, isTrue);
      w.setChatTabPresentation(owner, false);
      w.setConversationPresentation(owner, main: false, thread: false);
      w.releaseConversationPresentation(owner);
      w.releaseChatTabPresentation(owner);
      await w.flushCache();
      expect(w.messageDomain.messageWindow!.visible, isTrue);
      expect(w.messageDomain.threadWindow!.visible, isTrue);
      expect(w.notifications, 0);
      expect(f.client.calls, before);
      expect(f.cache.writes, isEmpty);
    },
  );

  for (final main in [true, false]) {
    for (final thread in [true, false]) {
      test(
        'P2 main:$main thread:$thread gates windows and actual receipts independently',
        () async {
          final f = _Fixture(), w = f.root;
          w.setConversationPresentation(Object(), main: main, thread: thread);
          expect(w.messageDomain.messageWindow!.visible, main);
          expect(w.messageDomain.threadWindow!.visible, thread);
          await w.markRead('c1');
          await w.markRead('thread');
          expect(f.client.receipts, [
            if (main) '/channels/c1/read',
            if (thread) '/channels/thread/read',
          ]);
        },
      );
    }
  }

  test('P3 hidden Chat tab retains live rows but sends no receipt', () async {
    final f = _Fixture(mobile: true), w = f.root;
    w.navigation.navigate(w.location.withQuery({'thread': null}));
    expect(w.location.thread, isNull);
    final owner = Object();
    w.setChatTabPresentation(owner, false);
    f.client.bus.add(RaftEvent('message:new', _row('c1', 6)));
    await w.markRead('c1');
    expect(w.messageDomain.messages.map((m) => m.id), contains('c1-6'));
    expect(w.messageDomain.messageWindow!.visible, isFalse);
    expect(w.messageDomain.threadWindow!.visible, isFalse);
    expect(f.client.receipts, isEmpty);
    w.releaseChatTabPresentation(owner);
    expect(w.messageDomain.messageWindow!.visible, isTrue);
    await w.markRead('c1');
    expect(f.client.receipts, ['/channels/c1/read']);
  });

  for (final tab in [true, false]) {
    test(
      'P4 identity ownership ignores stale and equal-but-distinct ${tab ? 'tab' : 'conversation'} tokens',
      () {
        final f = _Fixture(), w = f.root;
        final old = Object(), current = _EqualOwner(), equal = _EqualOwner();
        void hide(Object owner) => tab
            ? w.setChatTabPresentation(owner, false)
            : w.setConversationPresentation(owner, main: false, thread: false);
        void release(Object owner) => tab
            ? w.releaseChatTabPresentation(owner)
            : w.releaseConversationPresentation(owner);
        hide(old);
        hide(current);
        expect(current == equal, isTrue);
        expect(identical(current, equal), isFalse);
        for (final stale in [old, equal, Object()]) {
          release(stale);
          expect(w.messageDomain.messageWindow!.visible, isFalse);
          expect(w.messageDomain.threadWindow!.visible, isFalse);
        }
        release(current);
        release(current);
        release(old);
        expect(w.messageDomain.messageWindow!.visible, isTrue);
        expect(w.messageDomain.threadWindow!.visible, isTrue);
        expect(f.client.receipts, isEmpty);
        expect(w.notifications, 0);
      },
    );
  }

  test(
    'P5 matching release restores both defaults even after a mixed layout',
    () {
      final f = _Fixture(), w = f.root, owner = Object();
      w.setConversationPresentation(owner, main: false, thread: true);
      w.releaseConversationPresentation(owner);
      expect(w.messageDomain.messageWindow!.visible, isTrue);
      expect(w.messageDomain.threadWindow!.visible, isTrue);
      w.setConversationPresentation(owner, main: true, thread: false);
      w.releaseConversationPresentation(owner);
      expect(w.messageDomain.messageWindow!.visible, isTrue);
      expect(w.messageDomain.threadWindow!.visible, isTrue);
      expect(w.notifications, 0);
    },
  );

  test(
    'P6 tab and conversation owners are separate even with the same token',
    () {
      final f = _Fixture(), w = f.root, owner = Object();
      w.setChatTabPresentation(owner, false);
      w.setConversationPresentation(owner, main: false, thread: false);
      w.releaseConversationPresentation(owner);
      expect(w.messageDomain.messageWindow!.visible, isFalse);
      w.releaseChatTabPresentation(owner);
      expect(w.messageDomain.messageWindow!.visible, isTrue);
      w.setConversationPresentation(owner, main: false, thread: false);
      w.setChatTabPresentation(owner, false);
      w.releaseChatTabPresentation(owner);
      expect(w.messageDomain.messageWindow!.visible, isFalse);
      w.releaseConversationPresentation(owner);
      expect(w.messageDomain.messageWindow!.visible, isTrue);
    },
  );

  test('P7 active borrowed sets update local read admission before one source override', () async {
    final f = _Fixture(), source = f.root, page = f.make(source: f.root);
    final owner = Object(), pending = <Future<void>>[], observed = <int>[];
    // The borrowed repository's existing public command exercises its local
    // gate; controller.markRead deliberately dispatches to the source receiver.
    source.beforeDispatch = (_) {
      final before = f.client.receipts.length;
      pending.add(page.conversationReads.markRead('c1'));
      observed.add(f.client.receipts.length - before);
    };
    page.setConversationPresentation(owner, main: false, thread: true);
    page.setConversationPresentation(owner, main: true, thread: true);
    page.setChatTabPresentation(owner, false);
    page.setChatTabPresentation(owner, true);
    expect(observed, [0, 1, 0, 1]);
    expect(source.dispatch, [
      'set-conversation',
      'set-conversation',
      'set-tab',
      'set-tab',
    ]);
    expect(page.dispatch, source.dispatch);
    await Future.wait(pending);
  });

  test('P7 inactive borrowed sets stay local and presentationActive remains directly writable', () async {
    final f = _Fixture(), source = f.root, page = f.make(source: f.root);
    page.presentationActive = false;
    final owner = Object();
    page.setConversationPresentation(owner, main: false, thread: false);
    page.setChatTabPresentation(owner, false);
    await page.conversationReads.markRead('c1');
    expect(f.client.receipts, isEmpty);
    expect(source.dispatch, isEmpty);
    expect(source.messageDomain.messageWindow!.visible, isTrue);
    await page.markRead('c1');
    expect(f.client.receipts, ['/channels/c1/read']);
    page.presentationActive = true;
    page.setChatTabPresentation(owner, true);
    page.setConversationPresentation(owner, main: true, thread: true);
    expect(source.dispatch, ['set-tab', 'set-conversation']);
  });

  for (final tab in [true, false]) {
    test(
      'P8 inactive mismatched ${tab ? 'tab' : 'conversation'} release still dispatches source first',
      () async {
        final f = _Fixture(), source = f.root, page = f.make(source: f.root);
        final sourceOwner = Object(),
            localOwner = Object(),
            pending = <Future<void>>[];
        void hide(_Workspace w, Object owner) => tab
            ? w.setChatTabPresentation(owner, false)
            : w.setConversationPresentation(owner, main: false, thread: false);
        void release(Object owner) => tab
            ? page.releaseChatTabPresentation(owner)
            : page.releaseConversationPresentation(owner);
        hide(source, sourceOwner);
        page.presentationActive = false;
        hide(page, localOwner);
        source.dispatch.clear();
        final during = <int>[];
        source.beforeDispatch = (_) {
          final before = f.client.receipts.length;
          pending.add(page.conversationReads.markRead('c1'));
          during.add(f.client.receipts.length - before);
        };
        release(sourceOwner); // Wrong locally, correct on the source.
        expect(source.messageDomain.messageWindow!.visible, isTrue);
        await page.conversationReads.markRead('c1');
        expect(f.client.receipts, isEmpty);
        release(localOwner); // Source is called before the local owner clears.
        expect(during, [0, 0]);
        await page.conversationReads.markRead('c1');
        expect(f.client.receipts, ['/channels/c1/read']);
        expect(source.dispatch, [
          tab ? 'release-tab' : 'release-conversation',
          tab ? 'release-tab' : 'release-conversation',
        ]);
        await Future.wait(pending);
      },
    );
  }

  test(
    'P9 separate receivers and borrowed pages do not share local owner state',
    () async {
      final f = _Fixture(), source = f.root, independent = f.make();
      final a = f.make(source: source),
          b = f.make(source: source),
          owner = Object();
      a.presentationActive = b.presentationActive = false;
      a.setChatTabPresentation(owner, false);
      independent.setConversationPresentation(
        owner,
        main: false,
        thread: false,
      );
      expect(source.messageDomain.messageWindow!.visible, isTrue);
      expect(independent.messageDomain.messageWindow!.visible, isFalse);
      await a.conversationReads.markRead('c1');
      expect(f.client.receipts, isEmpty);
      await b.conversationReads.markRead('c1');
      expect(f.client.receipts, ['/channels/c1/read']);
      expect(identical(a.messageWindows, source.messageWindows), isTrue);
      expect(
        identical(independent.messageWindows, source.messageWindows),
        isFalse,
      );
    },
  );

  for (final boundary in [
    'background',
    'newer',
    'loading',
    'noncurrent',
    'mobile-thread',
  ]) {
    test(
      'P10 presentation defaults do not bypass the $boundary read gate',
      () async {
        final f = _Fixture(mobile: boundary == 'mobile-thread'), w = f.root;
        var id = 'c1';
        switch (boundary) {
          case 'background':
            w.foreground = false;
          case 'newer':
            w.messageDomain.state.hasNewer = true;
          case 'loading':
            w.messageDomain.state.channelLoading = true;
          case 'noncurrent':
            id = 'c2';
          case 'mobile-thread':
            break;
        }
        w.releaseConversationPresentation(Object());
        w.releaseChatTabPresentation(Object());
        await w.markRead(id);
        expect(f.client.receipts, isEmpty);
      },
    );
  }

  test(
    'P10 Activity previews retain independent channel and thread admission',
    () async {
      final f = _Fixture(), w = f.root, owner = Object();
      w.navigation.navigate(
        RaftLocation.parse('/s/test/activity?open=channel:c1'),
      );
      w.setConversationPresentation(owner, main: false, thread: true);
      await w.markRead('c1');
      expect(f.client.receipts, isEmpty);
      w.setConversationPresentation(owner, main: true, thread: false);
      await w.markRead('c1');
      expect(f.client.receipts, ['/channels/c1/read']);
      w.navigation.navigate(
        RaftLocation.parse('/s/test/activity?open=thread:thread'),
      );
      await w.markRead('thread');
      expect(f.client.receipts, hasLength(1));
      w.setConversationPresentation(owner, main: false, thread: true);
      await w.markRead('thread');
      expect(f.client.receipts, ['/channels/c1/read', '/channels/thread/read']);
    },
  );

  test('P11 channel selection and server projection reset retain the existing owner', () async {
    final f = _Fixture(), w = f.root, owner = Object();
    w.setChatTabPresentation(owner, false);
    w.setConversationPresentation(owner, main: false, thread: false);
    await w.selectChannel(w.channels.last, autoRead: false);
    expect(w.messageDomain.messageWindow!.visible, isFalse);
    w.resetServerProjection();
    w.server = RaftRecord({'id': 's1', 'slug': 'test', 'role': 'owner'});
    w.channels = [
      RaftChannel({'id': 'c1', 'type': 'private', 'joined': true}),
    ];
    w.channel = w.channels.first;
    w.section = 'chat';
    w.foreground = true;
    w.releaseConversationPresentation(owner);
    expect(
      w.messageDomain.messageWindow!.visible,
      isFalse,
      reason: 'The tab owner survived the reset.',
    );
    w.releaseChatTabPresentation(owner);
    expect(w.messageDomain.messageWindow!.visible, isTrue);
  });

  test(
    'P12 disposal adds no presentation persistence or deferred notification',
    () async {
      final f = _Fixture(), w = f.root, owner = Object();
      w.setChatTabPresentation(owner, false);
      w.setConversationPresentation(owner, main: false, thread: false);
      await w.flushCache();
      final before = List.of(f.client.calls), writes = List.of(f.cache.writes);
      w.dispose();
      await Future<void>.delayed(Duration.zero);
      expect(f.client.calls, before);
      expect(f.cache.writes, writes);
      expect(w.notifications, 0);
    },
  );
}
