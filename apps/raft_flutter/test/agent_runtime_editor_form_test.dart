// Web 1.24 has one runtime editor: the server-described protocol-v2 form under
// a Runtime select (AgentProfileInfo.tsx `v2EditEligible`,
// `saveRuntimeFormV2Edit`). A runtime whose admission row has no v2 marker
// shows the form-unavailable notice and cannot be saved.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';

import 'fixtures/runtime_editor_harness.dart';

const _surfaces = <(String, Size, TargetPlatform)>[
  ('fold portrait', Size(856, 944), TargetPlatform.android),
  ('fold landscape', Size(944, 856), TargetPlatform.android),
  ('narrow desktop', Size(390, 844), TargetPlatform.linux),
];

void main() {
  testWidgets('a failed Usage flag read leaves the runtime editor available', (
    t,
  ) async {
    await openRuntimeEditor(
      t,
      editorAgent(),
      setup: (client) => client.failUsageFlagEvaluation = true,
    );
    expect(editorKey('runtime-editor-runtime'), findsOneWidget);
    expect(find.text('Usage', skipOffstage: false), findsNothing);
  });

  testWidgets('the Runtime select sits above the saved runtime\'s form', (
    t,
  ) async {
    final c = await openRuntimeEditor(t, editorAgent());
    expect(editorKey('runtime-editor-runtime'), findsOneWidget);
    expect(find.text('Codex CLI'), findsWidgets);
    // The agent's own values come from its edit form, not a create form.
    expect(c.formReads.map((x) => x.$2), contains('/agents/a1/runtime-form'));
    expect(
      c.formReads.where((x) => x.$2.contains('/runtime-forms/v2/')),
      isEmpty,
    );
    expect(find.text('Command from Computer'), findsOneWidget);
    // Opened on the saved state: nothing to save yet.
    expect(runtimeEditorSaveEnabled(t), isFalse);
    // No legacy fields.
    expect(editorKey('runtime-editor-model'), findsNothing);
    expect(editorKey('runtime-editor-reasoning'), findsNothing);
  });

  for (final (name, size, platform) in _surfaces) {
    testWidgets('$name: a stopped agent\'s runtime switch is confirmed first', (
      t,
    ) async {
      final c = await openRuntimeEditor(
        t,
        editorAgent(),
        size: size,
        platform: platform,
      );
      await chooseInEditor(t, 'runtime-editor-runtime', 'Claude Code');
      // The other runtime's create form replaces the edit form.
      expect(
        c.formReads.map((x) => x.$2),
        contains('/servers/s/machines/m1/runtime-forms/v2/claude'),
      );
      // A runtime switch is a change by itself.
      expect(runtimeEditorSaveEnabled(t), isTrue);
      await saveRuntimeEditor(t);
      expect(find.text('Switch runtime config'), findsOneWidget);
      expect(
        find.text(
          'This will switch the runtime from Codex CLI to Claude Code.',
        ),
        findsOneWidget,
      );
      expect(c.patches, isEmpty);
      await t.tap(find.text('Save runtime change'));
      await t.pumpAndSettle();
      final body = c.patches.single.$3 as Map;
      expect(body['restartMode'], 'session');
      expect(body['formDefinitionRef'], {
        'protocolVersion': 2,
        'runtimeId': 'claude',
      });
      expect((body['formValues'] as Map)['model'], 'claude-default');
    });

    testWidgets('$name: a running agent switches runtime without a confirm', (
      t,
    ) async {
      final c = await openRuntimeEditor(
        t,
        editorAgent(activity: 'online', status: 'active'),
        size: size,
        platform: platform,
      );
      await chooseInEditor(t, 'runtime-editor-runtime', 'Claude Code');
      await saveRuntimeEditor(t);
      expect(find.text('Switch runtime config'), findsNothing);
      final body = c.patches.single.$3 as Map;
      expect(body.containsKey('restartMode'), isFalse);
      expect((body['formDefinitionRef'] as Map)['runtimeId'], 'claude');
      expect(find.text('Edit Runtime Config'), findsNothing);
    });
  }

  testWidgets('going back to the saved runtime restores its own form', (
    t,
  ) async {
    final c = await openRuntimeEditor(t, editorAgent());
    await chooseInEditor(t, 'runtime-editor-runtime', 'Claude Code');
    await chooseInEditor(t, 'runtime-editor-runtime', 'Codex CLI');
    // The agent's values again, and no switch left to save.
    expect(
      c.formReads.where((x) => x.$2 == '/agents/a1/runtime-form'),
      hasLength(2),
    );
    expect(runtimeEditorSaveEnabled(t), isFalse);
  });

  testWidgets(
    'a runtime whose row has no v2 marker shows the unavailable notice',
    (t) async {
      final c = await openRuntimeEditor(t, editorAgent());
      final reads = c.formReads.length;
      await chooseInEditor(t, 'runtime-editor-runtime', 'OpenCode');
      expect(editorKey('runtime-form-unavailable'), findsOneWidget);
      expect(
        find.text('Runtime configuration is unavailable.'),
        findsOneWidget,
      );
      // Nothing to load, nothing to save, and no retry that could not help.
      expect(c.formReads.length, reads);
      expect(find.text('Retry'), findsNothing);
      expect(runtimeEditorSaveEnabled(t), isFalse);
      // Back to a runtime with a form: the notice goes and Save follows the form.
      await chooseInEditor(t, 'runtime-editor-runtime', 'Claude Code');
      expect(editorKey('runtime-form-unavailable'), findsNothing);
      expect(runtimeEditorSaveEnabled(t), isTrue);
    },
  );

  testWidgets('an agent whose own runtime has no marker cannot be saved', (
    t,
  ) async {
    final c = await openRuntimeEditor(
      t,
      editorAgent(runtime: 'opencode'),
      setup: (c) => c.options = [
        {'runtimeId': 'opencode', 'canSelectInThisContext': true},
        {
          'runtimeId': 'codex',
          'canSelectInThisContext': true,
          'runtimeFormV2': {'protocolVersion': 2},
        },
      ],
    );
    expect(editorKey('runtime-form-unavailable'), findsOneWidget);
    expect(c.formReads, isEmpty);
    expect(runtimeEditorSaveEnabled(t), isFalse);
    // The runtime select is still there to move the agent to one with a form.
    expect(editorKey('runtime-editor-runtime'), findsOneWidget);
  });

  testWidgets('a runtime the context cannot select keeps Save disabled', (
    t,
  ) async {
    await openRuntimeEditor(
      t,
      editorAgent(),
      setup: (c) => c.options = [
        {
          'runtimeId': 'codex',
          'canSelectInThisContext': false,
          'runtimeFormV2': {'protocolVersion': 2},
        },
      ],
    );
    await typeCommand(t, 'edited-command');
    expect(runtimeEditorSaveEnabled(t), isFalse);
  });

  testWidgets('the server\'s deprecation answer labels the runtime row', (
    t,
  ) async {
    await openRuntimeEditor(
      t,
      editorAgent(),
      setup: (c) => c.options = [
        {
          'runtimeId': 'codex',
          'canSelectInThisContext': true,
          'runtimeFormV2': {'protocolVersion': 2},
        },
        {
          'runtimeId': 'claude',
          'canSelectInThisContext': true,
          'admissionReason': 'deprecated',
          'runtimeFormV2': {'protocolVersion': 2},
        },
      ],
    );
    await t.tap(editorKey('runtime-editor-runtime'));
    await t.pumpAndSettle();
    expect(find.text('Claude Code (deprecated)'), findsOneWidget);
    expect(find.text('Codex CLI (deprecated)'), findsNothing);
  });

  testWidgets('an idle agent saves the edited values in place', (t) async {
    final c = await openRuntimeEditor(t, editorAgent());
    await typeCommand(t, 'edited-command');
    expect(runtimeEditorSaveEnabled(t), isTrue);
    await saveRuntimeEditor(t);
    final body = c.patches.single.$3 as Map;
    expect(body.containsKey('restartMode'), isFalse);
    expect(body['formDefinitionRef'], {
      'protocolVersion': 2,
      'runtimeId': 'codex',
    });
    expect((body['formValues'] as Map)['command'], 'edited-command');
    expect(find.text('Edit Runtime Config'), findsNothing);
  });

  testWidgets('a failed save keeps the editor open and marks the field', (
    t,
  ) async {
    final c = await openRuntimeEditor(
      t,
      editorAgent(),
      setup: (c) => c.patchError = RaftApiException.response(
        'Command is not allowed',
        status: 400,
        body: {
          'error': 'Command is not allowed',
          'issues': [
            {'pointer': '/formValues/command'},
          ],
        },
      ),
    );
    await typeCommand(t, 'rm -rf');
    await saveRuntimeEditor(t);
    expect(find.text('Edit Runtime Config'), findsOneWidget);
    expect(c.patches, hasLength(1));
    // The banner and the field both carry the server's text.
    expect(find.text('Command is not allowed'), findsWidgets);
    expect(editorKey('runtime-editor-error'), findsOneWidget);
  });

  testWidgets('Cancel closes without saving', (t) async {
    final c = await openRuntimeEditor(t, editorAgent());
    await typeCommand(t, 'edited-command');
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(find.text('Edit Runtime Config'), findsNothing);
    expect(c.patches, isEmpty);
  });

  group('the model limits warning above the Built-in form', () {
    Map<String, dynamic> builtin({bool reported = true}) => editorAgent(
      runtime: 'builtin',
      extra: {
        'modelLimits': {'defaultsReported': reported},
      },
    );
    void builtinOptions(EditorClient c) => c.options = [
      {
        'runtimeId': 'builtin',
        'canSelectInThisContext': true,
        'runtimeFormV2': {'protocolVersion': 2},
      },
      {
        'runtimeId': 'codex',
        'canSelectInThisContext': true,
        'runtimeFormV2': {'protocolVersion': 2},
      },
    ];
    // The profile behind the modal shows its own copy of the warning.
    final warning = find.descendant(
      of: editorKey('agent-runtime-editor'),
      matching: editorKey('agent-model-limits-defaults-warning'),
    );

    testWidgets('shows while nothing is changed and goes with the first edit', (
      t,
    ) async {
      await openRuntimeEditor(t, builtin(), setup: builtinOptions);
      expect(warning, findsOneWidget);
      expect(
        find.descendant(
          of: warning,
          matching: find.text('This model may be using Raft default limits'),
        ),
        findsOneWidget,
      );
      await typeCommand(t, 'edited-command');
      expect(warning, findsNothing);
    });

    testWidgets('is not shown when the Computer reported nothing', (t) async {
      await openRuntimeEditor(
        t,
        builtin(reported: false),
        setup: builtinOptions,
      );
      expect(warning, findsNothing);
    });

    testWidgets('is not shown for another runtime, even when reported', (
      t,
    ) async {
      await openRuntimeEditor(
        t,
        editorAgent(
          extra: {
            'modelLimits': {'defaultsReported': true},
          },
        ),
      );
      expect(warning, findsNothing);
    });

    testWidgets('is not shown after switching the draft away from Built-in', (
      t,
    ) async {
      await openRuntimeEditor(t, builtin(), setup: builtinOptions);
      expect(warning, findsOneWidget);
      await chooseInEditor(t, 'runtime-editor-runtime', 'Codex CLI');
      expect(warning, findsNothing);
    });
  });

  group('the profile Model row', () {
    Future<EditorClient> profile(
      WidgetTester t,
      Map<String, dynamic> agent,
    ) async {
      // Only the profile: the editor is not opened here.
      return openRuntimeEditor(t, agent).then((c) async {
        await t.tap(find.text('Cancel'));
        await t.pumpAndSettle();
        return c;
      });
    }

    final hint = editorKey('agent-runtime-config-running');

    testWidgets('says what runs while a saved model waits for the idle point', (
      t,
    ) async {
      await profile(
        t,
        editorAgent(
          activity: 'online',
          status: 'active',
          extra: {
            'runtimeProfile': {
              'current': {'runtime': 'codex', 'model': 'gpt-6-luna'},
            },
          },
        ),
      );
      expect(hint, findsOneWidget);
      expect(
        find.textContaining('Running GPT-6 Luna · switches to'),
        findsOneWidget,
      );
      expect(find.textContaining('when idle'), findsOneWidget);
    });

    testWidgets('names the runtimes when the running runtime differs', (
      t,
    ) async {
      await profile(
        t,
        editorAgent(
          activity: 'online',
          status: 'active',
          extra: {
            'runtimeProfile': {
              'current': {'runtime': 'claude', 'model': 'opus'},
            },
          },
        ),
      );
      expect(
        find.text('Running Claude Code · switches to Codex CLI when idle'),
        findsOneWidget,
      );
    });

    testWidgets('says nothing when the running model is the saved one', (
      t,
    ) async {
      await profile(
        t,
        editorAgent(
          activity: 'online',
          status: 'active',
          extra: {
            'runtimeProfile': {
              'current': {'runtime': 'codex', 'model': 'gpt-5-codex'},
            },
          },
        ),
      );
      expect(hint, findsNothing);
    });

    testWidgets('says nothing for a stopped agent or an unknown profile', (
      t,
    ) async {
      await profile(
        t,
        editorAgent(
          extra: {
            'runtimeProfile': {
              'current': {'runtime': 'claude', 'model': 'opus'},
            },
          },
        ),
      );
      expect(hint, findsNothing);
    });

    testWidgets('shows the model limits warning only when reported', (t) async {
      await profile(
        t,
        editorAgent(
          extra: {
            'modelLimits': {'defaultsReported': true},
          },
        ),
      );
      expect(editorKey('agent-model-limits-defaults-warning'), findsOneWidget);
    });

    testWidgets('does not show the warning without a report', (t) async {
      await profile(t, editorAgent());
      expect(editorKey('agent-model-limits-defaults-warning'), findsNothing);
    });
  });
}
