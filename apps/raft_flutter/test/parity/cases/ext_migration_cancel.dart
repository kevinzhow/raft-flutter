import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/agent_migration_section.dart';
import 'package:raft_ui/raft_ui.dart';

import '../parity_harness.dart';
import 'screens/screen_fixture.dart';

final _case = ParityCase(
  widgets: const [
    'raft_flutter:AgentMigrationSection',
    'raft_ui:RaftConfirmDialog',
  ],
  notes: 'Mounted agent migration confirmation for a local or hosted move.',
  build: (ctx) {
    final fixture = ctx.fixtures['ext:migration-cancel'] as Map;
    final hosted = ctx.props['targetKind'] == 'hosted';
    final client = ScreenFixtureClient(
      (method, path, query) => switch (path) {
        '/billing/subscription' => {'plan': 'pro'},
        '/agents/a1/migration' => {
          'migration': {
            ...fixture['notice'] as Map,
            if (hosted) 'targetKind': 'hosted',
          },
        },
        _ => <String, dynamic>{},
      },
      user: {'id': 'alice'},
      server: 's1',
    );
    final workspace = WorkspaceController(client)
      ..server = RaftRecord({'id': 's1', 'role': 'owner', 'slug': 'acme'});
    addTearDown(() async {
      workspace.dispose();
      await client.dispose();
    });
    return Scaffold(
      body: SingleChildScrollView(
        child: AgentMigrationSection(
          controller: workspace,
          agent: const {'id': 'a1', 'runtime': 'codex', 'machineId': 'c1'},
          machines: List<Map<String, dynamic>>.from(
            fixture['machines'] as List,
          ),
        ),
      ),
    );
  },
  interact: (tester, ctx) async {
    final cancel = find.widgetWithText(RaftButton, 'Cancel Migration');
    await tester.ensureVisible(cancel);
    await tester.tap(cancel);
    await tester.pumpAndSettle();
    expect(find.text('Canceling is safe'), findsNothing);
    expect(
      find.textContaining(
        ctx.props['targetKind'] == 'hosted'
            ? 'Canceling finishes once Source confirms'
            : 'Keep Source and Target online until it finishes.',
      ),
      findsOneWidget,
    );
  },
);

final Map<String, ParityCase> extMigrationCancelCases = {
  for (final platform in ['desktop', 'mobile'])
    for (final target in ['hosted', 'computers'])
      for (final theme in ['elegant', 'elegant-dark'])
        'components.dialogs.desktop.migration-cancel.$platform.$target.$theme':
            _case,
};
