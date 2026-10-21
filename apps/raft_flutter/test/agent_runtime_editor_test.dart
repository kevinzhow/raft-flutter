import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/agent_runtime_catalog.dart';
import 'package:raft_flutter/features/fleet_views.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _agent({
  String runtime = 'codex',
  String model = 'gpt-5-codex',
  String activity = 'offline',
  String status = 'inactive',
  Map<String, dynamic>? extra,
}) => {
  'id': 'a1',
  'name': 'alpha',
  'displayName': 'Alpha',
  'status': status,
  'activity': activity,
  'runtime': runtime,
  'model': model,
  'machineId': 'm1',
  'reasoningEffort': 'medium',
  'creatorType': 'user',
  'creatorId': 'alice',
  ...?extra,
};

class _Client extends RaftClient {
  _Client(this.agent)
    : super(
        origin: 'https://fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice', 'displayName': 'Alice'});
  }
  Map<String, dynamic> agent;
  final calls = <(String, String, dynamic)>[];
  Object? runtimeOptions = {
    'options': [
      {'runtimeId': 'codex', 'canSelectInThisContext': true},
      {'runtimeId': 'claude', 'canSelectInThisContext': true},
      {'runtimeId': 'cursor', 'canSelectInThisContext': false},
    ],
  };
  Object? Function(String runtime) models = (_) =>
      const RaftApiException('offline');
  Map<String, dynamic>? form;

  /// `GET /agents/a1/migration`: the agent's latest migration, if any.
  Map<String, dynamic>? migration;
  Completer<void>? patchGate;
  Object? patchError;

  /// Applies a PATCH body to the stored agent like the server does.
  void Function(Map body)? onPatch;
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
  @override
  void connect() {}
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
    calls.add((method, path, data));
    if (path == '/agents') return [agent];
    if (path == '/agents/a1' && method == 'GET') return agent;
    if (path == '/agents/a1' && method == 'PATCH') {
      await patchGate?.future;
      if (patchError case final Exception e) throw e;
      if (data is Map) onPatch?.call(data);
      return agent;
    }
    if (path.endsWith('/skills')) return {'global': [], 'workspace': []};
    if (path == '/servers/s/machines') {
      return {
        'machines': [
          {
            'id': 'm1',
            'name': 'Box',
            'status': 'online',
            'runtimes': ['codex', 'claude'],
          },
        ],
      };
    }
    if (path == '/agents/a1/runtime-options') {
      final out = runtimeOptions;
      if (out is Exception) throw out;
      return out;
    }
    if (path.startsWith('/servers/s/machines/m1/runtime-models/')) {
      final out = models(path.split('/').last);
      if (out is Exception) throw out;
      return out;
    }
    if (path == '/agents/a1/runtime-form') return form;
    if (path == '/agents/a1/migration') return {'migration': migration};
    return [];
  }
}

Future<(WorkspaceController, _Client)> _open(
  WidgetTester tester, {
  Map<String, dynamic>? agent,
  void Function(_Client)? setup,
  bool v2Flag = false,
  bool openEditor = true,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final c = _Client(agent ?? _agent())..selectServer('s');
  setup?.call(c);
  final w = WorkspaceController(c)
    ..server = RaftRecord({'id': 's', 'name': 'Fixture', 'role': 'owner'})
    ..runtimeFormV2WebEnabled = v2Flag;
  addTearDown(() async {
    w.dispose();
    await c.stream.close();
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme(RaftFamily.brutal),
      home: Scaffold(
        body: FleetDetail(
          controller: w,
          computers: false,
          initial: const {'id': 'a1'},
          onClose: () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (openEditor) {
    await tester.tap(find.byKey(const ValueKey('agent-edit-runtime')));
    await tester.pumpAndSettle();
  }
  return (w, c);
}

Finder _k(String key) => find.byKey(ValueKey(key));

Future<void> _choose(
  WidgetTester tester,
  String selectKey,
  String label,
) async {
  await tester.tap(_k(selectKey));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

bool _saveEnabled(WidgetTester tester) =>
    tester
        .widget<RaftButton>(
          find.descendant(
            of: _k('runtime-editor-save'),
            matching: find.byType(RaftButton),
          ),
        )
        .onPressed !=
    null;

/// A real server `GET /agents/:id` payload: the structured runtimeConfig next
/// to the flat columns (there is no flat fast-mode column).
Map<String, dynamic> _fastAgent({bool fast = true, String effort = 'medium'}) =>
    _agent(
      extra: {
        'reasoningEffort': effort,
        'runtimeConfig': {
          'version': 1,
          'runtime': 'codex',
          'model': {'kind': 'preset', 'id': 'gpt-5-codex'},
          'mode': {'kind': fast ? 'fast' : 'default'},
          'reasoningEffort': effort,
          'envVars': null,
        },
      },
    );

Finder _modeRow() =>
    find.ancestor(of: find.text('Mode'), matching: find.byType(RaftInfoRow));

void main() {
  testWidgets('the profile shows Fast mode from runtimeConfig.mode.kind', (
    tester,
  ) async {
    await _open(tester, agent: _fastAgent(), openEditor: false);
    expect(_modeRow(), findsOneWidget);
    expect(
      find.descendant(of: _modeRow(), matching: find.text('Fast mode')),
      findsOneWidget,
    );
  });

  testWidgets('the profile shows Default when the mode is default', (
    tester,
  ) async {
    await _open(tester, agent: _fastAgent(fast: false), openEditor: false);
    expect(
      find.descendant(of: _modeRow(), matching: find.text('Default')),
      findsOneWidget,
    );
    expect(find.text('Fast mode'), findsNothing);
  });

  testWidgets('a legacy flat fastMode flag is not a saved mode', (
    tester,
  ) async {
    await _open(
      tester,
      agent: _agent(extra: {'fastMode': true}),
      openEditor: false,
    );
    expect(find.text('Fast mode'), findsNothing);
  });

  testWidgets('the profile shows every reasoning effort of the ladder', (
    tester,
  ) async {
    await _open(tester, agent: _fastAgent(effort: 'ultra'), openEditor: false);
    expect(find.text('Ultra'), findsOneWidget);
  });

  testWidgets('the editor opens with Fast mode checked from runtimeConfig', (
    tester,
  ) async {
    await _open(tester, agent: _fastAgent());
    expect(
      tester
          .widget<RaftAgentOptionCard>(_k('runtime-editor-fast-mode'))
          .checked,
      isTrue,
    );
    // Opened on the saved state: nothing to save yet.
    expect(_saveEnabled(tester), isFalse);
  });

  testWidgets('saving a mode change updates the profile immediately', (
    tester,
  ) async {
    final (_, client) = await _open(
      tester,
      agent: _fastAgent(fast: false),
      setup: (c) => c.onPatch = (body) {
        c.agent = {
          ...c.agent,
          'runtimeConfig': body['runtimeConfig'],
          'reasoningEffort': body['reasoningEffort'],
        };
      },
    );
    expect(
      tester
          .widget<RaftAgentOptionCard>(_k('runtime-editor-fast-mode'))
          .checked,
      isFalse,
    );
    await tester.tap(_k('runtime-editor-fast-mode'));
    await tester.pump();
    await tester.tap(_k('runtime-editor-save'));
    await tester.pumpAndSettle();
    final body = client.calls.where((c) => c.$1 == 'PATCH').single.$3 as Map;
    expect((body['runtimeConfig'] as Map)['mode'], {'kind': 'fast'});
    expect(find.text('EDIT RUNTIME CONFIG'), findsNothing);
    // The profile behind the closed modal now reads the saved mode.
    expect(
      find.descendant(of: _modeRow(), matching: find.text('Fast mode')),
      findsOneWidget,
    );
  });

  testWidgets('without the v2 flag the legacy fields are presented', (
    tester,
  ) async {
    await _open(tester);
    expect(find.text('EDIT RUNTIME CONFIG'), findsOneWidget);
    expect(find.textContaining('RUNTIME', findRichText: true), findsWidgets);
    expect(find.text('Codex CLI'), findsWidgets);
    expect(find.text('GPT-5 Codex'), findsWidgets);
    expect(find.text('Medium'), findsWidgets);
    expect(find.text('Fast mode'), findsWidgets);
    expect(find.text('Save runtime config'), findsOneWidget);
    // Detection failed: the retry line and the suggestion note.
    expect(
      find.textContaining(
        'Could not load models from this Computer.',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(find.textContaining('catalog suggestion'), findsOneWidget);
    expect(_saveEnabled(tester), isFalse);
  });

  testWidgets(
    'the flag without the runtime marker stays on the legacy fields',
    (tester) async {
      await _open(tester, v2Flag: true);
      expect(_k('runtime-editor-model'), findsOneWidget);
    },
  );

  testWidgets(
    'the runtime marker without the flag stays on the legacy fields',
    (tester) async {
      final (_, client) = await _open(
        tester,
        setup: (c) => c.runtimeOptions = {
          'options': [
            {
              'runtimeId': 'codex',
              'canSelectInThisContext': true,
              'runtimeFormV2': {'protocolVersion': 2},
            },
          ],
        },
      );
      expect(_k('runtime-editor-model'), findsOneWidget);
      expect(
        client.calls.where((c) => c.$2 == '/agents/a1/runtime-form'),
        isEmpty,
      );
    },
  );

  testWidgets('flag and marker present the protocol-v2 form', (tester) async {
    final (_, client) = await _open(
      tester,
      v2Flag: true,
      setup: (c) {
        c.runtimeOptions = {
          'options': [
            {
              'runtimeId': 'codex',
              'canSelectInThisContext': true,
              'runtimeFormV2': {'protocolVersion': 2},
            },
          ],
        };
        c.form = {
          'protocolVersion': 2,
          'runtimeId': 'codex',
          'fields': [
            {
              'key': 'fast',
              'kind': 'boolean',
              'label': 'Fast mode extra',
              'initial': false,
            },
          ],
        };
      },
    );
    expect(_k('runtime-editor-model'), findsNothing);
    expect(
      client.calls.where((c) => c.$2 == '/agents/a1/runtime-form'),
      isNotEmpty,
    );
  });

  testWidgets('a v2 form that cannot be loaded says so', (tester) async {
    await _open(
      tester,
      v2Flag: true,
      setup: (c) {
        c.runtimeOptions = {
          'options': [
            {
              'runtimeId': 'codex',
              'canSelectInThisContext': true,
              'runtimeFormV2': {'protocolVersion': 2},
            },
          ],
        };
        // Not a v2 form at all: the load fails.
        c.form = {'protocolVersion': 1};
      },
    );
    expect(
      find.textContaining(
        'Runtime configuration is unavailable. Refresh and try again.',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(_k('runtime-editor-form-error'), findsOneWidget);
  });

  testWidgets('Built-in Pi keeps the v2 form (no legacy fields for it)', (
    tester,
  ) async {
    final (_, client) = await _open(
      tester,
      agent: _agent(runtime: 'builtin', model: 'deepseek/deepseek-v4-pro'),
    );
    expect(_k('runtime-editor-model'), findsNothing);
    expect(
      client.calls.where((c) => c.$2 == '/agents/a1/runtime-form'),
      isNotEmpty,
    );
  });

  testWidgets(
    'an idle agent saves in place with the structured runtimeConfig',
    (tester) async {
      final (_, client) = await _open(tester);
      await _choose(tester, 'runtime-editor-reasoning', 'High');
      expect(_saveEnabled(tester), isTrue);
      await tester.tap(_k('runtime-editor-fast-mode'));
      await tester.pump();
      await tester.tap(_k('runtime-editor-save'));
      await tester.pumpAndSettle();
      final patch = client.calls.where((c) => c.$1 == 'PATCH').single;
      final body = patch.$3 as Map;
      expect(body['runtime'], 'codex');
      expect(body['model'], 'gpt-5-codex');
      expect(body['reasoningEffort'], 'high');
      expect(body.containsKey('restartMode'), isFalse);
      final config = body['runtimeConfig'] as Map;
      expect(config['mode'], {'kind': 'fast'});
      expect(config['model'], {'kind': 'preset', 'id': 'gpt-5-codex'});
      expect(config['version'], runtimeConfigVersion);
      // Saved: the modal is gone.
      expect(find.text('EDIT RUNTIME CONFIG'), findsNothing);
    },
  );

  testWidgets('an active agent asks to restart before applying', (
    tester,
  ) async {
    final (_, client) = await _open(
      tester,
      agent: _agent(activity: 'online', status: 'active'),
    );
    await _choose(tester, 'runtime-editor-reasoning', 'Low');
    await tester.tap(_k('runtime-editor-save'));
    await tester.pumpAndSettle();
    expect(find.text('EDIT RUNTIME CONFIG'), findsNothing);
    expect(find.text('RESTART TO APPLY RUNTIME CONFIG'), findsOneWidget);
    expect(
      find.text('Apply Reasoning and restart this agent now?'),
      findsOneWidget,
    );
    expect(client.calls.where((c) => c.$1 == 'PATCH'), isEmpty);
    await tester.tap(find.text('Restart agent'));
    await tester.pumpAndSettle();
    final body = client.calls.where((c) => c.$1 == 'PATCH').single.$3 as Map;
    expect(body['restartMode'], 'restart');
    expect(body['reasoningEffort'], 'low');
  });

  testWidgets('a Codex model change on an active agent resets the session', (
    tester,
  ) async {
    final bundled = runtimeModelCatalog['codex']!;
    final other = bundled.firstWhere((m) => m.id != 'gpt-5-codex');
    final (_, client) = await _open(
      tester,
      agent: _agent(activity: 'online', status: 'active'),
    );
    await _choose(tester, 'runtime-editor-model', other.label);
    await tester.tap(_k('runtime-editor-save'));
    await tester.pumpAndSettle();
    expect(find.text('SWITCH MODEL AND RESET SESSION'), findsOneWidget);
    expect(
      find.textContaining('resets the current runtime session'),
      findsOneWidget,
    );
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    final body = client.calls.where((c) => c.$1 == 'PATCH').single.$3 as Map;
    expect(body['restartMode'], 'session');
    expect(body['model'], other.id);
  });

  testWidgets(
    'switching runtime asks first and defaults the new runtime model',
    (tester) async {
      final (_, client) = await _open(tester);
      await _choose(tester, 'runtime-editor-runtime', 'Claude Code');
      // The model resets to the new runtime's default and reasoning follows it.
      expect(find.textContaining('Opus'), findsWidgets);
      await tester.tap(_k('runtime-editor-save'));
      await tester.pumpAndSettle();
      expect(find.text('SWITCH RUNTIME CONFIG'), findsOneWidget);
      expect(
        find.text(
          'This will switch the runtime from Codex CLI to Claude Code.',
        ),
        findsOneWidget,
      );
      expect(find.text('Save runtime change'), findsOneWidget);
      await tester.tap(find.text('Save runtime change'));
      await tester.pumpAndSettle();
      final body = client.calls.where((c) => c.$1 == 'PATCH').single.$3 as Map;
      expect(body['runtime'], 'claude');
      expect(body['restartMode'], 'session');
      expect((body['runtimeConfig'] as Map)['provider'], {'kind': 'default'});
    },
  );

  testWidgets('a runtime the context cannot select keeps Save disabled', (
    tester,
  ) async {
    await _open(
      tester,
      setup: (c) => c.runtimeOptions = {
        'options': [
          {'runtimeId': 'codex', 'canSelectInThisContext': false},
        ],
      },
    );
    await _choose(tester, 'runtime-editor-reasoning', 'High');
    expect(_saveEnabled(tester), isFalse);
  });

  testWidgets('a failed save keeps the modal open with the message', (
    tester,
  ) async {
    final (_, client) = await _open(
      tester,
      setup: (c) =>
          c.patchError = const RaftApiException('Rejected', status: 400),
    );
    await _choose(tester, 'runtime-editor-reasoning', 'High');
    await tester.tap(_k('runtime-editor-save'));
    await tester.pumpAndSettle();
    expect(find.text('Rejected'), findsOneWidget);
    expect(find.text('EDIT RUNTIME CONFIG'), findsOneWidget);
    expect(client.calls.where((c) => c.$1 == 'PATCH'), hasLength(1));
  });

  testWidgets('live models fill the picker; retry and rescan ask again', (
    tester,
  ) async {
    final (_, client) = await _open(
      tester,
      setup: (c) => c.models = (_) => {
        'kind': 'live',
        'value': {
          'models': [
            {
              'id': 'gpt-5-codex',
              'label': 'GPT-5 Codex',
              'verified': 'launchable',
            },
            {'id': 'live-only', 'label': 'Live Only'},
          ],
        },
      },
    );
    expect(
      find.text('Could not load models from this Computer.'),
      findsNothing,
    );
    expect(find.textContaining('catalog suggestion'), findsNothing);
    await tester.tap(_k('runtime-editor-model'));
    await tester.pumpAndSettle();
    expect(find.text('Live Only'), findsOneWidget);
    await tester.tap(find.text('Live Only'));
    await tester.pumpAndSettle();
    expect(_saveEnabled(tester), isTrue);
    final before = client.calls
        .where((c) => c.$2.contains('runtime-models'))
        .length;
    await tester.tap(_k('runtime-editor-rescan'));
    await tester.pumpAndSettle();
    expect(
      client.calls.where((c) => c.$2.contains('runtime-models')).length,
      before + 1,
    );
  });

  for (final (reason, expected) in <(String?, String)>[
    (
      'not_installed',
      'Codex CLI was not found on this Computer. Install it, then retry.',
    ),
    (
      'probe_timeout',
      "Checking for Codex CLI on this Computer timed out. Retry, or check this Computer's status.",
    ),
    (
      'permission_denied',
      'Could not check for Codex CLI on this Computer: permission denied. Check permissions on that machine, then retry.',
    ),
    (
      'probe_failed',
      "Could not confirm whether Codex CLI is available on this Computer. Retry, or check this Computer's status.",
    ),
    // An old daemon sends no reason: never "install it".
    (
      null,
      "Could not confirm whether Codex CLI is available on this Computer. Retry, or check this Computer's status.",
    ),
  ]) {
    testWidgets('runtime_not_found with reason $reason', (tester) async {
      await _open(
        tester,
        setup: (c) => c.models = (_) => {
          'kind': 'error',
          'code': 'runtime_not_found',
          'retryable': true,
          'reason': ?reason,
        },
      );
      expect(find.textContaining(expected, findRichText: true), findsOneWidget);
    });
  }

  testWidgets('Retry asks the Computer again after a failure', (tester) async {
    final (_, client) = await _open(tester);
    final before = client.calls
        .where((c) => c.$2.contains('runtime-models'))
        .length;
    tester
        .widget<RaftAgentSourceStatus>(_k('runtime-model-source-status'))
        .onRetry!();
    await tester.pumpAndSettle();
    expect(
      client.calls.where((c) => c.$2.contains('runtime-models')).length,
      before + 1,
    );
  });

  testWidgets(
    'Claude: custom provider needs a URL and key; MORE holds command and env',
    (tester) async {
      final (_, client) = await _open(
        tester,
        agent: _agent(runtime: 'claude', model: 'opus'),
        setup: (c) => c.runtimeOptions = {
          'options': [
            {'runtimeId': 'claude', 'canSelectInThisContext': true},
          ],
        },
      );
      await _choose(tester, 'runtime-editor-provider', 'Custom');
      expect(find.textContaining('API URL', findRichText: true), findsWidgets);
      expect(
        find.text('API URL must start with http:// or https://.'),
        findsOneWidget,
      );
      expect(_saveEnabled(tester), isFalse);
      await tester.enterText(
        _k('runtime-editor-api-url'),
        'https://gw.example.test',
      );
      await tester.enterText(_k('runtime-editor-api-key'), 'sk-test');
      await tester.pump();
      expect(_saveEnabled(tester), isTrue);
      await tester.ensureVisible(_k('runtime-editor-more'));
      await tester.pump();
      await tester.tap(
        find.descendant(
          of: _k('runtime-editor-more'),
          matching: find.text('MORE'),
        ),
      );
      await tester.pump();
      await tester.enterText(_k('runtime-editor-command'), 'claude-dev');
      await tester.ensureVisible(_k('env-add'));
      await tester.pump();
      await tester.tap(_k('env-add'));
      await tester.pump();
      await tester.enterText(_k('env-key-0'), 'FOO');
      await tester.enterText(_k('env-value-0'), 'bar');
      await tester.pump();
      await tester.tap(_k('runtime-editor-save'));
      await tester.pumpAndSettle();
      final body = client.calls.where((c) => c.$1 == 'PATCH').single.$3 as Map;
      final config = body['runtimeConfig'] as Map;
      expect(config['provider'], {
        'kind': 'custom',
        'apiUrl': 'https://gw.example.test',
        'apiKey': 'sk-test',
      });
      expect(config['command'], 'claude-dev');
      expect(config['envVars'], {'FOO': 'bar'});
    },
  );

  testWidgets('a typed model name is used as typed from the Model combobox', (
    tester,
  ) async {
    final (_, client) = await _open(tester);
    await tester.enterText(
      find.descendant(
        of: _k('runtime-editor-model'),
        matching: find.byType(EditableText),
      ),
      'my-model',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use “my-model”'));
    await tester.pumpAndSettle();
    expect(_saveEnabled(tester), isTrue);
    await tester.tap(_k('runtime-editor-save'));
    await tester.pumpAndSettle();
    final patch = client.calls.where((c) => c.$1 == 'PATCH').single;
    expect((patch.$3 as Map)['model'], 'my-model');
  });

  testWidgets('Cancel closes without saving', (tester) async {
    final (_, client) = await _open(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('EDIT RUNTIME CONFIG'), findsNothing);
    expect(client.calls.where((c) => c.$1 == 'PATCH'), isEmpty);
  });

  group('Move to another computer', () {
    Future<_Client> profile(
      WidgetTester tester, {
      required bool flag,
      Map<String, dynamic>? migration,
    }) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = _Client(_agent())
        ..selectServer('s')
        ..migration = migration;
      final w = WorkspaceController(c)
        ..server = RaftRecord({'id': 's', 'name': 'Fixture', 'role': 'owner'})
        ..agentMigrationEnabled = flag;
      addTearDown(() async {
        w.dispose();
        await c.stream.close();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.brutal),
          home: Scaffold(
            body: FleetDetail(
              key: UniqueKey(),
              controller: w,
              computers: false,
              initial: const {'id': 'a1'},
              onClose: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return c;
    }

    bool moveEnabled(WidgetTester tester) =>
        tester
            .widget<RaftButton>(find.widgetWithText(RaftButton, 'Migrate'))
            .onPressed !=
        null;

    const active = {
      'migrationRef': 'ref-1',
      'revision': 2,
      'state': 'in_transit',
      'sourceMachineId': 'm1',
      'targetMachineId': 'm2',
    };

    testWidgets('shows the migration inline and disables Move while it runs', (
      tester,
    ) async {
      await profile(tester, flag: true, migration: active);
      expect(find.text('Migrating to m2'), findsOneWidget);
      expect(find.text('Transferring workspace to m2.'), findsOneWidget);
      // Web: the progress block owns the only action (Cancel) while it runs.
      expect(find.widgetWithText(RaftButton, 'Migrate'), findsNothing);
      expect(find.widgetWithText(RaftButton, 'Cancel'), findsOneWidget);
    });

    testWidgets('no migration shows nothing and keeps Move enabled', (
      tester,
    ) async {
      await profile(tester, flag: true);
      expect(find.textContaining('Migrating to'), findsNothing);
      expect(moveEnabled(tester), isTrue);
    });

    testWidgets('an ended migration stays visible and Move comes back', (
      tester,
    ) async {
      await profile(
        tester,
        flag: true,
        migration: {...active, 'state': 'failed', 'failureReason': 'x'},
      );
      expect(find.text('Migration to m2 needs attention'), findsOneWidget);
      expect(
        find.textContaining('The agent is still on Box and works as usual.'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(RaftButton, 'Try migration again'),
        findsOneWidget,
      );
    });

    testWidgets(
      'a migration push re-reads and the 2s poll covers a missed push',
      (tester) async {
        final c = await profile(tester, flag: true, migration: active);
        int reads() =>
            c.calls.where((x) => x.$2 == '/agents/a1/migration').length;
        final first = reads();
        // A missed push: the server moved on and nothing was sent.
        c.migration = {...active, 'state': 'arriving'};
        await tester.pump(const Duration(seconds: 2, milliseconds: 100));
        await tester.pump();
        expect(reads(), greaterThan(first));
        expect(find.text('Setting up the workspace on m2.'), findsOneWidget);
        // A push for this agent re-reads at once; one for another agent does not.
        final before = reads();
        c.stream.add(
          const RaftEvent('agent:migration-updated', {'agentId': 'zz'}),
        );
        await tester.pump();
        expect(reads(), before);
        c.migration = {...active, 'state': 'completed'};
        c.stream.add(
          const RaftEvent('agent:migration-updated', {'agentId': 'a1'}),
        );
        await tester.pumpAndSettle();
        expect(find.text('Migrated to m2'), findsOneWidget);
        expect(moveEnabled(tester), isTrue);
        // Ended: no more polling.
        final settled = reads();
        await tester.pump(const Duration(seconds: 10));
        expect(reads(), settled);
      },
    );

    testWidgets('is offered only while agent_migration_v0 is on', (
      tester,
    ) async {
      await profile(tester, flag: false);
      expect(find.text('AGENT MIGRATION', skipOffstage: false), findsNothing);
      await profile(tester, flag: true);
      expect(find.text('AGENT MIGRATION', skipOffstage: false), findsOneWidget);
    });
  });
}
