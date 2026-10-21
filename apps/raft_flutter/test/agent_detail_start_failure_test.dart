import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/runtime_error.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/fleet_views.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Client extends RaftClient {
  Map<String, dynamic>? agent;
  _Client()
    : super(
        origin: 'https://fixture.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice', 'displayName': 'Alice'});
  }
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
    if (path == '/agents') return [agent];
    if (path == '/agents/a1' && method == 'GET') return agent;
    if (path == '/servers/s/machines') {
      return {
        'machines': [
          {
            'id': 'm1',
            'name': 'Box',
            'status': 'online',
            'runtimes': ['codex', 'copilot'],
          },
        ],
      };
    }
    if (path.endsWith('/skills')) return {'global': [], 'workspace': []};
    return [];
  }
}

Map<String, dynamic> _agent({
  String runtime = 'codex',
  Object? spawnFailure,
  String detailKind = 'runtime_unavailable',
}) => {
  'id': 'a1',
  'name': 'alpha',
  'displayName': 'Alpha',
  'status': 'offline',
  'activity': 'offline',
  'activityDetail': 'Start failed: daemon says no',
  'activityDetailKind': detailKind,
  'runtime': runtime,
  'model': 'gpt-5-codex',
  'machineId': 'm1',
  'creatorType': 'user',
  'creatorId': 'alice',
  'spawnFailure': ?spawnFailure,
};

const _paused =
    ' — automatic restarts are paused until you change the model or API key, or restart the agent';

String _english(String source, Map<String, Object?> values) =>
    source.replaceAllMapped(
      RegExp(r'\{([a-z]+)\}'),
      (m) => '${values[m[1]] ?? m[0]}',
    );

void main() {
  group('spawnFailureDetailText (Web formatSpawnFailureDetail)', () {
    String? text(Map<String, dynamic>? failure, [String detail = 'daemon']) =>
        spawnFailureDetailText(failure, detail, _english);

    test('nothing to replace without a carrier or a pause', () {
      expect(text(null), isNull);
      expect(text({'reason': 'runtime_spawn_failed'}), isNull);
    });

    test('a pause wraps the daemon detail', () {
      expect(
        text({'reason': 'runtime_login_required', 'autoRestartPaused': true}),
        'daemon$_paused',
      );
    });

    test('model_not_found has catalog copy, paused or not', () {
      const copy =
          'Model "gpt-x" is not available for this runtime — it may have been renamed or removed, or its provider has no API key on this computer. Pick another model or fix the key in the agent settings';
      expect(text({'reason': 'model_not_found', 'model': 'gpt-x'}), copy);
      expect(
        text({
          'reason': 'model_not_found',
          'model': 'gpt-x',
          'autoRestartPaused': true,
        }),
        '$copy$_paused',
      );
      expect(
        text({'reason': 'model_not_found'}),
        contains('Model "?" is not available'),
      );
    });

    test('session_needs_reset points at Reset, never at a plain restart', () {
      final reset = text({
        'reason': 'session_needs_reset',
        'autoRestartPaused': true,
      });
      expect(reset, startsWith("This agent's conversation no longer fits"));
      expect(reset, contains('Reset Session & Restart'));
      expect(reset, isNot(contains('or restart the agent')));
    });

    test('the carrier is kept only for a runtime_unavailable state', () {
      expect(spawnFailureCarrier('other', {'reason': 'x'}), isNull);
      expect(spawnFailureCarrier('runtime_unavailable', {'oops': 1}), isNull);
      expect(spawnFailureCarrier('runtime_unavailable', {'reason': 'x'}), {
        'reason': 'x',
      });
    });
  });

  Future<_Client> show(WidgetTester t, Map<String, dynamic> agent) async {
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(900, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final c = _Client()
      ..agent = agent
      ..selectServer('s');
    final w = WorkspaceController(c)
      ..server = RaftRecord({'id': 's', 'name': 'Fixture', 'role': 'owner'});
    addTearDown(() async {
      w.dispose();
      await c.stream.close();
    });
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: Scaffold(
          body: FleetDetail(
            controller: w,
            computers: false,
            initial: agent,
            onClose: () {},
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    return c;
  }

  group('agent status line for a failed start', () {
    testWidgets('a paused auto restart says how to lift it', (t) async {
      await show(
        t,
        _agent(
          spawnFailure: {
            'reason': 'runtime_login_required',
            'autoRestartPaused': true,
          },
        ),
      );
      expect(find.text('Start failed: daemon says no$_paused'), findsOneWidget);
    });

    testWidgets('model_not_found names the model', (t) async {
      await show(
        t,
        _agent(spawnFailure: {'reason': 'model_not_found', 'model': 'gpt-x'}),
      );
      expect(
        find.textContaining('Model "gpt-x" is not available for this runtime'),
        findsOneWidget,
      );
      expect(find.textContaining('daemon says no'), findsNothing);
    });

    testWidgets('session_needs_reset replaces the generic paused copy', (
      t,
    ) async {
      await show(
        t,
        _agent(
          spawnFailure: {
            'reason': 'session_needs_reset',
            'autoRestartPaused': true,
          },
        ),
      );
      expect(find.textContaining('Reset Session & Restart'), findsOneWidget);
      expect(
        find.textContaining('automatic restarts are paused'),
        findsNothing,
      );
    });

    testWidgets('a socket frame carries the typed reason too', (t) async {
      final c = await show(t, _agent());
      expect(find.text('Start failed: daemon says no'), findsOneWidget);
      c.stream.add(
        const RaftEvent('agent:activity', {
          'agentId': 'a1',
          'activity': 'offline',
          'detail': 'Start failed: daemon says no',
          'detailKind': 'runtime_unavailable',
          'spawnFailure': {
            'reason': 'session_needs_reset',
            'autoRestartPaused': true,
          },
        }),
      );
      await t.pumpAndSettle();
      expect(find.textContaining('Reset Session & Restart'), findsOneWidget);
      // A later frame without the carrier clears it.
      c.stream.add(
        const RaftEvent('agent:activity', {
          'agentId': 'a1',
          'activity': 'offline',
          'detail': 'Start failed: daemon says no',
          'detailKind': 'runtime_unavailable',
        }),
      );
      await t.pumpAndSettle();
      expect(find.text('Start failed: daemon says no'), findsOneWidget);
    });

    testWidgets('without a typed carrier the daemon detail stays', (t) async {
      await show(t, _agent());
      expect(find.text('Start failed: daemon says no'), findsOneWidget);
    });

    testWidgets('the carrier does not apply to another detail kind', (t) async {
      await show(
        t,
        _agent(
          detailKind: 'stopped',
          spawnFailure: {'reason': 'model_not_found', 'model': 'gpt-x'},
        ),
      );
      expect(find.textContaining('Model "gpt-x"'), findsNothing);
    });
  });

  group('deprecated runtime warning (Web currentRuntimeDeprecated)', () {
    const warning =
        'This agent uses a deprecated runtime. It can keep running, but new agents cannot select this runtime.';

    testWidgets('a deprecated runtime shows the banner under Runtime', (
      t,
    ) async {
      await show(t, _agent(runtime: 'copilot'));
      expect(find.text(warning), findsOneWidget);
      expect(
        t.getTopLeft(find.text(warning)).dy,
        greaterThan(t.getTopLeft(find.text('Copilot CLI (deprecated)')).dy),
      );
    });

    testWidgets('a current runtime has none', (t) async {
      await show(t, _agent());
      expect(find.text(warning), findsNothing);
    });
  });
}
