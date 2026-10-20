import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
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
            'runtimes': ['codex'],
          },
        ],
      };
    }
    if (path.endsWith('/skills')) return {'global': [], 'workspace': []};
    return [];
  }
}

Map<String, dynamic> _agent({Object? spawnFailure, bool socketFrame = false}) =>
    {
      'id': 'a1',
      'name': 'alpha',
      'displayName': 'Alpha',
      'status': 'active',
      'activity': 'error',
      'activityDetail': 'codex is not installed on this machine',
      'activityDetailKind': 'runtime_unavailable',
      'runtime': 'codex',
      'model': 'gpt-5-codex',
      'machineId': 'm1',
      'creatorType': 'user',
      'creatorId': 'alice',
      'spawnFailure': ?spawnFailure,
      // A newer socket frame states the reason itself (none here).
      if (socketFrame) 'spawnLookupReason': null,
    };

void main() {
  const installed = 'This runtime is not installed on this computer.';
  const unresolved =
      "Could not confirm whether Codex CLI is available on this Computer. Retry, or check this Computer's status.";

  Future<void> show(WidgetTester t, Map<String, dynamic> agent) async {
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
        theme: raftTheme(RaftFamily.brutal),
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
  }

  testWidgets('a confirmed miss keeps the install copy', (t) async {
    await show(
      t,
      _agent(
        spawnFailure: {
          'reason': 'runtime_not_found',
          'lookupReason': 'not_on_path',
        },
      ),
    );
    expect(find.text(installed), findsOneWidget);
  });

  for (final (lookupReason, expected) in <(String, String)>[
    (
      'lookup_timed_out',
      "Checking for Codex CLI on this Computer timed out. Retry, or check this Computer's status.",
    ),
    (
      'lookup_permission_denied',
      'Could not check for Codex CLI on this Computer: permission denied. Check permissions on that machine, then retry.',
    ),
    ('lookup_failed', unresolved),
  ]) {
    testWidgets('a start failure with $lookupReason is not "install it"', (
      t,
    ) async {
      await show(
        t,
        _agent(
          spawnFailure: {
            'reason': 'runtime_not_found',
            'lookupReason': lookupReason,
          },
        ),
      );
      expect(find.text(expected), findsOneWidget);
      expect(find.text(installed), findsNothing);
    });
  }

  testWidgets('an old daemon (no reason) never says "install it"', (t) async {
    await show(t, _agent(spawnFailure: {'reason': 'runtime_not_found'}));
    expect(find.text(unresolved), findsOneWidget);
    expect(find.text(installed), findsNothing);
  });

  testWidgets('nor does a row that carries no typed carrier at all', (t) async {
    await show(t, _agent());
    expect(find.text(unresolved), findsOneWidget);
    expect(find.text(installed), findsNothing);
  });

  testWidgets(
    'a newer socket frame without a reason overrides the REST carrier',
    (t) async {
      await show(
        t,
        _agent(
          spawnFailure: {
            'reason': 'runtime_not_found',
            'lookupReason': 'not_on_path',
          },
          socketFrame: true,
        ),
      );
      expect(find.text(unresolved), findsOneWidget);
    },
  );
}
