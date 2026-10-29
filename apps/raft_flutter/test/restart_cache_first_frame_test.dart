import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/auth_view.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/global_server_selector.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_flutter/platform/background_notifications.dart';
import 'package:raft_client/raft_client.dart';

import 'app_global_server_selector_test.dart' show RootFixture, RootCache;

const _memory = 'raft.server-surface.https%3A%2F%2Ffixture.invalid.alice';
const _origin = 'https://fixture.invalid';

/// Every network read a cold start makes before the selected channel's page.
const _startupReads = [
  'GET /auth/me',
  'GET /servers',
  'GET /channels',
  'GET /channels/dm',
  'GET /channels/unread',
  'GET /messages/channel/ca',
];

/// First process: open Alpha's channel so its accepted window is on disk.
Future<(RootCache, String)> _firstProcess(WidgetTester t) async {
  final f = RootFixture();
  await f.mount(t, 'light', 1280);
  await t.tap(find.byKey(const ValueKey('global-server-a')));
  await f.flush(t);
  expect(find.text('Accepted a'), findsOneWidget);
  final uri = f.router(t).currentConfiguration.toString();
  await f.workspace(t).flushCache();
  await f.close(t);
  expect(await f.cache.read(_origin, 'alice', 'a', 'window', 'ca'), isNotNull);
  return (f.cache, uri);
}

/// Second process on the same device cache, with every startup read held.
Future<RootFixture> _restart(
  WidgetTester t,
  RootCache cache,
  String uri, {
  String principal = 'alice',
  String lastServer = 'alpha',
  double width = 1280,
  void Function(RootFixture)? before,
}) async {
  final f = RootFixture(cache: cache);
  for (final key in _startupReads) {
    f.holds[key] = Completer<dynamic>();
  }
  before?.call(f);
  await f.mount(
    t,
    'light',
    width,
    cachedSession: true,
    principal: principal,
    preferences: {'$_memory.last': lastServer, '$_memory.a': uri},
  );
  return f;
}

Future<void> _release(WidgetTester t, RootFixture f, [String? only]) async {
  for (final entry in f.holds.entries) {
    if ((only == null || entry.key == only) && !entry.value.isCompleted) {
      entry.value.complete(null);
    }
  }
  await f.flush(t);
}

RootFixture _twoChannelFixture({RootCache? cache}) {
  final f = RootFixture(cache: cache);
  f.overrides['GET /channels'] = (request) => [
    for (final id
        in request.headers['X-Server-Id'] == 'a'
            ? ['alpha', 'beta']
            : ['c${request.headers['X-Server-Id']}'])
      {
        'id': id,
        'name': 'channel-$id',
        'type': 'channel',
        'serverId': request.headers['X-Server-Id'],
        'joined': true,
        'latestSeq': '1',
      },
  ];
  for (final id in ['alpha', 'beta']) {
    f.overrides['GET /messages/channel/$id'] = (_) => {
      'messages': [
        {
          'id': 'message-$id',
          'channelId': id,
          'seq': '1',
          'senderId': 'alice',
          'senderName': 'Alice',
          'content': 'Message $id',
          'createdAt': '2026-10-10T00:00:00Z',
        },
      ],
      'hasMore': false,
      'hasNewer': false,
    };
    f.overrides['POST /channels/$id/read'] = (_) => {};
    f.overrides['GET /channels/$id/members'] = (_) => [];
  }
  return f;
}

Future<RootCache> _cachedBeta(WidgetTester t) async {
  final first = _twoChannelFixture();
  await first.mount(t, 'light', 1280);
  await t.tap(find.byKey(const ValueKey('global-server-a')));
  await first.flush(t);
  await t.tap(find.text('channel-beta').first);
  await first.flush(t);
  expect(find.text('Message beta'), findsOneWidget);
  await first.workspace(t).flushCache();
  await first.close(t);
  expect(
    await first.cache.read(_origin, 'alice', 'a', 'selection', ''),
    'beta',
  );
  return first.cache;
}

void main() {
  for (final width in [390.0, 1280.0]) {
    for (final (route, server, channel, message) in [
      ('/s/alpha/channel/beta', 'a', 'beta', 'Message beta'),
      ('/s/beta/channel/cb', 'b', 'cb', 'Accepted b'),
    ]) {
      testWidgets('late cold-start Alpha cannot replace $route at $width', (
        t,
      ) async {
        final cache = await _cachedBeta(t);
        final f = _twoChannelFixture(cache: cache);
        final alpha = Completer<dynamic>();
        f.holds['GET /messages/channel/alpha'] = alpha;
        try {
          await f.mount(
            t,
            'light',
            width,
            cachedSession: true,
            uri: Uri(path: '/s/alpha/channel/alpha'),
          );
          expect(f.workspace(t).channel?.id, 'alpha');
          await f.pushUri(t, route);
          expect(f.workspace(t).server?.id, server);
          expect(f.workspace(t).channel?.id, channel);
          expect(find.text(message), findsOneWidget);
          alpha.complete({
            'messages': [
              {
                'id': 'late-alpha',
                'channelId': 'alpha',
                'seq': '1',
                'senderId': 'alice',
                'senderName': 'Alice',
                'content': 'Late Alpha must not replace this page',
                'createdAt': '2026-10-10T00:00:00Z',
              },
            ],
            'hasMore': false,
            'hasNewer': false,
          });
          await f.flush(t);
          expect(f.router(t).currentConfiguration.toString(), route);
          expect(f.workspace(t).server?.id, server);
          expect(f.workspace(t).channel?.id, channel);
          expect(find.text(message), findsOneWidget);
          expect(
            find.text('Late Alpha must not replace this page'),
            findsNothing,
          );
        } finally {
          if (!alpha.isCompleted) alpha.complete(null);
          await f.flush(t);
          await f.close(t);
        }
      });
    }
    for (final status in [403, 404]) {
      testWidgets(
        'cold-start denied Alpha stays unavailable instead of cached Beta $width/$status',
        (t) async {
          final cache = await _cachedBeta(t);
          final f = _twoChannelFixture(cache: cache);
          f.overrides['GET /messages/channel/alpha'] = (_) => {
            'error': 'Channel unavailable',
          };
          f.adapter.statuses['GET /messages/channel/alpha'] = status;
          try {
            await f.mount(
              t,
              'light',
              width,
              cachedSession: true,
              uri: Uri(path: '/s/alpha/channel/alpha'),
            );
            expect(
              f.router(t).currentConfiguration.toString(),
              '/s/alpha/channel/alpha',
            );
            expect(f.workspace(t).missingConversationChannelId, 'alpha');
            expect(find.text('Message beta'), findsNothing);
            expect(find.text('Select a channel'), findsOneWidget);
            expect(find.text('Loading channel'), findsNothing);
            expect(f.client.user?.id, 'alice');
            expect(
              await cache.read(_origin, 'alice', 'a', 'window', 'beta'),
              isNotNull,
            );
          } finally {
            await f.close(t);
          }
        },
      );
    }
  }
  for (final width in [390.0, 1280.0]) {
    for (final cachedSession in [false, true]) {
      testWidgets(
        'cold start routes Alpha over cached Beta $width/cached=$cachedSession',
        (t) async {
          final first = _twoChannelFixture();
          await first.mount(t, 'light', 1280);
          await t.tap(find.byKey(const ValueKey('global-server-a')));
          await first.flush(t);
          await t.tap(find.text('channel-beta').first);
          await first.flush(t);
          expect(find.text('Message beta'), findsOneWidget);
          await first.workspace(t).flushCache();
          await first.close(t);
          expect(
            await first.cache.read(_origin, 'alice', 'a', 'selection', ''),
            'beta',
          );
          final restarted = _twoChannelFixture(cache: first.cache);
          try {
            await restarted.mount(
              t,
              'light',
              width,
              cachedSession: cachedSession,
              uri: Uri(path: '/s/alpha/channel/alpha'),
            );
            expect(
              restarted.router(t).currentConfiguration.toString(),
              '/s/alpha/channel/alpha',
            );
            expect(
              restarted.adapter.calls.where(
                (request) => request.path == '/messages/channel/alpha',
              ),
              isNotEmpty,
              reason: 'the route must drive selection and the page request',
            );
            expect(restarted.workspace(t).channel?.id, 'alpha');
            expect(find.text('Message alpha'), findsOneWidget);
            expect(find.text('Message beta'), findsNothing);
            expect(find.text('Loading channel'), findsNothing);
          } finally {
            await restarted.close(t);
          }
        },
      );
    }
  }

  testWidgets(
    'logout while a guest settles revokes its rotation without erasing a concurrent new login',
    (t) async {
      final (cache, _) = await _firstProcess(t);
      final drained = Completer<void>();
      final worker = NativeSessionOwner(
        supported: true,
        onPreempt: () => drained.future,
      );
      final ui = NativeSessionOwner(supported: true);
      addTearDown(worker.release);
      addTearDown(ui.release);
      worker.registerGuest();
      final f = RootFixture(cache: cache, sessionOwner: ui);
      await f.mount(
        t,
        'light',
        412,
        cachedSession: true,
        preferences: {'$_memory.last': 'alpha', '$_memory.a': '/s/alpha'},
      );
      final oldClient = f.client;
      final logout = t
          .widget<WorkspaceView>(find.byType(WorkspaceView))
          .onLogout();
      expect(oldClient.signedIn, false);
      await f.flush(t);
      expect(find.byType(AuthView), findsOneWidget);
      f.adapter.routes['POST /auth/login'] = (_) => {
        'accessToken': 'new-login-fixture',
        'refreshToken': 'new-login-fixture',
        'user': {
          'id': 'bob',
          'email': 'bob@example.invalid',
          'emailVerified': true,
        },
      };
      final login = t
          .widget<AuthView>(find.byType(AuthView))
          .onLogin(_origin, 'bob@example.invalid', 'fixture-only');
      await f.sessions.write(
        _origin,
        Session(
          accessToken: 'worker-fixture',
          refreshToken: 'worker-fixture',
          cachedUser: {'id': 'alice', 'emailVerified': true},
        ),
      );
      drained.complete();
      await f.flush(t);
      await logout;
      await login;
      expect(
        f.adapter.calls
            .singleWhere((r) => r.path == '/auth/logout')
            .data['refreshToken'],
        'worker-fixture',
      );
      final saved = await f.sessions.read(_origin);
      expect(saved?.refreshToken, 'new-login-fixture');
      expect(saved?.cachedUser?['id'], 'bob');
      expect(await cache.read(_origin, 'alice', 'a', 'window', 'ca'), isNull);
      expect(oldClient.disposalCount, 1);
      await f.close(t);
    },
  );

  testWidgets(
    'a busy background guest never delays the first frame or any startup read',
    (t) async {
      final (cache, _) = await _firstProcess(t);
      final asked = Completer<void>();
      final stuck = Completer<void>(); // a guest that never stops by itself
      final worker = NativeSessionOwner(
        supported: true,
        onPreempt: () {
          asked.complete();
          return stuck.future;
        },
      );
      final ui = NativeSessionOwner(supported: true);
      addTearDown(worker.release);
      addTearDown(ui.release);
      worker.registerGuest();
      var ready = 0;
      final f = RootFixture(
        cache: cache,
        sessionOwner: ui,
        onStartupReady: () => ready++,
      );
      for (final key in _startupReads) {
        f.holds[key] = Completer<dynamic>();
      }
      await f.mount(
        t,
        'light',
        412,
        cachedSession: true,
        preferences: {'$_memory.last': 'alpha', '$_memory.a': '/s/alpha'},
      );
      expect(asked.isCompleted, isTrue, reason: 'the guest was preempted');
      expect(ready, 1);
      expect(find.byType(WorkspaceView), findsOneWidget);
      expect(find.text('Restoring session…'), findsNothing);
      expect(find.byType(GlobalServerSelector), findsNothing);
      expect(f.surfaces, everyElement('workspace'));
      expect(
        f.adapter.calls,
        isNotEmpty,
        reason: 'startup reads are sent while the guest is still unsettled',
      );
      final w = f.workspace(t);
      expect(w.channels.single.name, 'general-a');
      await t.tap(find.text('general-a').first);
      await f.flush(t);
      expect(find.text('Accepted a'), findsOneWidget);
      await _release(t, f);
      expect(
        f.adapter.calls.where(
          (r) => r.headers['Authorization'] == 'Bearer fixture-only',
        ),
        isNotEmpty,
      );
      expect(find.text('Accepted a'), findsOneWidget);
      await f.close(t);
      expect(ready, 1);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'a first login without a cached account releases the launch screen while validation waits',
    (t) async {
      var ready = 0;
      final f = RootFixture(onStartupReady: () => ready++);
      f.holds['GET /auth/me'] = Completer<dynamic>();
      await f.mount(t, 'light', 412);
      expect(ready, 1);
      expect(find.text('Restoring session…'), findsOneWidget);
      await _release(t, f);
      await f.close(t);
      expect(ready, 1);
    },
  );

  testWidgets(
    'an account with no workspace cache releases the launch screen before the directory read',
    (t) async {
      var ready = 0;
      final f = RootFixture(onStartupReady: () => ready++);
      f.holds['GET /servers'] = Completer<dynamic>();
      await f.mount(t, 'light', 412, cachedSession: true);
      expect(ready, 1);
      expect(find.byType(GlobalServerSelector), findsOneWidget);
      await _release(t, f);
      await f.close(t);
    },
  );

  for (final direct in [false, true]) {
    testWidgets(
      'restart paints cached sidebar and window at the first frame when direct is $direct, then revalidates in place',
      (t) async {
        final (cache, uri) = await _firstProcess(t);
        final f = await _restart(t, cache, uri, width: direct ? 390 : 1280);
        expect(
          find.byType(MobileChatDirectRead),
          direct ? findsWidgets : findsNothing,
        );
        // No startup response has arrived; every painted frame was already the
        // workspace with its cached sidebar row and message window.
        expect(f.surfaces, everyElement('workspace'));
        expect(f.router(t).currentConfiguration.toString(), uri);
        expect(find.byType(GlobalServerSelector), findsNothing);
        expect(find.text('general-a'), findsWidgets);
        expect(find.text('Accepted a'), findsOneWidget);
        expect(find.text('Alice'), findsWidgets);
        expect(f.workspace(t).server!.id, 'a');
        // A disk-only tail may be stale: no read receipt until revalidated.
        expect(
          f.adapter.calls.where((c) => c.path == '/channels/ca/read'),
          isEmpty,
        );
        // Revalidation adds a newer row; the cached row never blanks.
        final cached =
            await cache.read(_origin, 'alice', 'a', 'window', 'ca') as Map;
        // The request may already be in flight over the cached first frame.
        // Complete that held response instead of replacing its handler later.
        f.holds['GET /messages/channel/ca']!.complete({
          'messages': [
            ...cached['messages'] as List,
            {
              'id': 'ma2',
              'channelId': 'ca',
              'seq': '2',
              'senderId': 'alice',
              'senderName': 'Alice',
              'content': 'Fresh a',
              'createdAt': '2026-10-10T00:01:00Z',
            },
          ],
          'hasMore': false,
          'hasNewer': false,
        });
        var blanked = false;
        f.onFrame = () {
          if (find.text('Accepted a').evaluate().isEmpty) blanked = true;
        };
        await _release(t, f);
        await f.flush(t);
        expect(
          f.adapter.calls.where((c) => c.path == '/messages/channel/ca'),
          isNotEmpty,
          reason: 'the cached window is revalidated, not trusted',
        );
        expect(
          f.adapter.calls.where((c) => c.path == '/channels/ca/read'),
          isNotEmpty,
        );
        expect(blanked, isFalse);
        expect(find.text('Accepted a'), findsOneWidget);
        expect(find.text('Fresh a'), findsOneWidget);
        expect(f.surfaces, everyElement('workspace'));
        await f.close(t);
      },
    );
  }

  testWidgets('another account on the device never sees the cached window', (
    t,
  ) async {
    final (cache, uri) = await _firstProcess(t);
    final f = await _restart(t, cache, uri, principal: 'bob');
    expect(find.byType(WorkspaceView), findsNothing);
    expect(find.text('Accepted a'), findsNothing);
    expect(find.text('general-a'), findsNothing);
    await _release(t, f);
    await f.close(t);
  });

  testWidgets('another server never adopts the cached window', (t) async {
    final (cache, uri) = await _firstProcess(t);
    final f = await _restart(t, cache, uri, lastServer: 'beta');
    expect(find.text('Accepted a'), findsNothing);
    expect(find.text('general-a'), findsNothing);
    await _release(t, f);
    expect(f.workspace(t).server!.id, 'b');
    expect(find.text('Accepted a'), findsNothing);
    await f.close(t);
  });

  testWidgets(
    'a channel revoked by the fresh lists is removed from screen and disk',
    (t) async {
      final (cache, uri) = await _firstProcess(t);
      final f = await _restart(t, cache, uri);
      expect(find.text('Accepted a'), findsOneWidget);
      await _release(t, f, 'GET /auth/me');
      await _release(t, f, 'GET /servers');
      await _release(t, f, 'GET /channels/dm');
      f.holds['GET /channels']!.complete([]);
      await f.flush(t);
      expect(find.text('Accepted a'), findsNothing);
      expect(find.text('general-a'), findsNothing);
      await f.workspace(t).flushCache();
      expect(await cache.read(_origin, 'alice', 'a', 'window', 'ca'), isNull);
      await _release(t, f);
      await f.close(t);
    },
  );

  testWidgets(
    'a server missing from the fresh directory closes and purges its cache',
    (t) async {
      final (cache, uri) = await _firstProcess(t);
      final f = await _restart(t, cache, uri);
      expect(find.text('Accepted a'), findsOneWidget);
      f.servers.removeWhere((s) => s['id'] == 'a');
      await _release(t, f, 'GET /auth/me');
      await _release(t, f, 'GET /servers');
      expect(find.text('Accepted a'), findsNothing);
      expect(find.byType(WorkspaceView), findsNothing);
      expect(await cache.read(_origin, 'alice', 'a', 'window', 'ca'), isNull);
      expect(await cache.read(_origin, 'alice', 'a', 'channels', ''), isNull);
      await _release(t, f);
      await f.close(t);
    },
  );

  testWidgets('a reduced role on revalidation replaces the server authority', (
    t,
  ) async {
    final (cache, uri) = await _firstProcess(t);
    final f = await _restart(t, cache, uri);
    final w = f.workspace(t);
    expect(w.server!.string('role'), 'owner');
    for (final s in f.servers) {
      s['role'] = 'member';
    }
    await _release(t, f);
    expect(w.server!.string('role'), 'member');
    expect(
      (await cache.read(_origin, 'alice', '', 'servers', '') as List).every(
        (s) => s['role'] == 'member',
      ),
      isTrue,
    );
    await f.close(t);
  });

  testWidgets('a rejected stored session ends and clears the account cache', (
    t,
  ) async {
    final (cache, uri) = await _firstProcess(t);
    final f = await _restart(
      t,
      cache,
      uri,
      before: (f) {
        f.adapter.statuses['GET /auth/me'] = 401;
        f.adapter.statuses['POST /auth/refresh'] = 401;
        f.adapter.routes['POST /auth/refresh'] = (_) => {
          'error': 'Session revoked',
        };
      },
    );
    expect(find.text('Accepted a'), findsOneWidget);
    await _release(t, f, 'GET /auth/me');
    await f.flush(t);
    expect(find.byType(WorkspaceView), findsNothing);
    expect(find.byType(AuthView), findsOneWidget);
    expect(find.text('Accepted a'), findsNothing);
    expect(await f.sessions.read(_origin), isNull);
    expect(await cache.read(_origin, 'alice', 'a', 'window', 'ca'), isNull);
    await _release(t, f);
    await f.close(t);
  });

  testWidgets(
    'a stored session that now belongs to another account clears the original',
    (t) async {
      final (cache, uri) = await _firstProcess(t);
      final f = await _restart(t, cache, uri);
      expect(find.text('Accepted a'), findsOneWidget);
      f.holds['GET /auth/me']!.complete({
        'id': 'bob',
        'name': 'bob',
        'email': 'bob@example.invalid',
        'emailVerified': true,
      });
      await f.flush(t);
      expect(find.byType(WorkspaceView), findsNothing);
      expect(find.text('Accepted a'), findsNothing);
      expect(await cache.read(_origin, 'alice', 'a', 'window', 'ca'), isNull);
      await _release(t, f);
      await f.close(t);
    },
  );

  testWidgets('offline restart keeps the cached workspace usable', (t) async {
    final (cache, uri) = await _firstProcess(t);
    final f = await _restart(
      t,
      cache,
      uri,
      before: (f) {
        for (final key in _startupReads) {
          f.adapter.statuses[key] = 503;
        }
      },
    );
    await _release(t, f);
    await f.flush(t);
    expect(f.client.restoredOffline, isTrue);
    expect(find.byType(WorkspaceView), findsOneWidget);
    expect(find.text('Accepted a'), findsOneWidget);
    expect(find.text('general-a'), findsWidgets);
    await f.close(t);
  });
}
