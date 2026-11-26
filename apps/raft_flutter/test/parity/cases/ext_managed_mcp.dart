import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/integrations_views.dart';

import '../parity_harness.dart';
import 'screens/screen_fixture.dart';

final Map<String, ParityCase> extManagedMcpCases = {
  for (final state in [
    'new',
    'probe-headers',
    'edit',
    'connection-add',
    'editor-loading',
    'editor-error',
  ])
    for (final platform in ['desktop', 'phone'])
      for (final theme in ['raft-light', 'raft-dark'])
        'components.managed-mcp.editor.$state.$platform.$theme': _editorCase,
};

final _editorCase = ParityCase(
  widgets: const ['raft_flutter:IntegrationsView', 'raft_flutter:McpAppEditor'],
  build: (context) {
    final fixture = context.fixtures['ext:managed-mcp'] as Map;
    final overrides =
        (fixture['routeSets'] as Map)[context.props['routeSet']] as Map? ??
        const {};
    final routes = {...fixture['routes'] as Map, ...overrides};
    final client = ScreenFixtureClient(
      (method, path, _) {
        final value = routes['$method $path'];
        if (value is Map && value[r'$pending'] == true) {
          return ScreenFixtureClient.pending;
        }
        if (value is Map && value[r'$status'] is int) {
          throw RaftApiException.response(
            'fixture error',
            status: value[r'$status'] as int,
            body: const {'error': 'fixture error'},
          );
        }
        return value ?? const <String, Object?>{};
      },
      user: const {'id': 'owner'},
      server: 'server',
    );
    final workspace = WorkspaceController(client)
      ..server = RaftRecord({'id': 'server', 'role': 'owner'});
    context.onDispose(() {
      workspace.dispose();
      client.dispose();
    });
    return Builder(
      builder: (theme) => Theme(
        data: Theme.of(theme).copyWith(
          platform: context.props['platform'] == 'phone'
              ? TargetPlatform.android
              : TargetPlatform.linux,
        ),
        child: Scaffold(body: IntegrationsView(controller: workspace)),
      ),
    );
  },
);
