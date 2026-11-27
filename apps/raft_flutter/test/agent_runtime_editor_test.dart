import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
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
  bool openEditor = true,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final c = _Client(agent ?? _agent())..selectServer('s');
  setup?.call(c);
  final w = WorkspaceController(c)
    ..server = RaftRecord({'id': 's', 'name': 'Fixture', 'role': 'owner'});
  addTearDown(() async {
    w.dispose();
    await c.stream.close();
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme(),
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

  group('Move to Another Computer', () {
    final lastMigration = find.byKey(
      const ValueKey('agent-last-migration-toggle'),
    );
    final migrationDetails = find.byKey(
      const ValueKey('agent-last-migration-body'),
    );

    Future<_Client> profile(
      WidgetTester tester, {
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
        ..server = RaftRecord({'id': 's', 'name': 'Fixture', 'role': 'owner'});
      addTearDown(() async {
        w.dispose();
        await c.stream.close();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQueryData.fromView(tester.view)
                .copyWith(disableAnimations: true),
            child: child!,
          ),
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
            .widget<RaftButton>(
              find.widgetWithText(RaftButton, 'Move to Another Computer'),
            )
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
      await profile(tester, migration: active);
      expect(find.text('Migrating to m2'), findsOneWidget);
      expect(find.text('Transferring workspace to m2.'), findsOneWidget);
      // Web: the progress block owns the only action (Cancel) while it runs.
      expect(
        find.widgetWithText(RaftButton, 'Move to Another Computer'),
        findsNothing,
      );
      expect(
        find.widgetWithText(RaftButton, 'Cancel Migration'),
        findsOneWidget,
      );
    });

    testWidgets('no migration shows nothing and keeps Move enabled', (
      tester,
    ) async {
      await profile(tester);
      expect(find.textContaining('Migrating to'), findsNothing);
      expect(moveEnabled(tester), isTrue);
    });

    testWidgets('a failed migration opens its details and offers retry', (
      tester,
    ) async {
      await profile(
        tester,
        migration: {...active, 'state': 'failed', 'failureReason': 'x'},
      );
      expect(lastMigration, findsOneWidget);
      expect(migrationDetails, findsOneWidget);
      expect(
        find.textContaining('The agent is still on Box and works as usual.'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(RaftButton, 'Try Migration Again'),
        findsOneWidget,
      );
    });

    testWidgets(
      'a migration push re-reads and the 2s poll covers a missed push',
      (tester) async {
        final c = await profile(tester, migration: active);
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
        expect(lastMigration, findsOneWidget);
        expect(
          find.descendant(
            of: lastMigration,
            matching: find.textContaining('Completed', findRichText: true),
          ),
          findsOneWidget,
        );
        expect(migrationDetails, findsNothing);
        expect(moveEnabled(tester), isTrue);
        await tester.tap(lastMigration);
        await tester.pumpAndSettle();
        expect(migrationDetails, findsOneWidget);
        // Ended: no more polling.
        final settled = reads();
        await tester.pump(const Duration(seconds: 10));
        expect(reads(), settled);
      },
    );

    // Web 1.24 AgentMigrationSection.tsx:70, AgentDetailPanel.tsx:873: a
    // computer and the permission (`agent_migration_v0` is retired).
    testWidgets('is offered without a flag', (tester) async {
      await profile(tester);
      expect(find.text('Agent migration', skipOffstage: false), findsOneWidget);
    });
  });
}
