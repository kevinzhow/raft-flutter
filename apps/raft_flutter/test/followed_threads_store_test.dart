import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/thread_actions.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A route result that answers with an HTTP error status.
class _Status {
  const _Status(this.code);
  final int code;
}

class _Adapter implements HttpClientAdapter {
  final calls = <RequestOptions>[];
  final Map<String, FutureOr<dynamic> Function(RequestOptions)> routes = {};
  int count(String route) =>
      calls.where((o) => '${o.method} ${o.path}' == route).length;
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) async {
    calls.add(o);
    final route = routes['${o.method} ${o.path}'];
    final value = route == null ? const _Status(404) : await route(o);
    final status = value is _Status ? value.code : 200;
    return ResponseBody.fromString(
      jsonEncode(value is _Status ? {'error': 'Fixture failure'} : value),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Client extends RaftClient {
  _Client(_Adapter adapter)
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
        transport: Dio()..httpClientAdapter = adapter,
      );
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
  void emit(String name, [dynamic payload]) =>
      stream.add(RaftEvent(name, payload));
  @override
  Future<void> dispose() async {
    await stream.close();
    await super.dispose();
  }
}

const _followed = 'GET /channels/threads/followed';
Map<String, dynamic> _row(String parent, String thread) => {
  'parentMessageId': parent,
  'threadChannelId': thread,
  'parentChannelId': 'c1',
  'replyCount': 1,
  'lastReplyAt': '2026-10-10T00:00:00.000Z',
  'unreadCount': 0,
};

Future<(WorkspaceController, _Adapter, _Client)> _fixture({
  List<Map<String, dynamic>> followed = const [],
}) async {
  final a = _Adapter();
  a.routes['POST /auth/login'] = (_) => {
    'accessToken': 'fixture-only',
    'refreshToken': 'fixture-only',
    'user': {'id': 'alice'},
  };
  a.routes[_followed] = (_) => {'threads': followed};
  a.routes['GET /channels/unread'] = (_) => {'channels': {}};
  final client = _Client(a);
  await client.login('fixture', 'fixture');
  client.selectServer('s1');
  final w = WorkspaceController(client);
  w.server = RaftRecord({'id': 's1', 'role': 'owner'});
  w.channel = RaftChannel({'id': 'c1', 'name': 'test', 'joined': true});
  w.channels = [w.channel!];
  return (w, a, client);
}

final _parent = RaftMessage({
  'id': 'm',
  'channelId': 'c1',
  'content': 'Thread parent',
});

Future<void> _pumpThreadActions(WidgetTester t, WorkspaceController w) async {
  w
    ..threadParent = _parent
    ..threadChannelId = 't1';
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(RaftFamily.elegant),
      home: Scaffold(
        body: ThreadActions(
          controller: w,
          parentMessageId: _parent.id,
          menuMode: true,
        ),
      ),
    ),
  );
}

RaftMenuItem _followItem(WidgetTester t) =>
    t.widget<RaftMenuItem>(find.byKey(const Key('thread-follow-menu-item')));

Future<void> _openThreadMenu(WidgetTester t) async {
  await t.tap(find.byKey(const Key('thread-options')));
  await t.pump();
}

/// Polls a condition reached through the asynchronous transport.
Future<void> _until(bool Function() condition) async {
  for (var i = 0; i < 500 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(condition(), isTrue);
}

/// Lets the in-memory transport settle without advancing timers.
/// [until] bounds the wait on a condition rather than a fixed step count.
Future<void> _settle(WidgetTester t, [bool Function()? until]) async {
  for (var i = 0; i < (until == null ? 10 : 300); i++) {
    if (until != null && until()) break;
    await t.runAsync(() => Future<void>.delayed(Duration.zero));
    await t.pump(const Duration(milliseconds: 10));
  }
  if (until != null) {
    expect(until(), isTrue);
    await t.pump();
  }
}

void main() {
  group('store lifecycle', () {
    test('loads once per identity; first connect reuses the read', () async {
      final (w, a, client) = await _fixture(followed: [_row('m', 't1')]);
      final store = w.followedThreads;
      store.start();
      store.start();
      client.emit('connected');
      await store.refresh();
      expect(a.count(_followed), 1);
      expect(store.isFollowing('m'), isTrue);
      expect(store.threadChannelIdFor('m'), 't1');
      // A reconnect revalidates in place: the row stays visible meanwhile.
      final held = Completer<dynamic>();
      a.routes[_followed] = (_) => held.future;
      client.emit('connected');
      await _until(() => a.count(_followed) == 2);
      expect(a.count(_followed), 2);
      expect(store.isFollowing('m'), isTrue);
      held.complete({'threads': <Object>[]});
      await store.idle;
      expect(store.isFollowing('m'), isFalse);
      w.dispose();
      await client.dispose();
    });

    test(
      'server, role and principal changes clear; stale reads drop',
      () async {
        final (w, a, client) = await _fixture(followed: [_row('m', 't1')]);
        final store = w.followedThreads;
        await store.refresh();
        expect(store.isFollowing('m'), isTrue);
        // Role change clears and reloads for the new identity.
        w.applyMembershipRole({
          'userId': 'alice',
          'serverId': 's1',
          'role': 'member',
        });
        expect(store.loaded, isFalse);
        expect(store.isFollowing('m'), isFalse);
        await _until(() => store.loaded);
        expect(store.isFollowing('m'), isTrue);
        // A response that started before a server switch is never accepted.
        final held = Completer<dynamic>();
        a.routes[_followed] = (_) => held.future;
        final pending = store.refresh();
        client.selectServer('s2');
        w.server = RaftRecord({'id': 's2', 'role': 'owner'});
        expect(store.isFollowing('m'), isFalse);
        held.complete({
          'threads': [_row('m', 't1')],
        });
        await pending;
        expect(store.isFollowing('m'), isFalse);
        expect(store.loaded, isFalse);
        w.dispose();
        await client.dispose();
      },
    );

    test('thread:updated patches a followed row without a request', () async {
      final (w, a, client) = await _fixture(
        followed: [_row('m', 't1'), _row('n', 't2')],
      );
      final store = w.followedThreads;
      await store.refresh();
      var notified = 0;
      store.addListener(() => notified++);
      client.emit('thread:updated', {
        'parentMessageId': 'n',
        'threadChannelId': 't2',
        'replyCount': 5,
        'lastReplyAt': '2026-10-11T00:00:00.000Z',
      });
      expect(a.count(_followed), 1);
      expect(notified, 1);
      expect(store.threads.first['parentMessageId'], 'n');
      expect(store.threads.first['replyCount'], 5);
      expect(store.threads.first['unreadCount'], 1);
      w.dispose();
      await client.dispose();
    });

    test(
      'an acknowledged follow survives its stale echo read, then yields',
      () async {
        final (w, a, client) = await _fixture();
        final store = w.followedThreads;
        await store.refresh();
        a.routes['POST /channels/threads/follow'] = (_) => {
          'ok': true,
          'threadChannelId': 't1',
        };
        await store.follow('m');
        // Source followThread refresh; the projection has not caught up yet.
        await _until(() => a.count(_followed) == 2);
        await store.idle;
        expect(a.count(_followed), 2);
        expect(store.isFollowing('m'), isTrue);
        expect(store.threadChannelIdFor('m'), 't1');
        // A real change signal for the thread trusts the next read again.
        client.emit('thread:updated', {
          'parentMessageId': 'm',
          'threadChannelId': 't1',
          'replyCount': 1,
        });
        await _until(() => a.count(_followed) == 3);
        await store.idle;
        expect(a.count(_followed), 3);
        expect(store.isFollowing('m'), isFalse);
        w.dispose();
        await client.dispose();
      },
    );
  });

  testWidgets('thread menu is final at first frame without a request', (
    t,
  ) async {
    final (w, a, client) = (await t.runAsync(
      () => _fixture(followed: [_row('m', 't1')]),
    ))!;
    await t.runAsync(w.followedThreads.refresh);
    final before = a.calls.length;
    await _pumpThreadActions(t, w);
    await _openThreadMenu(t);
    expect(_followItem(t).label, 'Unfollow thread');
    expect(_followItem(t).glyph, RaftGlyph.messageCircleOff);
    expect(_followItem(t).onPressed, isNotNull);
    expect(find.text('Loading thread settings…'), findsNothing);
    expect(a.calls.length, before);
    await t.pumpWidget(const SizedBox());
    w.dispose();
    await t.runAsync(client.dispose);
  });

  testWidgets('thread follow is optimistic and reverts on failure', (t) async {
    final (w, a, client) = (await t.runAsync(() => _fixture()))!;
    await t.runAsync(w.followedThreads.refresh);
    final write = Completer<dynamic>();
    a.routes['POST /channels/threads/follow'] = (_) => write.future;
    await _pumpThreadActions(t, w);
    await _openThreadMenu(t);
    expect(_followItem(t).label, 'Follow thread');
    await t.tap(find.byKey(const Key('thread-follow-menu-item')));
    await t.pump();
    // The label flips before the write is acknowledged.
    await _openThreadMenu(t);
    expect(_followItem(t).label, 'Unfollow thread');
    expect(_followItem(t).onPressed, isNull);
    write.complete(const _Status(500));
    await _settle(t, () => !w.followedThreads.isPending('m'));
    expect(_followItem(t).label, 'Follow thread');
    expect(_followItem(t).onPressed, isNotNull);
    expect(find.text('Retry'), findsOneWidget);
    expect(w.followedThreads.isFollowing('m'), isFalse);
    expect(a.count('POST /channels/threads/follow'), 1);
    await t.pumpWidget(const SizedBox());
    w.dispose();
    await t.runAsync(client.dispose);
  });

  testWidgets('thread:updated updates an open thread menu in place', (t) async {
    final (w, a, client) = (await t.runAsync(() => _fixture()))!;
    await t.runAsync(w.followedThreads.refresh);
    await _pumpThreadActions(t, w);
    await _openThreadMenu(t);
    expect(_followItem(t).label, 'Follow thread');
    // The server auto-followed the thread when the reply was posted.
    a.routes[_followed] = (_) => {
      'threads': [_row('m', 't1')],
    };
    client.emit('thread:updated', {
      'parentMessageId': 'm',
      'threadChannelId': 't1',
      'replyCount': 1,
    });
    await _settle(t, () => w.followedThreads.isFollowing('m'));
    expect(_followItem(t).label, 'Unfollow thread');
    expect(a.count(_followed), 2);
    await t.pumpWidget(const SizedBox());
    w.dispose();
    await t.runAsync(client.dispose);
  });

  testWidgets('message menu reads membership synchronously and unfollows', (
    t,
  ) async {
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(1200, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final (w, a, client) = (await t.runAsync(
      () => _fixture(followed: [_row('m', 't1')]),
    ))!;
    a.routes['GET /servers/s1/setup-projection'] = (_) => {
      'phase': 'complete',
      'surface': 'complete',
      'blocksChat': false,
    };
    a.routes['GET /agents'] = (_) => [];
    a.routes['GET /servers/s1/members'] = (_) => [];
    a.routes['GET /channels/c1/available-mentions'] = (_) => {
      'humans': [],
      'agents': [],
    };
    await t.runAsync(w.followedThreads.refresh);
    w.ledger.switchServer('s1');
    w.ledger.ingest([
      {
        'id': 'm',
        'channelId': 'c1',
        'seq': 1,
        'senderId': 'alice',
        'senderType': 'user',
        'senderName': 'Alice',
        'content': 'Thread parent',
        'messageType': 'chat',
        'threadChannelId': 't1',
      },
    ], expectedGeneration: w.ledger.generation);
    w.visibleIds['c1'] = {'m'};
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: Scaffold(body: RaftChatView(controller: w)),
      ),
    );
    await _settle(t);
    final followedReads = a.count(_followed);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final row = find.byType(RaftMessageRow).first;
    await t.tapAt(
      t.getCenter(row),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await t.pump();
    expect(find.byKey(const ValueKey('message-menu-unfollow')), findsOneWidget);
    expect(find.byKey(const ValueKey('message-menu-follow')), findsNothing);
    expect(a.count(_followed), followedReads);
    final write = Completer<dynamic>();
    a.routes['POST /channels/threads/unfollow'] = (_) => write.future;
    await t.tap(find.byKey(const ValueKey('message-menu-unfollow')));
    await t.pump();
    expect(w.followedThreads.isFollowing('m'), isFalse);
    write.complete({'ok': true});
    await _settle(t, () => !w.followedThreads.isPending('m'));
    final post = a.calls.lastWhere(
      (o) => o.path == '/channels/threads/unfollow',
    );
    expect(post.data, {'threadChannelId': 't1'});
    expect(w.followedThreads.isFollowing('m'), isFalse);
    await t.tapAt(
      t.getCenter(row),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await t.pump();
    expect(find.byKey(const ValueKey('message-menu-follow')), findsOneWidget);
    expect(a.count(_followed), followedReads);
    await t.pumpWidget(const SizedBox());
    w.dispose();
    await t.runAsync(client.dispose);
  });
}
