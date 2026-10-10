import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/auth_view.dart';
import 'package:raft_flutter/features/global_server_selector.dart';
import 'package:raft_flutter/features/workspace_view.dart';

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
  await f.mount(t, 'elegant-light', 1280);
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
  void Function(RootFixture)? before,
}) async {
  final f = RootFixture(cache: cache);
  for (final key in _startupReads) {
    f.holds[key] = Completer<dynamic>();
  }
  before?.call(f);
  await f.mount(
    t,
    'elegant-light',
    1280,
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

void main() {
  testWidgets(
    'restart paints cached sidebar and window at the first frame, then revalidates in place',
    (t) async {
      final (cache, uri) = await _firstProcess(t);
      final f = await _restart(t, cache, uri);
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
      final ordinary = f.adapter.routes['GET /messages/channel/ca']!;
      f.adapter.routes['GET /messages/channel/ca'] = (o) async {
        final page = Map<String, dynamic>.from(await ordinary(o));
        return {
          ...page,
          'messages': [
            ...page['messages'] as List,
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
        };
      };
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
