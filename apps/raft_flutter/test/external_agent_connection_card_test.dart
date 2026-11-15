// The connection card's live parts (Web v1.24 ExternalAgentConnectionCard):
// the 3 s status poll while not connected, the method switch with its
// rollback, who is told to ask, and the controls on the fold and narrow sizes.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/external_agent_setup.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/external_agent_fixture.dart';

Future<void> _mount(
  WidgetTester tester,
  ExternalClient client,
  Map<String, dynamic> agent,
) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(900, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  client.selectServer('s');
  final w = WorkspaceController(client)
    ..server = RaftRecord({'id': 's', 'name': 'Fixture', 'role': 'member'});
  addTearDown(() async {
    w.dispose();
    await client.stream.close();
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: ExternalAgentSetup(
            controller: w,
            agent: agent,
            status: const {'setupState': 'credential_minted'},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _switchLink() => find.descendant(
  of: key('external-agent-switch'),
  matching: find.byType(RaftTextLink),
);

void main() {
  testWidgets(
    'not connected: the status is read every 3 s; connected: it stops',
    (tester) async {
      final client = ExternalClient();
      await pumpExternal(tester, client: client);
      final start = client.statusReads;
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(client.statusReads, start + 1);
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(client.statusReads, start + 2);
      // It signs in: the next read says so, the line changes by itself and the
      // poll ends.
      client.status = {'setupState': 'connected'};
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('Offline'), findsOneWidget);
      final reads = client.statusReads;
      await tester.pump(const Duration(seconds: 9));
      expect(client.statusReads, reads);
    },
  );

  testWidgets(
    'the method switch shows at once, is saved, and rolls back on failure',
    (tester) async {
      final client = ExternalClient();
      await pumpExternal(tester, client: client);
      expect(key('external-agent-steps-existingAgent'), findsOneWidget);
      await tester.tap(_switchLink());
      await tester.pump();
      // Optimistic: before the request answers.
      expect(key('external-agent-steps-sdk'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(client.bodies.firstWhere((b) => b.$1.startsWith('PUT')).$2, {
        'method': 'sdk',
      });
      expect(find.text('Use an existing agent instead'), findsOneWidget);
      // A failed save puts the old method back.
      client.failMethod = true;
      await tester.tap(_switchLink());
      await tester.pumpAndSettle();
      expect(key('external-agent-steps-sdk'), findsOneWidget);
    },
  );

  testWidgets('someone who may not issue credentials is told who can', (
    tester,
  ) async {
    final other = Map<String, dynamic>.from(externalAgentRow)
      ..['creatorId'] = 'bob'
      ..['creator'] = {
        'id': 'bob',
        'type': 'human',
        'name': 'bob',
        'displayName': 'Bob',
      };
    final client = ExternalClient(row: other);
    await _mount(tester, client, other);
    expect(find.text('Ask Bob for a credential.'), findsOneWidget);
    expect(key('external-agent-credentials'), findsNothing);
    expect(client.calls.where((c) => c.contains('/credentials')), isEmpty);
  });

  testWidgets('an agent no person made says to ask an owner or admin', (
    tester,
  ) async {
    final other = Map<String, dynamic>.from(externalAgentRow)
      ..['creatorId'] = 'bob'
      ..['creatorType'] = 'agent'
      ..['creator'] = {'id': 'x', 'type': 'agent', 'name': 'x'};
    await _mount(tester, ExternalClient(row: other), other);
    expect(
      find.text('Ask a server owner or admin for a credential.'),
      findsOneWidget,
    );
  });

  for (final (name, platform, size) in [
    ('fold 856x944 (Android)', TargetPlatform.android, const Size(856, 944)),
    ('fold 944x856 (Android)', TargetPlatform.android, const Size(944, 856)),
    (
      'narrow desktop 390x844 (Linux)',
      TargetPlatform.linux,
      const Size(390, 844),
    ),
  ]) {
    testWidgets('Create credential and the switch work on $name', (
      tester,
    ) async {
      final client = ExternalClient()..credentials = const [];
      await pumpExternal(
        tester,
        client: client,
        // The widths of the sizes; tall, so the block is on screen.
        size: Size(size.width, 3200),
        platform: platform,
      );
      final create = key('external-agent-create-credential');
      await tester.tap(create);
      await tester.pumpAndSettle();
      expect(find.text('sk_agent_0123456789abcdefghijklmnop'), findsOneWidget);
      final toggle = _switchLink();
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(key('external-agent-steps-sdk'), findsOneWidget);
      expect(
        RaftInteraction.of(tester.element(toggle)).touch,
        platform == TargetPlatform.android,
      );
    });
  }
}
