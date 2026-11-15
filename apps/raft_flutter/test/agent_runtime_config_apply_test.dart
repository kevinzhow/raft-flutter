// Web v1.24 AgentProfileInfo.tsx `saveRuntimeFormV2Edit` +
// runtimeConfigApplyNotice.ts: saving a running agent's runtime config sends
// no restartMode (no "Restart to apply" confirmation), reads `configApply`
// from the response and says when it applies in a toast whose one action,
// Restart now, is the ordinary reset, offered only to who may restart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/agent_runtime_config_apply.dart';
import 'package:raft_ui/raft_ui.dart';

import 'fixtures/runtime_editor_harness.dart';

Map<String, dynamic> _agent({
  String activity = 'online',
  String status = 'active',
}) => editorAgent(activity: activity, status: status);

Future<EditorClient> _open(WidgetTester tester, Map<String, dynamic> agent) =>
    openRuntimeEditor(tester, agent, toasts: true);

/// An edit the saved form counts as a change.
Future<void> _edit(WidgetTester t) => typeCommand(t, 'edited-command');

Future<void> _choose(WidgetTester t, String key, String label) =>
    chooseInEditor(t, key, label);

Future<void> _save(WidgetTester t) => saveRuntimeEditor(t);

Iterable<(String, String, dynamic)> _patches(EditorClient c) => c.patches;

void main() {
  group('saving a running agent', () {
    testWidgets('applies when idle: the toast says so and Restart now resets', (
      t,
    ) async {
      final c = await _open(t, _agent());
      await _edit(t);
      await _save(t);
      expect(find.text('Restart to apply runtime config'), findsNothing);
      expect(find.text('Edit Runtime Config'), findsNothing);
      expect(
        (_patches(c).single.$3 as Map).containsKey('restartMode'),
        isFalse,
      );
      expect(find.text("Alpha's settings saved"), findsOneWidget);
      expect(find.text("They apply when it's next idle."), findsOneWidget);
      expect(c.calls.where((x) => x.$2.endsWith('/reset')), isEmpty);
      await t.tap(find.text('Restart now'));
      await t.pumpAndSettle();
      final reset = c.calls.singleWhere((x) => x.$2 == '/agents/a1/reset');
      expect(reset.$3, {'mode': 'restart'});
      // The action clears the toast: it does not come back.
      expect(find.text("Alpha's settings saved"), findsNothing);
    });

    testWidgets(
      'a runtime switch starts a new session: Restart now resets it',
      (t) async {
        final c = await _open(t, _agent());
        await _choose(t, 'runtime-editor-runtime', 'Claude Code');
        await _save(t);
        expect(find.text('Switch runtime config'), findsNothing);
        expect(
          (_patches(c).single.$3 as Map).containsKey('restartMode'),
          isFalse,
        );
        expect(
          find.text("It starts a new session when it's next idle."),
          findsOneWidget,
        );
        await t.tap(find.text('Restart now'));
        await t.pumpAndSettle();
        expect(c.calls.singleWhere((x) => x.$2 == '/agents/a1/reset').$3, {
          'mode': 'session',
        });
      },
    );

    testWidgets('a daemon too old to apply when idle: next start', (t) async {
      (await _open(t, _agent())).configApply = 'saved';
      await _edit(t);
      await _save(t);
      expect(find.text('They apply the next time it starts.'), findsOneWidget);
    });

    testWidgets('restarted: it already happened, no toast', (t) async {
      final c = await _open(t, _agent());
      c.configApply = 'restarted';
      await _edit(t);
      await _save(t);
      expect(_patches(c), hasLength(1));
      expect(find.textContaining('settings saved'), findsNothing);
    });

    testWidgets('a failed Restart now says so', (t) async {
      (await _open(t, _agent())).resetError = const RaftApiException(
        'down',
        status: 500,
      );
      await _edit(t);
      await _save(t);
      await t.tap(find.text('Restart now'));
      await t.pumpAndSettle();
      expect(find.text('Restart failed.'), findsOneWidget);
    });
  });

  group('a stopped agent', () {
    testWidgets('a plain change saves in place with no toast', (t) async {
      final c = await _open(t, _agent(activity: 'offline', status: 'inactive'))
        ..configApply = 'saved';
      await _edit(t);
      await _save(t);
      expect(
        (_patches(c).single.$3 as Map).containsKey('restartMode'),
        isFalse,
      );
      expect(find.textContaining('settings saved'), findsNothing);
      expect(find.text('Edit Runtime Config'), findsNothing);
    });

    testWidgets(
      'a runtime switch is confirmed and sent as restartMode session',
      (t) async {
        final c = await _open(
          t,
          _agent(activity: 'offline', status: 'inactive'),
        );
        await _choose(t, 'runtime-editor-runtime', 'Claude Code');
        await _save(t);
        expect(find.text('Switch runtime config'), findsOneWidget);
        expect(_patches(c), isEmpty);
        await t.tap(find.text('Save runtime change'));
        await t.pumpAndSettle();
        expect((_patches(c).single.$3 as Map)['restartMode'], 'session');
        expect(find.textContaining('settings saved'), findsNothing);
      },
    );
  });

  group('announceRuntimeConfigApply', () {
    Future<void> announce(
      WidgetTester t, {
      required AgentConfigApply? apply,
      required bool active,
      Future<void> Function(String)? restartNow,
    }) async {
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          builder: (context, child) => RaftToastHost(child: child!),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => announceRuntimeConfigApply(
                context,
                configApply: apply,
                agentActive: active,
                agentName: 'Alpha',
                newSession: false,
                restartNow: restartNow,
              ),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await t.tap(find.text('go'));
      await t.pumpAndSettle();
    }

    testWidgets('no Restart now for someone who may not restart it', (t) async {
      await announce(t, apply: AgentConfigApply.whenIdle, active: true);
      expect(find.text("Alpha's settings saved"), findsOneWidget);
      expect(find.text('Restart now'), findsNothing);
    });

    testWidgets('nothing for restarted, an unknown value or a stopped agent', (
      t,
    ) async {
      await announce(t, apply: AgentConfigApply.restarted, active: true);
      expect(find.textContaining('settings saved'), findsNothing);
      await announce(t, apply: null, active: true);
      expect(find.textContaining('settings saved'), findsNothing);
      await announce(t, apply: AgentConfigApply.saved, active: false);
      expect(find.textContaining('settings saved'), findsNothing);
    });

    test('configApply parses the three values only', () {
      expect(
        agentConfigApplyOf({'configApply': 'when_idle'}),
        AgentConfigApply.whenIdle,
      );
      expect(
        agentConfigApplyOf({'configApply': 'restarted'}),
        AgentConfigApply.restarted,
      );
      expect(
        agentConfigApplyOf({'configApply': 'saved'}),
        AgentConfigApply.saved,
      );
      expect(agentConfigApplyOf({'configApply': 'later'}), isNull);
      expect(agentConfigApplyOf(null), isNull);
    });

    test('who may restart: a managed agent, creator or capability', () {
      final row = {'creatorType': 'user', 'creatorId': 'alice'};
      bool can({
        Map? agent,
        String user = 'bob',
        bool control = true,
        bool external = false,
      }) => canRestartAgentAfterSave(
        agent: agent ?? row,
        currentUserId: user,
        controlAgentRuntime: control,
        external: external,
      );
      expect(can(), isTrue);
      expect(can(control: false), isFalse);
      expect(can(control: false, user: 'alice'), isTrue);
      expect(can(external: true), isFalse);
      expect(can(agent: {...row, 'deletedAt': '2026-01-01'}), isFalse);
    });
  });
}
