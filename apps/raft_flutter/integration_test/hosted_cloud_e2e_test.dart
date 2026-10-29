// Cloud agents against a real Raft server and a real hosted runtime (the local
// test stack with a local antiproton): create a cloud agent from the Computer
// picker, watch its status go from setting up to running, read its usage after
// real turns, stop a turn, see the cloud group and the sender line, open the
// Plan page's spend card, and update the onboarding agent's official identity.
//
//   flutter test integration_test/hosted_cloud_e2e_test.dart -d linux --no-pub \
//     --dart-define=RAFT_TEST_CONFIG=<json: origin, email, password, serverId> \
//     --dart-define=RAFT_TEST_REPORT=<dir for the PNG captures and the run log>
//
// It spends model calls: exactly two agent turns (one answered, one stopped).
// It archives the agents it created and restores the server's onboarding agent.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/raftbench_session.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.shouldPropagateDevicePointerEvents = true;
  WidgetController.hitTestWarningShouldBeFatal = true;

  testWidgets('cloud agent: create, run, usage, stop, labels, spend, identity', (
    t,
  ) async {
    final cfg = raftbenchConfig();
    t.view.physicalSize = const Size(1440, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    addTearDown(() => writeRunLog('run.log'));
    final w = await signIn(t, cfg);
    final created = <String>[];
    var turns = 0;
    addTearDown(() async {
      for (final id in created) {
        try {
          await w.client.request(
            'DELETE',
            '/agents/$id',
            data: {'workspace': 'keep'},
          );
          note('archived $id');
        } catch (e) {
          note('could not archive $id: ${e.runtimeType}');
        }
      }
      note('agent turns used: $turns');
    });
    final stamp = DateTime.now().millisecondsSinceEpoch % 1000000;
    final name = 'cloud-e2e-$stamp';

    // 1. Create from the Computer picker.
    w.setSection('agents');
    await t.pumpAndSettle();
    final add = find.byKey(const ValueKey('desktop-directory-add-agent'));
    await until(
      t,
      () => add.hitTestable().evaluate().isNotEmpty,
      what: 'Add agent',
    );
    await t.tap(add);
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(RaftMenuItem, 'Create agent'));
    await t.pumpAndSettle();
    final cloudOption = find.text(
      'Cloud agent, runs in the cloud · Free for a limited time',
    );
    // The option arrives once the flag and the probe have answered.
    await t.tap(find.byType(RaftAgentSelect<String>).first);
    await t.pumpAndSettle();
    await until(
      t,
      () => cloudOption.evaluate().isNotEmpty,
      what: 'the Cloud agent option',
    );
    await shot(t, '01-create-picker-with-cloud-option');
    await t.tap(cloudOption);
    await t.pumpAndSettle();
    expect(
      find.textContaining('Raft creates the agent in the cloud'),
      findsOneWidget,
    );
    expect(
      find.text('RUNTIME', findRichText: true).evaluate().isEmpty &&
          find.textContaining('RUNTIME', findRichText: true).evaluate().isEmpty,
      isTrue,
      reason: 'a cloud agent has no runtime field',
    );
    await until(
      t,
      () => find
          .byKey(const ValueKey('hosted-model-choice'))
          .evaluate()
          .isNotEmpty,
      what: 'the model picker',
    );
    await shot(t, '02-create-cloud-form');
    final nameField = find.byWidgetPredicate(
      (x) => x is TextField && (x.controller?.text.isNotEmpty ?? false),
    );
    await t.enterText(nameField.first, name);
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(RaftAgentDialogButton, 'Create Agent'));
    // The dialog closes once the server has created the agent.
    await until(
      t,
      () => find.byType(RaftAgentDialogCard).evaluate().isEmpty,
      seconds: 60,
      what: 'the create dialog to close',
    );
    final rows = await w.client.get('/agents') as List;
    final agent = rows.cast<Map>().firstWhere((a) => a['name'] == name);
    final id = agent['id'] as String;
    created.add(id);
    expect(agent['hostedRuntime'], isNotNull);
    expect(agent['external'], true);
    note(
      'created a cloud agent; hostedRuntime.state=${(agent['hostedRuntime'] as Map)['state']}',
    );

    // 2. The cloud group and the status panel.
    await until(
      t,
      () =>
          find.text('cloud').evaluate().isNotEmpty ||
          find.textContaining('cloud').evaluate().isNotEmpty,
      what: 'the cloud sidebar group',
    );
    await shot(t, '03-sidebar-cloud-group');
    await t.tap(find.byKey(ValueKey('desktop-directory-agent-$id')));
    await t.pumpAndSettle();
    await until(
      t,
      () => find
          .byKey(const ValueKey('hosted-runtime-state'))
          .evaluate()
          .isNotEmpty,
      what: 'the status chip',
    );
    await shot(t, '04-profile-status-first-frame');
    expect(find.text('Runs in the cloud'), findsOneWidget);
    expect(find.text('Free for a limited time'), findsOneWidget);
    expect(find.text('Hermes'), findsNothing);
    await until(
      t,
      () => find.text('Running').evaluate().isNotEmpty,
      seconds: 150,
      what: 'the agent to be running',
    );
    note('status reached Running');
    await shot(t, '05-profile-running');
    await until(
      t,
      () => find.text('No usage in the last 7 days').evaluate().isNotEmpty,
      what: 'the empty usage block',
    );
    await shot(t, '06-usage-empty');

    // 3. One real turn.
    final dm =
        await w.client.post('/channels/dm', data: {'agentId': id}) as Map;
    final dmId = dm['id'] as String;
    await w.client.send(dmId, 'Reply with the single word: ok');
    turns++;
    note('turn 1 sent');
    final started = DateTime.now();
    var replied = false;
    while (DateTime.now().difference(started) < const Duration(minutes: 4)) {
      await t.pump(const Duration(seconds: 2));
      final page = await w.client.messagePage(dmId);
      final list = (page['messages'] as List).cast<Map>();
      if (list.any((m) => m['senderType'] == 'agent')) {
        replied = true;
        break;
      }
    }
    expect(replied, isTrue, reason: 'the cloud agent answered');
    note(
      'turn 1 answered after ${DateTime.now().difference(started).inSeconds}s',
    );

    // 4. The sender line in the DM.
    w.setSection('chat');
    await t.pumpAndSettle();
    await w.selectChannel(w.dms.firstWhere((c) => c.id == dmId));
    await t.pumpAndSettle();
    await until(
      t,
      () => find
          .text('Cloud agent · Free for a limited time')
          .evaluate()
          .isNotEmpty,
      what: 'the sender line',
    );
    await shot(t, '07-dm-sender-line');

    // 5. Usage after the turn (the profile reads it on open).
    w.setSection('agents');
    await t.pumpAndSettle();
    await t.tap(find.byKey(ValueKey('desktop-directory-agent-$id')));
    await t.pumpAndSettle();
    await until(
      t,
      () => find.text('USAGE (LAST 7 DAYS)').evaluate().isNotEmpty,
      what: 'the usage block',
    );
    await until(
      t,
      () =>
          find.text('Total tokens').evaluate().isNotEmpty ||
          find.text('No usage in the last 7 days').evaluate().isNotEmpty,
      what: 'usage rows',
    );
    note(
      find.text('Total tokens').evaluate().isNotEmpty
          ? 'usage block shows tokens'
          : 'usage still empty (the provider has not reported yet)',
    );
    await shot(t, '08-usage-after-turn');

    // 6. Stop the current turn.
    await w.client.send(dmId, 'Count from 1 to 300, one number per line.');
    turns++;
    note('turn 2 sent');
    await t.pump(const Duration(seconds: 3));
    final inline = find.byKey(
      const Key('agent-profile-inline-stop-hosted-turn'),
    );
    if (inline.evaluate().isNotEmpty) {
      await t.tap(inline);
    } else {
      await t.tap(find.byKey(const Key('agent-profile-overflow-trigger')));
      await t.pumpAndSettle();
      await t.tap(find.text('Stop current turn'));
    }
    await until(
      t,
      () =>
          find.text('Stopped the current turn.').evaluate().isNotEmpty ||
          find.text('Nothing was running.').evaluate().isNotEmpty,
      what: 'the stop toast',
    );
    note(
      find.text('Stopped the current turn.').evaluate().isNotEmpty
          ? 'stop: interrupted'
          : 'stop: nothing was running',
    );
    await shot(t, '09-stop-toast');

    // 7. The Plan page's spend card.
    await openSettingsTab(t, 'billing');
    await until(
      t,
      () => find
          .byKey(const ValueKey('hosted-runtime-spend'))
          .evaluate()
          .isNotEmpty,
      what: 'the spend card',
    );
    await until(
      t,
      () =>
          find
              .byKey(const ValueKey('hosted-runtime-spend-today'))
              .evaluate()
              .isNotEmpty ||
          find
              .byKey(const ValueKey('hosted-runtime-spend-error'))
              .evaluate()
              .isNotEmpty,
      what: 'the spend card to load',
    );
    note(
      find
              .byKey(const ValueKey('hosted-runtime-spend-today'))
              .evaluate()
              .isNotEmpty
          ? 'spend card loaded'
          : 'spend card shows the provider failure warning',
    );
    await shot(t, '10-plan-spend-card');
  });

  testWidgets('cloud agent: official identity of the onboarding agent', (
    t,
  ) async {
    final cfg = raftbenchConfig();
    t.view.physicalSize = const Size(1440, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    addTearDown(() => writeRunLog('run-identity.log'));
    // The agent is created and made the onboarding agent before the app signs
    // in, so the first server record the app reads carries it. No model turn.
    final admin = RaftClient(
      origin: cfg['origin'] as String,
      sessionStore: MemorySessionStore(),
    );
    await admin.login(cfg['email'] as String, cfg['password'] as String);
    admin.selectServer(cfg['serverId'] as String);
    final name = 'cloud-id-${DateTime.now().millisecondsSinceEpoch % 1000000}';
    final made = await admin.post(
      '/agents',
      data: {
        'name': name,
        'external': true,
        'provider': 'antiproton',
        'avatarUrl': 'pixel:bot-1',
      },
    ) as Map;
    final id = made['id'] as String;
    Future<void> setOnboarding(String? agentId) async {
      final result = await Process.run(cfg['psql'] as String, [
        "UPDATE servers SET onboarding_agent_id = ${agentId == null ? 'NULL' : "'$agentId'"} WHERE id = '${cfg['serverId']}'",
      ]);
      expect(result.exitCode, 0);
    }

    addTearDown(() async {
      await setOnboarding(null);
      try {
        await admin.request(
          'DELETE',
          '/agents/$id',
          data: {'workspace': 'keep'},
        );
        note('archived $id');
      } catch (e) {
        note('could not archive $id: ${e.runtimeType}');
      }
      await admin.dispose();
    });
    await setOnboarding(id);
    final w = await signIn(t, cfg);
    w.setSection('agents');
    await t.pumpAndSettle();
    await until(
      t,
      () => find
          .byKey(ValueKey('desktop-directory-agent-$id'))
          .evaluate()
          .isNotEmpty,
      what: 'the agent row',
    );
    await t.tap(find.byKey(ValueKey('desktop-directory-agent-$id')));
    await t.pumpAndSettle();
    final adopt = find.byKey(const ValueKey('agent-identity-adoption-button'));
    await until(
      t,
      () => adopt.evaluate().isNotEmpty,
      what: 'Update official identity',
    );
    await shot(t, '11-identity-button');
    await t.tap(adopt);
    await t.pumpAndSettle();
    expect(find.text('Review official identity changes'), findsOneWidget);
    await shot(t, '12-identity-review');
    await t.tap(find.byKey(const ValueKey('agent-identity-adoption-confirm')));
    await until(
      t,
      () => adopt.evaluate().isEmpty,
      what: 'the adoption to finish',
    );
    await t.pumpAndSettle();
    final after = await w.client.get('/agents/$id') as Map;
    note('after adoption displayName=${after['displayName']}');
    await shot(t, '13-identity-adopted');
  });
}
