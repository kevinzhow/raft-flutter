import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/workspace_entity_directory.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'app_global_server_selector_test.dart' show RootFixture, RootCache;

const _memory = 'raft.server-surface.https%3A%2F%2Ffixture.invalid.alice';
const _origin = 'https://fixture.invalid';

/// Every network read a cold start makes, including the directory reads.
const _startupReads = [
  'GET /auth/me',
  'GET /servers',
  'GET /channels',
  'GET /channels/dm',
  'GET /channels/unread',
  'GET /messages/channel/ca',
  'GET /agents',
  'GET /servers/a/members',
  'GET /servers/a/machines',
  'GET /servers/b/members',
  'GET /servers/b/machines',
];

Map<String, dynamic> _agent({
  String activity = 'working',
  String model = 'fixture-model-1',
}) => {
  'id': 'ag1',
  'name': 'Cindy',
  'displayName': 'Cindy',
  'status': 'active',
  'runtime': 'claude-code',
  'model': model,
  'description': 'Fixture designer',
  'activity': activity,
};

/// Agents, members, computers and the agent-authored row of server a.
void _routes(RootFixture f, {List<Map<String, dynamic>>? agents}) {
  f.overrides['GET /agents'] = (_) => agents ?? [_agent()];
  f.overrides['GET /servers/a/members'] = (_) => [
    {'userId': 'alice', 'name': 'alice', 'role': 'owner'},
  ];
  f.overrides['GET /servers/a/machines'] = (_) => {
    'machines': [
      {'id': 'pc1', 'name': 'Fixture box', 'status': 'online'},
    ],
  };
  f.overrides['GET /servers/b/machines'] = (_) => {'machines': []};
  f.overrides['GET /messages/channel/ca'] = (_) => {
    'messages': [
      {
        'id': 'ma',
        'channelId': 'ca',
        'seq': '1',
        'senderId': 'alice',
        'senderName': 'Alice',
        'content': 'Accepted a',
        'createdAt': '2026-10-10T00:00:00Z',
      },
      {
        'id': 'mg',
        'channelId': 'ca',
        'seq': '2',
        'senderId': 'ag1',
        'senderType': 'agent',
        'senderName': 'Cindy',
        'content': 'Agent says a',
        'createdAt': '2026-10-10T00:00:30Z',
      },
    ],
    'hasMore': false,
    'hasNewer': false,
  };
}

/// The avatar of the agent-authored row (null while the row is not shown).
RaftAvatar? _agentAvatar() {
  final found = find.byWidgetPredicate(
    (w) =>
        w is RaftAvatar &&
        w.name == 'Cindy' &&
        w.key is ValueKey<String> &&
        (w.key as ValueKey<String>).value.startsWith('message-avatar-'),
  );
  return found.evaluate().isEmpty
      ? null
      : found.evaluate().first.widget as RaftAvatar;
}

/// First process: the agent's channel was opened, so the directory and the
/// window are on disk.
Future<(RootCache, String)> _firstProcess(WidgetTester t) async {
  final f = RootFixture();
  _routes(f);
  await f.mount(t, 'elegant-light', 1280);
  await t.tap(find.byKey(const ValueKey('global-server-a')));
  await f.flush(t);
  expect(find.text('Agent says a'), findsOneWidget);
  expect(_agentAvatar()?.presence?.activity, RaftAvatarActivity.working);
  final uri = f.router(t).currentConfiguration.toString();
  await f.workspace(t).flushCache();
  await f.close(t);
  for (final kind in WorkspaceEntityKind.values) {
    expect(
      await f.cache.read(_origin, 'alice', 'a', 'entities', kind.name),
      isNotNull,
      reason: '${kind.name} are saved on the device',
    );
  }
  return (f.cache, uri);
}

/// The agent avatar of every painted frame in which the agent row is shown.
final _presences = <RaftAvatarPresence?>[];

Future<RootFixture> _restart(
  WidgetTester t,
  RootCache cache,
  String uri, {
  String principal = 'alice',
  String lastServer = 'alpha',
  List<Map<String, dynamic>>? agents,
}) async {
  _presences.clear();
  final f = RootFixture(cache: cache);
  _routes(f, agents: agents);
  for (final key in _startupReads) {
    f.holds[key] = Completer<dynamic>();
  }
  f.onFrame = () {
    final avatar = _agentAvatar();
    if (avatar != null) _presences.add(avatar.presence);
  };
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
    'restart paints the agent status badge from disk at the first frame and revalidates in place',
    (t) async {
      final (cache, uri) = await _firstProcess(t);
      final f = await _restart(t, cache, uri);
      // No response has arrived. The first frame that shows the agent row
      // already carries its status badge from the device directory.
      expect(f.surfaces, everyElement('workspace'));
      expect(find.text('Agent says a'), findsOneWidget);
      expect(_presences, isNotEmpty);
      expect(
        _presences.map((p) => p?.activity),
        everyElement(RaftAvatarActivity.working),
      );
      final directory = f.workspace(t).entityDirectory;
      expect(directory.authorsLoading, isFalse);
      expect(directory.fromDevice(WorkspaceEntityKind.agents), isTrue);
      expect(directory.state(WorkspaceEntityKind.agents).loaded, isTrue);
      expect(directory.state(WorkspaceEntityKind.agents).loading, isTrue);
      expect(directory.member('alice')?['role'], 'owner');
      expect(directory.computer('pc1')?['name'], 'Fixture box');
      expect(find.text('Fixture designer'), findsWidgets);

      // The revalidation reports a new activity and model: replaced in
      // place, the badge never disappears in between.
      f.holds['GET /agents']!.complete([
        _agent(activity: 'thinking', model: 'fixture-model-2'),
      ]);
      _presences.clear();
      await _release(t, f);
      await f.flush(t);
      expect(
        f.adapter.calls.where((c) => c.path == '/agents'),
        isNotEmpty,
        reason: 'the device directory is revalidated, not trusted',
      );
      expect(_presences, isNotEmpty);
      expect(_presences, everyElement(isNotNull));
      expect(_agentAvatar()?.presence?.activity, RaftAvatarActivity.thinking);
      expect(directory.fromDevice(WorkspaceEntityKind.agents), isFalse);
      expect(directory.agent('ag1')?['model'], 'fixture-model-2');
      // The accepted revalidation is written back.
      await f.workspace(t).flushCache();
      final saved = await cache.read(
        _origin,
        'alice',
        'a',
        'entities',
        'agents',
      );
      expect((saved['rows'] as List).single['model'], 'fixture-model-2');
      expect(saved['role'], 'owner');
      await f.close(t);
    },
  );

  testWidgets('another account on the device never sees the saved directory', (
    t,
  ) async {
    final (cache, uri) = await _firstProcess(t);
    final f = await _restart(t, cache, uri, principal: 'bob', agents: []);
    expect(_presences, isEmpty);
    for (final key in _startupReads.where((k) => k != 'GET /agents')) {
      await _release(t, f, key);
    }
    // Bob has no remembered server: he opens Alpha himself.
    if (find.byType(WorkspaceView).evaluate().isEmpty) {
      await t.tap(find.byKey(const ValueKey('global-server-a')));
      await f.flush(t);
    }
    final directory = f.workspace(t).entityDirectory;
    expect(f.workspace(t).server!.id, 'a');
    expect(directory.fromDevice(WorkspaceEntityKind.agents), isFalse);
    expect(directory.agent('ag1'), isNull);
    expect(directory.authorAgents, isEmpty);
    expect(directory.authorsLoading, isTrue);
    expect(_presences, everyElement(isNull));
    await _release(t, f);
    expect(directory.agent('ag1'), isNull);
    // Alice's saved directory is untouched by bob's session.
    expect(
      await cache.read(_origin, 'alice', 'a', 'entities', 'agents'),
      isNotNull,
    );
    await f.close(t);
  });

  testWidgets('another server never adopts the saved directory', (t) async {
    final (cache, uri) = await _firstProcess(t);
    final f = await _restart(t, cache, uri, lastServer: 'beta', agents: []);
    for (final key in _startupReads.where((k) => k != 'GET /agents')) {
      await _release(t, f, key);
    }
    final directory = f.workspace(t).entityDirectory;
    expect(f.workspace(t).server!.id, 'b');
    expect(directory.fromDevice(WorkspaceEntityKind.agents), isFalse);
    expect(directory.agent('ag1'), isNull);
    expect(directory.computer('pc1'), isNull);
    expect(directory.authorsLoading, isTrue);
    await _release(t, f);
    expect(directory.agent('ag1'), isNull);
    await f.close(t);
  });

  testWidgets(
    'a role changed since the save never paints the saved directory and retires it',
    (t) async {
      final (cache, uri) = await _firstProcess(t);
      cache.rows['$_origin|alice||servers|'] = [
        for (final s in cache.rows['$_origin|alice||servers|'] as List)
          {...(s as Map), 'role': 'admin'},
      ];
      final f = await _restart(t, cache, uri);
      expect(f.workspace(t).server!.string('role'), 'admin');
      final directory = f.workspace(t).entityDirectory;
      expect(directory.fromDevice(WorkspaceEntityKind.agents), isFalse);
      expect(directory.agent('ag1'), isNull);
      expect(directory.authorsLoading, isTrue);
      expect(_presences, everyElement(isNull));
      await f.workspace(t).flushCache();
      for (final kind in WorkspaceEntityKind.values) {
        expect(
          await cache.read(_origin, 'alice', 'a', 'entities', kind.name),
          isNull,
        );
      }
      await _release(t, f);
      await f.close(t);
    },
  );

  testWidgets(
    'a permission downgrade on revalidation hides the directory on screen and disk',
    (t) async {
      final (cache, uri) = await _firstProcess(t);
      final f = await _restart(t, cache, uri);
      expect(_agentAvatar()?.presence, isNotNull);
      final directory = f.workspace(t).entityDirectory;
      expect(directory.agent('ag1'), isNotNull);
      // The fresh server list reports a role without viewAgents/viewMembers/
      // viewMachines.
      for (final s in f.servers) {
        s['role'] = 'guest';
      }
      await _release(t, f, 'GET /auth/me');
      await _release(t, f, 'GET /servers');
      expect(f.workspace(t).server!.string('role'), 'guest');
      expect(directory.agent('ag1'), isNull);
      expect(directory.authorAgents, isEmpty);
      expect(directory.member('alice'), isNull);
      expect(directory.computer('pc1'), isNull);
      expect(_agentAvatar()?.presence, isNull);
      await f.workspace(t).flushCache();
      for (final kind in WorkspaceEntityKind.values) {
        expect(
          await cache.read(_origin, 'alice', 'a', 'entities', kind.name),
          isNull,
          reason: '${kind.name} are no longer allowed',
        );
      }
      await _release(t, f);
      await f.close(t);
    },
  );

  testWidgets('logout clears the saved directory', (t) async {
    final (cache, uri) = await _firstProcess(t);
    final f = await _restart(t, cache, uri);
    await _release(t, f);
    expect(_agentAvatar()?.presence, isNotNull);
    final view = t.widget<WorkspaceView>(find.byType(WorkspaceView));
    // A late directory patch is scheduled before the logout.
    f.client.event('agent:activity', {'agentId': 'ag1', 'activity': 'online'});
    unawaited(view.onLogout());
    await f.flush(t);
    await t.runAsync(
      () => Future<void>.delayed(WorkspaceEntityDirectory.persistDelay * 2),
    );
    await f.flush(t);
    expect(find.byType(WorkspaceView), findsNothing);
    for (final kind in WorkspaceEntityKind.values) {
      expect(
        await cache.read(_origin, 'alice', 'a', 'entities', kind.name),
        isNull,
      );
    }
    await f.close(t);
  });
}
