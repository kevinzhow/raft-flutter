// Fixture-backed WorkspaceController for the home/tasks parity cases. It
// answers the same API paths react-provider.spec.ts stubs for these cases,
// from the shared visual-testing JSON (ctx.fixtures). No network, no product
// code changes: only `query` (the controller's read path) is overridden, the
// way apps/raft_flutter/lib/features/page_alignment_previews.dart does.
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/search_memory.dart';
import 'package:raft_flutter/data/workspace_controller.dart';

import '../../parity_harness.dart';

const parityOrigin = 'https://public-visual-fixture.invalid';

Map<String, dynamic> _map(dynamic v) => Map<String, dynamic>.from(v as Map);

class ParityFixtureWorkspace extends WorkspaceController {
  ParityFixtureWorkspace(super.client, this.ctx);
  final ParityContext ctx;

  Map<String, dynamic> get _fx => ctx.fixtureData;

  @override
  Future<void> refreshUnread() async {}

  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    final f = ctx.fixtures;
    if (path == '/tasks/server') {
      // React stub: every /api/tasks/server URL answers tasksFixture.tasks
      // with no next_cursor.
      final status = query?['status'];
      final tasks = (f['tasksFixture']['tasks'] as List)
          .where((t) => status == null || (t as Map)['status'] == status)
          .toList();
      return {'tasks': tasks, 'next_cursor': null};
    }
    if (path == '/messages/search') return _map(f['searchResultsFixture']);
    if (path == '/channels/saved') return _map(f['savedMessagesFixture']);
    if (path.startsWith('/channels/inbox')) {
      return ctx.id == 'components.home.activity.results'
          ? _map(f['activityResultsFixture'])
          : {'items': [], 'hasMore': false};
    }
    if (path.endsWith('/members')) {
      // VisualTestingCases.tsx visualMembers: owner + designer.
      final humans = _map(_fx['humans']);
      return [
        for (final h in ['owner', 'designer'].map((k) => _map(humans[k])))
          {
            'id': h['memberId'] ?? h['id'],
            'userId': h['id'],
            'name': h['name'],
            'displayName': h['displayName'],
            'email': h['email'],
            'role': h['role'],
          },
      ];
    }
    if (path == '/agents') {
      // VisualTestingCases.tsx visualAgents (the agent store the React
      // search page reads): Cindy + Product UX Designer.
      final agents = _map(_fx['agents']);
      return [
        for (final a in ['cindy', 'productUx'].map((k) => _map(agents[k])))
          {
            'id': a['id'],
            'name': a['name'],
            'displayName': a['displayName'],
            'avatarUrl': a['avatar'],
            'status': a['status'],
          },
      ];
    }
    if (path.endsWith('/machines')) return [];
    return {};
  }

  @override
  Future<dynamic> command(String method, String path, {dynamic data}) async =>
      throw const RaftApiException(
        'This public visual fixture does not execute server mutations.',
      );
}

/// Server/user/channels primed like VisualTestingCases.tsx
/// primeDirectVisualStores (owner `artin`, #design + #android-artifacts).
ParityFixtureWorkspace parityWorkspace(
  ParityContext ctx, {
  String? serverName,
  String section = 'chat',
}) {
  final fx = ctx.fixtureData;
  final server = _map(fx['server']);
  final owner = _map(_map(fx['humans'])['owner']);
  final channels = _map(fx['channels']);
  final client = RaftClient(
    origin: parityOrigin,
    sessionStore: MemorySessionStore(),
  )..user = RaftRecord({
      'id': owner['id'],
      'name': owner['name'],
      'displayName': owner['displayName'],
      'email': owner['email'],
    });
  client.selectServer(server['id'] as String);
  return ParityFixtureWorkspace(client, ctx)
    ..server = RaftRecord({
      'id': server['id'],
      'name': serverName ?? server['name'],
      'slug': server['slug'],
      'role': 'owner',
      'plan': 'free',
    })
    ..channels = [
      for (final key in ['design', 'androidArtifacts'])
        RaftChannel({
          'id': channels[key]['id'],
          'serverId': server['id'],
          'name': channels[key]['name'],
          'description': channels[key]['description'],
          'type': 'channel',
          'joined': true,
          'createdAt': channels[key]['createdAtIso'],
        }),
    ]
    ..section = section;
}

DateTime parityNow(ParityContext ctx) => DateTime.fromMillisecondsSinceEpoch(
  (ctx.fixtureData['locale']['nowEpochMillis'] as num).toInt(),
);

class ParityMemorySearchStorage implements SearchMemoryStorage {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

/// Anonymous client for AuthView's provider lookup: answers
/// GET /auth/providers like react-provider.spec.ts (Google + GitHub).
class ParityAuthClient extends RaftClient {
  ParityAuthClient(String origin)
    : super(origin: origin, sessionStore: MemorySessionStore());
  @override
  Future<dynamic> request(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    bool authorized = true,
    bool retried = false,
    UploadCancellation? cancellation,
    void Function(int, int)? onSendProgress,
    Map<String, dynamic>? headers,
    bool acceptServerExit = false,
    Duration? receiveTimeout,
  }) async {
    if (method == 'GET' && path == '/auth/providers') {
      return {
        'providers': [
          {'id': 'google', 'label': 'Google', 'enabled': true},
          {'id': 'github', 'label': 'GitHub', 'enabled': true},
        ],
      };
    }
    throw const RaftApiException('Public auth fixture: no mutations.');
  }
}
