import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_flutter/features/workspace_view.dart';

import 'activity_incremental_refresh_test.dart' show channelRow;
import 'app_global_server_selector_test.dart' show RootCache, RootFixture;

const _failure = 'Fixture directory unavailable.';
const _preview = 'Accepted Activity survives a failed background read';

class _Cache extends RootCache {
  bool failServerWrite = false;

  @override
  Future<void> write(
    String origin,
    String principal,
    String server,
    String kind,
    String id,
    dynamic value,
  ) async {
    if (failServerWrite && kind == 'servers') {
      throw StateError('fixture device write failed');
    }
    await super.write(origin, principal, server, kind, id, value);
  }
}

void _fail(
  RootFixture f,
  String path, {
  bool offline = false,
  int status = 503,
}) {
  if (offline) {
    f.adapter.routes['GET $path'] = (options) =>
        throw DioException.connectionError(
          requestOptions: options,
          reason: 'fixture offline',
        );
  } else {
    f.adapter.statuses['GET $path'] = status;
    f.adapter.routes['GET $path'] = (_) => {'error': _failure};
  }
}

Future<RootFixture> _open(WidgetTester t, {_Cache? cache}) async {
  final f = RootFixture(cache: cache);
  f.overrides['GET /channels/ca'] = (_) => {
    'id': 'ca',
    'name': 'general-a',
    'type': 'channel',
    'serverId': 'a',
    'joined': true,
    'latestSeq': '1',
  };
  f.overrides['GET /channels/inbox'] = (_) => {
    'items': [
      {
        ...channelRow(0),
        'channelId': 'ca',
        'channelName': 'general-a',
        'lastMessagePreview': _preview,
      },
    ],
    'hasMore': false,
    'totalUnreadCount': 0,
  };
  addTearDown(() async => f.close(t));
  await f.mount(
    t,
    'light',
    856,
    cachedSession: true,
    uri: Uri.parse('/s/alpha/activity'),
  );
  expect(find.byType(WorkspaceView), findsOneWidget);
  expect(find.byType(ResourceView), findsOneWidget);
  expect(find.textContaining(_preview, findRichText: true), findsOneWidget);
  return f;
}

Future<void> _resume(WidgetTester t, RootFixture f) async {
  t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await f.flush(t);
}

void main() {
  for (final offline in [false, true]) {
    testWidgets(
      'actual foreground membership read stays quiet (${offline ? 'offline' : '503'})',
      (t) async {
        final f = await _open(t);
        final w = f.workspace(t);
        final held = w.servers;
        final before = f.adapter.calls
            .where((c) => c.path == '/servers')
            .length;
        _fail(f, '/servers', offline: offline);
        await _resume(t, f);
        expect(
          f.adapter.calls.where((c) => c.path == '/servers').length,
          before + 1,
        );
        expect(w.servers, same(held));
        expect(w.server?.id, 'a');
        expect(
          find.textContaining(_preview, findRichText: true),
          findsOneWidget,
        );
        expect(find.text(_failure), findsNothing);
        expect(find.text('Cannot connect to the Raft server.'), findsNothing);
        expect(find.text('Could not complete that. Try again.'), findsNothing);
      },
      variant: TargetPlatformVariant({TargetPlatform.android}),
    );
  }

  for (final status in [503, 403]) {
    testWidgets('rooms-joined channel refresh is quiet ($status)', (t) async {
      final f = await _open(t);
      final w = f.workspace(t), held = w.channels;
      final before = f.adapter.calls.where((c) => c.path == '/channels').length;
      _fail(f, '/channels', status: status);
      f.client.event('rooms:joined', null);
      await f.flush(t);
      expect(
        f.adapter.calls.where((c) => c.path == '/channels').length,
        before + 1,
      );
      expect(w.channels, same(held));
      expect(find.textContaining(_preview, findRichText: true), findsOneWidget);
      expect(find.text(_failure), findsNothing);
    });
  }

  for (final (event, payload, path) in [
    ('channel:updated', <String, dynamic>{}, '/channels'),
    (
      'server:member-updated',
      <String, dynamic>{'serverId': 'a', 'userId': 'alice', 'role': 'member'},
      '/servers',
    ),
    ('server:plan-updated', <String, dynamic>{'serverId': 'a'}, '/servers'),
  ]) {
    testWidgets('automatic $event recovery does not toast a failed read', (
      t,
    ) async {
      final f = await _open(t);
      _fail(f, path);
      f.client.event(event, payload);
      await f.flush(t);
      expect(find.text(_failure), findsNothing);
      expect(find.textContaining(_preview, findRichText: true), findsOneWidget);
    });
  }

  for (final servers in [false, true]) {
    testWidgets(
      'explicit ${servers ? 'server' : 'channel'} refresh still reports failure',
      (t) async {
        final f = await _open(t);
        _fail(f, servers ? '/servers' : '/channels');
        final w = f.workspace(t);
        await t.runAsync(
          () => servers ? w.recoverMembership() : w.refreshChannels(),
        );
        await f.flush(t);
        expect(find.text(_failure), findsOneWidget);
      },
    );
  }

  testWidgets('first server selection still reports channel-load failure', (
    t,
  ) async {
    final f = RootFixture();
    addTearDown(() async => f.close(t));
    f.overrides['GET /channels'] = (_) => {'error': _failure};
    f.adapter.statuses['GET /channels'] = 503;
    await f.mount(
      t,
      'light',
      856,
      cachedSession: true,
      uri: Uri.parse('/s/alpha'),
    );
    await f.flush(t);
    expect(find.text(_failure), findsOneWidget);
  });

  testWidgets('foreground device-cache write failure remains actionable', (
    t,
  ) async {
    final cache = _Cache();
    final f = await _open(t, cache: cache);
    cache.failServerWrite = true;
    await _resume(t, f);
    expect(
      find.text('Local changes could not be saved on this device.'),
      findsOneWidget,
    );
  });

  testWidgets('automatic reads update normally after transport recovers', (
    t,
  ) async {
    final f = await _open(t);
    _fail(f, '/servers');
    await _resume(t, f);
    f.adapter.statuses.remove('GET /servers');
    f.servers.add({'id': 'new', 'name': 'New server', 'role': 'member'});
    f.adapter.routes['GET /servers'] = (_) => f.servers;
    f.client.event('server:member-added', {'serverId': 'a', 'userId': 'alice'});
    await f.flush(t);
    expect(f.workspace(t).servers.map((s) => s.id), contains('new'));
    expect(f.workspace(t).server?.id, 'a');
    expect(find.textContaining(_preview, findRichText: true), findsOneWidget);
    expect(find.text(_failure), findsNothing);
  });

  testWidgets('background denial still leaves a revoked server', (t) async {
    final f = await _open(t);
    final w = f.workspace(t);
    _fail(f, '/servers', status: 403);
    f.client.event('server:membership-removed', {'serverId': 'a'});
    await f.flush(t);
    expect(w.server?.id, isNot('a'));
    expect(w.client.serverId, isNot('a'));
    expect(find.text(_failure), findsNothing);
  });

  testWidgets('background 401 still applies confirmed session rejection', (
    t,
  ) async {
    final f = await _open(t);
    _fail(f, '/servers', status: 401);
    await _resume(t, f);
    expect(f.client.user, isNull);
    expect(find.byType(WorkspaceView), findsNothing);
    expect(find.text(_failure), findsNothing);
  });
}
