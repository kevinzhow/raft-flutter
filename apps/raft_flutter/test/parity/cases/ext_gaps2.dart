import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/agent_last_migration.dart';
import 'package:raft_flutter/features/agent_migration_panel.dart';
import 'package:raft_ui/raft_ui.dart';

import '../parity_harness.dart';

final _migration = ParityCase(
  widgets: const [
    'raft_flutter:AgentLastMigration',
    'raft_flutter:MigrationProgressPanel',
    'raft_flutter:MigrationReference',
  ],
  build: (context) {
    final fixture = context.fixtures['ext:gaps2'] as Map;
    final migration = Map<String, dynamic>.from(fixture['migration'] as Map);
    final machines = List<Map<String, dynamic>>.from(
      fixture['machines'] as List,
    );
    return Scaffold(
      body: SizedBox(
        width: 620,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: AgentLastMigration(
            migration: migration,
            machines: machines,
            formatTimestamp: (stamp) => stamp,
            retry: null,
            openComputer: (_) {},
            openMember: (_) {},
            failurePanel: MigrationProgressPanel(
              migration: migration,
              machines: machines,
              agentName: 'Alpha',
              now: DateTime.utc(2026, 11, 28),
              formatTimestamp: (stamp) => stamp,
            ),
          ),
        ),
      ),
    );
  },
);

final _working = ParityCase(
  widgets: const ['raft_ui:RaftWorkingSummary', 'raft_ui:RaftWorkingNow'],
  build: (context) {
    final fixture = context.fixtures['ext:gaps2'] as Map;
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: RaftWorkingSummary(
          agents: [
            for (final row in fixture['agents'] as List)
              RaftWorkingAgent(
                id: row['id'] as String,
                name: row['name'] as String,
                text: row['text'] as String,
                avatar: RaftAvatarContent(
                  name: row['name'] as String,
                  kind: RaftAvatarContentKind.agent,
                ),
              ),
          ],
          onOpenAgent: (_) {},
        ),
      ),
    );
  },
  interact: (tester, context) async {
    await tester.tap(find.byKey(const Key('working-agents-summary')));
    await tester.pumpAndSettle();
  },
);

final _toast = ParityCase(
  widgets: const ['raft_ui:RaftToastHost', 'raft_ui:RaftToastPortal'],
  build: (context) => RaftToastHost(
    child: Scaffold(
      body: Center(
        child: Builder(
          builder: (context) => RaftButton(
            label: 'Forward',
            onPressed: () => showRaftToast(
              context,
              'Forwarded to #general.',
              tone: RaftToastRecipeTone.success,
              actionLabel: 'View in chat',
              onAction: () {},
              placement: RaftToastPlacement.top,
            ),
          ),
        ),
      ),
    ),
  ),
  interact: (tester, context) async {
    await tester.tap(find.text('Forward'));
    await tester.pumpAndSettle();
  },
);

final Map<String, ParityCase> extGaps2Cases = {
  for (final platform in ['desktop', 'phone'])
    for (final theme in ['brutal', 'elegant-dark']) ...{
      'components.gaps2.migration.$platform.$theme': _migration,
      'components.gaps2.working-now.$platform.$theme': _working,
      'components.gaps2.forward-toast.$platform.$theme': _toast,
    },
};
