import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/agent_connections_section.dart';

import 'support/agent_panel_fixture.dart';

/// Web AgentProfileInfo.tsx:633: the connections section is not mounted for an
/// app-managed agent.
void main() {
  final hosted = <String, dynamic>{
    ...agentPanelAgent,
    'runtime': 'external',
    'external': true,
    'machineId': null,
    'hostedRuntime': {'state': 'active'},
  };

  testWidgets('a hosted external agent shows its connections', (tester) async {
    await pumpAgentPanel(tester, agent: hosted);
    expect(
      find.byType(AgentConnectionsSection, skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('an app-managed agent shows no connections section', (
    tester,
  ) async {
    await pumpAgentPanel(
      tester,
      agent: {...hosted, 'managedByAppInstallId': 'install-1'},
    );
    expect(
      find.byType(AgentConnectionsSection, skipOffstage: false),
      findsNothing,
    );
  });
}
