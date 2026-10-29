import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/agent_detail_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A workspace whose reads answer from [routes] (path -> body or a thunk) and
/// whose writes are recorded in [calls]. No real HTTP.
class AgentPanelWorkspace extends WorkspaceController {
  AgentPanelWorkspace(
    super.client, {
    this.routes = const {},
    this.readFile,
    this.queryRoutes = const {},
  });
  final Map<String, Object? Function()> routes;

  /// Reads that depend on the query (paging): path -> body.
  final Map<String, Object? Function(Map<String, dynamic>? query)> queryRoutes;
  final queries = <(String, Map<String, dynamic>?)>[];

  /// `GET /agents/a/workspace-files/read?path=`: the body for one file.
  final Object? Function(String path)? readFile;
  final calls = <(String, String, dynamic)>[];

  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    if (path.endsWith('/workspace-files/read') && readFile != null) {
      return readFile!('${query?['path']}');
    }
    queries.add((path, query));
    final withQuery = queryRoutes[path];
    if (withQuery != null) return withQuery(query);
    final route = routes[path];
    if (route == null) return [];
    return route();
  }

  @override
  Future<dynamic> command(String method, String path, {dynamic data}) async {
    calls.add((method, path, data));
    return {};
  }
}

class AgentPanelClient extends RaftClient {
  AgentPanelClient()
    : super(
        origin: 'https://fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice', 'displayName': 'Alice'});
  }
  final stream = StreamController<RaftEvent>.broadcast(sync: true);

  /// Writes the app sends straight through the client (the sidebar order).
  final writes = <(String, String, dynamic)>[];

  /// Feature flags `POST /feature-flags/evaluate` answers as enabled.
  final flags = <String>{};
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
    writes.add((method, path, data));
    if (path == '/feature-flags/evaluate') {
      return {
        'evaluations': [
          for (final key in flags) {'key': key, 'enabled': true},
        ],
      };
    }
    return <String, dynamic>{};
  }

  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  void connect() {}
  @override
  void joinChannel(String id) {}
}

const agentPanelAgent = <String, dynamic>{
  'id': 'a',
  'name': 'alpha',
  'displayName': 'Alpha Agent',
  'description': 'Reviews things',
  'status': 'active',
  'runtime': 'codex',
  'model': 'alpha-model-1',
  'activity': 'offline',
  'serverId': 's',
  'machineId': 'm1',
  'creatorType': 'user',
  'creatorId': 'alice',
  'avatarUrl': 'pixel:cat',
  'createdAt': '2026-10-13T08:00:00.000Z',
  'creator': {
    'id': 'alice',
    'type': 'human',
    'name': 'alice',
    'displayName': 'Alice',
    'avatarUrl': null,
  },
};

const agentPanelMachines = <Map<String, dynamic>>[
  {'id': 'm1', 'name': 'Studio Mac', 'status': 'online', 'isComputer': true},
];

/// Mounts an [AgentDetailPanel] for [agent] at a tall 900 px window.
Future<(AgentPanelWorkspace, AgentPanelClient)> pumpAgentPanel(
  WidgetTester tester, {
  Map<String, dynamic> agent = agentPanelAgent,
  Map<String, Object? Function()> routes = const {},
  Object? Function(String path)? readFile,
  Map<String, Object? Function(Map<String, dynamic>? query)> queryRoutes =
      const {},
  Set<String> flags = const {},
  Map<String, dynamic>? liveActivity,
  bool settle = true,
  AgentDetailActions actions = const AgentDetailActions(),
  bool canManage = true,
  bool canViewPrivate = true,
  AgentDetailTab tab = AgentDetailTab.profile,
  Size size = const Size(900, 1600),
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final client = AgentPanelClient()
    ..selectServer('s')
    ..flags.addAll(flags);
  final w = AgentPanelWorkspace(
    client,
    routes: routes,
    readFile: readFile,
    queryRoutes: queryRoutes,
  )..server = RaftRecord({'id': 's', 'name': 'Fixture', 'role': 'owner'});
  addTearDown(() async {
    w.dispose();
    await client.stream.close();
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme().copyWith(platform: TargetPlatform.linux),
      home: Scaffold(
        body: AgentDetailPanel(
          controller: w,
          agent: agent,
          machines: agentPanelMachines,
          actions: actions,
          initialTab: tab,
          liveActivity: liveActivity,
          canManage: canManage,
          canViewPrivate: canViewPrivate,
          canControlRuntime: canManage,
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return (w, client);
}
