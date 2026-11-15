// The create external agent dialog (Web v1.24 CreateExternalAgentDialog):
// step 1, the requests of Next, step 2 with its poll, the discard flow.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/create_external_agent_dialog.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/external_agent_fixture.dart';

Future<(ExternalClient, List<String>)> _open(
  WidgetTester tester, {
  ExternalClient? client,
  Size size = const Size(900, 1400),
  TargetPlatform platform = TargetPlatform.linux,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final c = (client ?? ExternalClient())..selectServer('s');
  final w = WorkspaceController(c)
    ..server = RaftRecord({'id': 's', 'name': 'Fixture', 'role': 'owner'});
  addTearDown(() async {
    w.dispose();
    await c.stream.close();
  });
  final opened = <String>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme().copyWith(platform: platform),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => unawaited(
              showCreateExternalAgentDialog(
                context,
                w,
                onOpenAgent: opened.add,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return (c, opened);
}

Future<void> _next(WidgetTester tester, [String name = 'Nathan']) async {
  await tester.enterText(key('create-external-agent-name'), name);
  await tester.pump();
  await tester.tap(key('create-external-agent-next'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'step 1: Next waits for a name, then makes the agent and its credential',
    (tester) async {
      final (client, _) = await _open(tester);
      expect(find.text('Create external agent'), findsOneWidget);
      expect(
        find.text(
          'Muse, Dots, Hermes and more. Give it a command-line tool to work with your agents on Raft.',
        ),
        findsOneWidget,
      );
      final next = tester.widget<RaftButton>(
        find.descendant(
          of: key('create-external-agent-next'),
          matching: find.byType(RaftButton),
        ),
      );
      expect(next.onPressed, isNull);
      await _next(tester);
      final posts = client.bodies.where((b) => b.$1 == 'POST /agents').toList();
      expect(posts, hasLength(1));
      final body = posts.single.$2 as Map;
      expect(body['name'], 'Nathan');
      expect(body['external'], true);
      expect(body['avatarUrl'], startsWith('pixel:'));
      expect(body.containsKey('description'), isFalse);
      expect(client.bodies.where((b) => b.$1.startsWith('PUT')).single.$2, {
        'method': 'existing_agent',
      });
      expect(
        client.bodies
            .where((b) => b.$1 == 'POST /agents/ext-1/credentials')
            .single
            .$2,
        {'name': 'Created on this page'},
      );
      expect(find.text('Set up Nathan'), findsOneWidget);
      expect(find.text('Waiting for Nathan to connect…'), findsOneWidget);
      expect(find.text('sk_agent_0123456789abcdefghijklmnop'), findsOneWidget);
      expect(find.text('You can finish connecting later.'), findsOneWidget);
    },
  );

  testWidgets('Build your own saves the SDK method; the switch link flips it', (
    tester,
  ) async {
    final (client, _) = await _open(tester);
    await tester.tap(key('create-external-agent-sdk'));
    await tester.pump();
    expect(
      find.text(
        'Build your own agent with the Raft SDK and bring it onto Raft.',
      ),
      findsOneWidget,
    );
    await _next(tester);
    expect(client.bodies.firstWhere((b) => b.$1.startsWith('PUT')).$2, {
      'method': 'sdk',
    });
    expect(find.text('2. Install the SDK and connect'), findsOneWidget);
    expect(find.text('npm install @botiverse/raft-sdk'), findsOneWidget);
    await tester.tap(key('create-external-agent-switch'));
    await tester.pumpAndSettle();
    expect(client.bodies.where((b) => b.$1.startsWith('PUT')).last.$2, {
      'method': 'existing_agent',
    });
    expect(find.text('1. Send this prompt to your agent'), findsOneWidget);
  });

  testWidgets('a refused credential deletes the agent again and says why', (
    tester,
  ) async {
    final client = ExternalClient()..failCreate = true;
    final (_, _) = await _open(tester, client: client);
    await _next(tester);
    expect(client.bodies.map((b) => b.$1), contains('DELETE /agents/ext-1'));
    expect(find.text('Set up Nathan'), findsNothing);
    expect(
      find.text("Raft couldn't create the agent. Try again."),
      findsOneWidget,
    );
    // Resolved: the next try goes through and the notice is gone.
    client.failCreate = false;
    await tester.tap(key('create-external-agent-next'));
    await tester.pumpAndSettle();
    expect(find.text('Set up Nathan'), findsOneWidget);
    expect(
      find.text("Raft couldn't create the agent. Try again."),
      findsNothing,
    );
  });

  testWidgets('a refused agent shows the server error and deletes nothing', (
    tester,
  ) async {
    final client = ExternalClient()..failAgentCreate = true;
    await _open(tester, client: client);
    await _next(tester);
    expect(find.text('Name taken'), findsOneWidget);
    expect(
      client.bodies.map((b) => b.$1),
      isNot(contains('DELETE /agents/ext-1')),
    );
  });

  testWidgets('step 2 asks every 3 seconds until connected, then offers Done', (
    tester,
  ) async {
    final (client, opened) = await _open(tester);
    await _next(tester);
    final before = client.statusReads;
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(client.statusReads, greaterThan(before));
    expect(find.text('Waiting for Nathan to connect…'), findsOneWidget);
    client.status = {'setupState': 'connected'};
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Nathan is online'), findsOneWidget);
    expect(find.text('You can finish connecting later.'), findsNothing);
    expect(key('create-external-agent-cancel'), findsNothing);
    // Polling stopped.
    final reads = client.statusReads;
    await tester.pump(const Duration(seconds: 9));
    expect(client.statusReads, reads);
    // Connected: the X is Done and opens the agent.
    await tester.tap(key('create-external-agent-done'));
    await tester.pumpAndSettle();
    expect(opened, ['ext-1']);
    expect(find.text('Set up Nathan'), findsNothing);
  });

  testWidgets('Cancel before it connects asks; Keep stays, Discard deletes', (
    tester,
  ) async {
    final client = ExternalClient()..failDelete = true;
    await _open(tester, client: client);
    await _next(tester);
    await tester.tap(key('create-external-agent-cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Discard Nathan?'), findsOneWidget);
    await tester.tap(find.text('Keep setting up'));
    await tester.pumpAndSettle();
    expect(find.text('Set up Nathan'), findsOneWidget);
    expect(
      client.bodies.map((b) => b.$1),
      isNot(contains('DELETE /agents/ext-1')),
    );
    // A failed delete says so back in the setup.
    await tester.tap(key('create-external-agent-cancel'));
    await tester.pumpAndSettle();
    await tester.tap(key('create-external-agent-discard-confirm'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        "Raft couldn't discard the agent. Try again, or delete it from its page.",
      ),
      findsOneWidget,
    );
    client.failDelete = false;
    await tester.tap(key('create-external-agent-cancel'));
    await tester.pumpAndSettle();
    await tester.tap(key('create-external-agent-discard-confirm'));
    await tester.pumpAndSettle();
    expect(find.text('Set up Nathan'), findsNothing);
    expect(client.bodies.where((b) => b.$1 == 'DELETE /agents/ext-1').last.$2, {
      'workspace': 'keep',
    });
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
    testWidgets('Next and Cancel work on $name', (tester) async {
      final (client, _) = await _open(tester, size: size, platform: platform);
      await _next(tester);
      expect(find.text('Set up Nathan'), findsOneWidget);
      await tester.tap(key('create-external-agent-cancel'));
      await tester.pumpAndSettle();
      await tester.tap(key('create-external-agent-discard-confirm'));
      await tester.pumpAndSettle();
      expect(client.bodies.map((b) => b.$1), contains('DELETE /agents/ext-1'));
      expect(find.text('Set up Nathan'), findsNothing);
      expect(
        RaftInteraction.of(tester.element(find.text('open'))).touch,
        platform == TargetPlatform.android,
      );
    });
  }
}
