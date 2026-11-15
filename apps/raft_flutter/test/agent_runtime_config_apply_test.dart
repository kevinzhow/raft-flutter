// Web v1.24 AgentProfileInfo.tsx `saveRuntimeFormV2Edit` +
// runtimeConfigApplyNotice.ts: saving a running agent's runtime config sends
// no restartMode (no "Restart to apply" confirmation), reads `configApply`
// from the response and says when it applies in a toast whose one action,
// Restart now, is the ordinary reset, offered only to who may restart.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/agent_runtime_config_apply.dart';
import 'package:raft_flutter/features/fleet_views.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _agent({
  String runtime = 'codex',
  String activity = 'online',
  String status = 'active',
}) => {
  'id': 'a1',
  'name': 'alpha',
  'displayName': 'Alpha',
  'status': status,
  'activity': activity,
  'runtime': runtime,
  'model': runtime == 'codex' ? 'gpt-5-codex' : 'claude-opus',
  'machineId': 'm1',
  'reasoningEffort': 'medium',
  'creatorType': 'user',
  'creatorId': 'alice',
};

class _Client extends RaftClient {
  _Client(this.agent)
    : super(
        origin: 'https://fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice', 'displayName': 'Alice'});
  }
  final Map<String, dynamic> agent;
  final calls = <(String, String, dynamic)>[];
  String? configApply = 'when_idle';
  Object? resetError;
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
      return {...agent, 'configApply': ?configApply};
    }
    if (path == '/agents/a1/reset') {
      if (resetError case final Exception e) throw e;
      return {};
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
      return {
        'options': [
          {'runtimeId': 'codex', 'canSelectInThisContext': true},
          {'runtimeId': 'claude', 'canSelectInThisContext': true},
        ],
      };
    }
    if (path.startsWith('/servers/s/machines/m1/runtime-models/')) {
      throw const RaftApiException('offline');
    }
    if (path == '/agents/a1/migration') return {'migration': null};
    return [];
  }
}

Future<_Client> _open(WidgetTester tester, Map<String, dynamic> agent) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final c = _Client(agent)..selectServer('s');
  final w = WorkspaceController(c)
    ..server = RaftRecord({'id': 's', 'name': 'Fixture', 'role': 'owner'});
  addTearDown(() async {
    w.dispose();
    await c.stream.close();
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme(),
      builder: (context, child) => RaftToastHost(child: child!),
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
  await tester.tap(find.byKey(const ValueKey('agent-edit-runtime')));
  await tester.pumpAndSettle();
  return c;
}

Finder _k(String key) => find.byKey(ValueKey(key));

Future<void> _choose(WidgetTester t, String key, String label) async {
  await t.tap(_k(key));
  await t.pumpAndSettle();
  await t.tap(find.text(label).last);
  await t.pumpAndSettle();
}

Future<void> _save(WidgetTester t) async {
  await t.tap(_k('runtime-editor-save'));
  await t.pumpAndSettle();
}

Iterable<(String, String, dynamic)> _patches(_Client c) =>
    c.calls.where((x) => x.$1 == 'PATCH');

void main() {
  group('saving a running agent', () {
    testWidgets('applies when idle: the toast says so and Restart now resets', (
      t,
    ) async {
      final c = await _open(t, _agent());
      await _choose(t, 'runtime-editor-reasoning', 'Low');
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
      await _choose(t, 'runtime-editor-reasoning', 'Low');
      await _save(t);
      expect(find.text('They apply the next time it starts.'), findsOneWidget);
    });

    testWidgets('restarted: it already happened, no toast', (t) async {
      final c = await _open(t, _agent());
      c.configApply = 'restarted';
      await _choose(t, 'runtime-editor-reasoning', 'Low');
      await _save(t);
      expect(_patches(c), hasLength(1));
      expect(find.textContaining('settings saved'), findsNothing);
    });

    testWidgets('a failed Restart now says so', (t) async {
      (await _open(t, _agent())).resetError = const RaftApiException(
        'down',
        status: 500,
      );
      await _choose(t, 'runtime-editor-reasoning', 'Low');
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
      await _choose(t, 'runtime-editor-reasoning', 'Low');
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
