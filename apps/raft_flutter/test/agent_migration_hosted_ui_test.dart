// The cloud as a migration target in the app: the start dialog (Cloud option,
// model, what happens next, the start request), the review with its Confirm,
// Cancel before the switch, and a cloud agent's arrival block.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/agent_migration_section.dart';
import 'package:raft_ui/raft_ui.dart';

class _Transport implements HttpClientAdapter {
  Map<String, dynamic>? migration;
  bool hostedFlag = true, cloudFlag = true, available = true;
  bool modelsLocked = false;
  Map<String, dynamic>? confirmError;
  int confirmStatus = 200;
  final bodies = <String, Object?>{};
  final calls = <String>[];
  Completer<void>? confirmGate;
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) async {
    final key = '${o.method} ${o.path}';
    calls.add(key);
    bodies[key] = o.data;
    dynamic data;
    var status = 200;
    switch (key) {
      case 'POST /auth/login':
        data = {
          'accessToken': 'fixture',
          'refreshToken': 'fixture',
          'user': {'id': 'alice'},
        };
      case 'POST /feature-flags/evaluate':
        data = {
          'evaluations': [
            {'key': 'antiproton_hosted_runtime', 'enabled': cloudFlag},
            {'key': 'agent_migration_hosted_v0', 'enabled': hostedFlag},
          ],
        };
      case 'GET /agent-runtime-providers/antiproton':
        data = {'kind': 'antiproton', 'available': available};
      case 'GET /agent-runtime-providers/antiproton/models':
        data = {
          'models': [
            {'id': 'fast', 'label': 'Fast', 'provider': 'p'},
            {'id': 'smart', 'label': 'Smart', 'provider': 'p'},
          ],
          'default': 'balanced',
          'defaultLabel': 'Balanced',
          'locked': modelsLocked,
        };
      case 'GET /billing/subscription':
        data = {'plan': 'pro'};
      case 'GET /agents/a1/migration':
        data = {'migration': migration};
      case 'POST /agents/a1/migrate':
        data = {'migration': {}};
      case 'POST /agents/a1/migration/confirm-hosted':
        await confirmGate?.future;
        status = confirmError == null ? confirmStatus : 409;
        data = confirmError ?? {'ok': true};
      case 'POST /agents/a1/migration/cancel':
        data = {'ok': true};
      default:
        data = {'error': 'Unexpected endpoint'};
        status = 404;
    }
    return ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _EventClient extends RaftClient {
  _EventClient({required super.transport})
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
      ) {
    user = RaftRecord({'id': 'alice'});
  }
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
}

const _machines = <Map<String, dynamic>>[
  {'id': 'c1', 'name': 'Source', 'status': 'online', 'isComputer': true},
  {'id': 'c2', 'name': 'Target', 'status': 'online', 'isComputer': true},
];

Map<String, dynamic> _m(String state, [Map<String, dynamic> more = const {}]) =>
    {
      'agentId': 'a1',
      'migrationRef': 'mig_1',
      'state': state,
      'revision': 4,
      'sourceMachineId': 'c1',
      'targetKind': 'hosted',
      'targetMachineId': null,
      ...more,
    };

Map<String, dynamic> _review() => _m('in_transit', {
  'readyAt': '2026-10-24T08:00:00.000Z',
  'transferDeadlineAt': '2026-10-24T20:00:00.000Z',
  'hosted': {
    'reviewReadyAt': '2026-10-24T08:05:00.000Z',
    'reviewConfirmedAt': null,
    'importSummary': {
      'importedFileCount': 12,
      'importedBytes': 2048,
      'skipped': [
        {
          'reason': 'git',
          'count': 7,
          'bytes': 4096,
          'largestPaths': [
            'a/.git/1',
            'a/.git/2',
            'a/.git/3',
            'a/.git/4',
            'a/.git/5',
            'a/.git/6',
          ],
        },
      ],
    },
  },
});

void main() {
  late _Transport transport;
  late WorkspaceController w;
  final now = DateTime.utc(2026, 10, 24, 12);

  Future<void> mount(
    WidgetTester tester, {
    Map<String, dynamic> agent = const {
      'id': 'a1',
      'runtime': 'codex',
      'machineId': 'c1',
    },
    bool arrivalOnly = false,
  }) async {
    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final client = _EventClient(
      transport: Dio()..httpClientAdapter = transport,
    );
    client.selectServer('s1');
    w = WorkspaceController(client)
      ..server = RaftRecord({'id': 's1', 'role': 'owner', 'slug': 'acme'});
    addTearDown(() async {
      w.dispose();
      await client.stream.close();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: AgentMigrationSection(
              controller: w,
              agent: agent,
              machines: _machines,
              now: () => now,
              arrivalOnly: arrivalOnly,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() => transport = _Transport());

  final entry = find.widgetWithText(RaftButton, 'Move Agent');
  final dialogSubmit = find.descendant(
    of: find.byType(RaftFormDialog),
    matching: find.widgetWithText(RaftButton, 'Move to the Cloud'),
  );
  final target = find.byKey(const ValueKey('migration-target-computer'));

  group('the start dialog', () {
    testWidgets('offers the cloud only with both flags and the provider', (
      tester,
    ) async {
      await mount(tester);
      expect(entry, findsOneWidget);
      expect(
        find.widgetWithText(RaftButton, 'Move to Another Computer'),
        findsNothing,
      );
    });

    testWidgets('without the flag, or a provider, nothing about the cloud', (
      tester,
    ) async {
      transport.hostedFlag = false;
      await mount(tester);
      expect(entry, findsNothing);
      expect(
        find.widgetWithText(RaftButton, 'Move to Another Computer'),
        findsOneWidget,
      );
      expect(
        transport.calls,
        isNot(contains('GET /agent-runtime-providers/antiproton')),
        reason: 'the probe waits for the flag',
      );
    });

    testWidgets('a provider that is not configured offers nothing', (
      tester,
    ) async {
      transport.available = false;
      await mount(tester);
      expect(entry, findsNothing);
    });

    testWidgets('an older server (no flags route) keeps the computer move', (
      tester,
    ) async {
      transport.cloudFlag = false;
      transport.hostedFlag = false;
      await mount(tester);
      expect(entry, findsNothing);
      expect(
        find.widgetWithText(RaftButton, 'Move to Another Computer'),
        findsOneWidget,
      );
    });

    testWidgets(
      'choosing Cloud shows the model, the notes and Move to the cloud',
      (tester) async {
        await mount(tester);
        await tester.tap(entry);
        await tester.pumpAndSettle();
        expect(find.text('Move Agent'), findsWidgets);
        await tester.tap(target);
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(RaftComboboxPanel),
            matching: find.text('Cloud'),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('hosted-model-choice')),
          findsOneWidget,
        );
        expect(find.text('Default (Balanced)'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('agent-migration-hosted-notes')),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            'The agent stops on Source while the cloud checks its files',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining("Once you confirm the move, it can't be undone."),
          findsOneWidget,
        );
        expect(
          find.textContaining('Your agent will stop while it migrates'),
          findsNothing,
        );
        expect(dialogSubmit, findsOneWidget);
      },
    );

    testWidgets('starting posts a hosted target with the picked model', (
      tester,
    ) async {
      await mount(tester);
      await tester.tap(entry);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(RaftComboboxPanel),
          matching: find.text('Cloud'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('hosted-model-choice')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Smart'));
      await tester.pumpAndSettle();
      await tester.tap(dialogSubmit);
      await tester.pumpAndSettle();
      expect(transport.bodies['POST /agents/a1/migrate'], {
        'target': {'kind': 'hosted', 'hostedModel': 'smart'},
      });
    });

    testWidgets('the default model names none; a locked list names none', (
      tester,
    ) async {
      transport.modelsLocked = true;
      await mount(tester);
      await tester.tap(entry);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(RaftComboboxPanel),
          matching: find.text('Cloud'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('hosted-model-choice-locked')),
        findsOneWidget,
      );
      await tester.tap(dialogSubmit);
      await tester.pumpAndSettle();
      expect(transport.bodies['POST /agents/a1/migrate'], {
        'target': {'kind': 'hosted'},
      });
    });

    testWidgets('a computer target still posts targetComputer', (tester) async {
      await mount(tester);
      await tester.tap(entry);
      await tester.pumpAndSettle();
      // Target is the first computer by default.
      await tester.tap(
        find.descendant(
          of: find.byType(RaftFormDialog),
          matching: find.widgetWithText(RaftButton, 'Move to Another Computer'),
        ),
      );
      await tester.pumpAndSettle();
      expect(transport.bodies['POST /agents/a1/migrate'], {
        'targetComputer': 'c2',
      });
    });
  });

  group('the review', () {
    testWidgets('lists what moves and what stays, with Cancel and Confirm', (
      tester,
    ) async {
      transport.migration = _review();
      await mount(tester);
      expect(find.text('What moves to the cloud'), findsOneWidget);
      expect(find.text('12 files (2.0 KB)'), findsOneWidget);
      expect(find.text('Left behind: Git data (.git)'), findsOneWidget);
      expect(find.text('7 files (4.0 KB)'), findsOneWidget);
      expect(find.text('a/.git/5'), findsOneWidget);
      expect(
        find.text('a/.git/6'),
        findsNothing,
        reason: 'five paths per reason',
      );
      expect(find.text('and 2 more'), findsOneWidget);
      expect(
        find.textContaining(
          "the copy on Source is archived. This can't be undone.",
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Confirm by '), findsOneWidget);
      expect(find.text('Confirm and move'), findsOneWidget);
      // The panel's own Cancel is gone while the review waits: one Cancel.
      expect(find.widgetWithText(RaftButton, 'Cancel'), findsOneWidget);
      expect(
        find.text(
          'Review what moves to the cloud, then confirm. The agent stays stopped on Source until you decide.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Confirm posts the ref and revision, then reads the status', (
      tester,
    ) async {
      transport.migration = _review();
      await mount(tester);
      final reads = transport.calls
          .where((c) => c == 'GET /agents/a1/migration')
          .length;
      transport.migration = _m('arriving', {
        'flippedAt': '2026-10-24T09:00:00Z',
      });
      await tester.tap(find.text('Confirm and move'));
      await tester.pumpAndSettle();
      expect(transport.bodies['POST /agents/a1/migration/confirm-hosted'], {
        'migrationRef': 'mig_1',
        'expectedRevision': 4,
      });
      expect(
        transport.calls.where((c) => c == 'GET /agents/a1/migration').length,
        greaterThan(reads),
      );
      expect(find.text('What moves to the cloud'), findsNothing);
      expect(find.text('Switching the agent to the cloud.'), findsOneWidget);
    });

    testWidgets(
      'a refused Confirm explains and shows what the migration is now',
      (tester) async {
        transport.migration = _review();
        transport.confirmError = {
          'error': 'x',
          'code': 'HOSTED_REVIEW_NOT_READY',
        };
        await mount(tester);
        await tester.tap(find.text('Confirm and move'));
        await tester.pumpAndSettle();
        expect(
          find.text(
            'This migration is not waiting for your confirmation any more. Refresh to see where it stands.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('Confirm is busy while it moves', (tester) async {
      transport.migration = _review();
      final gate = transport.confirmGate = Completer<void>();
      await mount(tester);
      await tester.tap(find.text('Confirm and move'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Moving…'), findsOneWidget);
      final confirm = tester.widget<RaftButton>(
        find.widgetWithText(RaftButton, 'Moving…'),
      );
      expect(confirm.onPressed, isNull);
      gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('Cancel asks first and says where the agent stays', (
      tester,
    ) async {
      transport.migration = _review();
      await mount(tester);
      await tester.tap(find.widgetWithText(RaftButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Canceling is safe'), findsOneWidget);
      expect(
        find.text(
          'Raft will stop moving the agent to the cloud. The agent and its workspace stay on Source, and it goes back to work there.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Canceling finishes once Source confirms. Keep it online until then.',
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('agent-migration-cancel-confirm')),
      );
      await tester.pumpAndSettle();
      expect(transport.bodies['POST /agents/a1/migration/cancel'], {
        'migrationRef': 'mig_1',
        'expectedRevision': 4,
      });
    });
  });

  group('progress and arrival', () {
    testWidgets('the steps and header are the cloud\'s', (tester) async {
      transport.migration = _m('ready');
      await mount(tester);
      expect(find.text('Moving to the cloud'), findsOneWidget);
      for (final step in [
        'Prepare and upload',
        'Check files',
        'Your review',
        'Switch to the cloud',
        'Running in the cloud',
      ]) {
        expect(find.text(step), findsOneWidget, reason: step);
      }
      expect(find.text('Stop agent'), findsNothing);
    });

    testWidgets('after the switch there is no Cancel', (tester) async {
      transport.migration = _m('arriving', {
        'flippedAt': '2026-10-24T09:00:00Z',
      });
      await mount(tester);
      expect(find.widgetWithText(RaftButton, 'Cancel'), findsNothing);
    });

    testWidgets('a cloud agent shows only the move that brought it there', (
      tester,
    ) async {
      transport.migration = _m('completed', {
        'flippedAt': '2026-10-24T09:00:00Z',
        'completedAt': '2026-10-24T09:30:00Z',
      });
      await mount(
        tester,
        agent: const {'id': 'a1', 'runtime': 'external', 'external': true},
        arrivalOnly: true,
      );
      expect(find.text('Moved to the cloud'), findsOneWidget);
      expect(find.text('The agent now runs in the cloud.'), findsOneWidget);
      // No way to start another move from a cloud agent.
      expect(find.widgetWithText(RaftButton, 'Move Agent'), findsNothing);
      expect(
        find.widgetWithText(RaftButton, 'Move to Another Computer'),
        findsNothing,
      );
      expect(
        find.textContaining(
          'Move this agent and its workspace to another computer',
        ),
        findsNothing,
      );
      expect(
        transport.calls,
        isNot(contains('POST /feature-flags/evaluate')),
        reason: 'an arrival block does not ask what it may offer',
      );
      expect(transport.calls, isNot(contains('GET /billing/subscription')));
    });

    testWidgets('a day later, or without a switch, the section is gone', (
      tester,
    ) async {
      transport.migration = _m('completed', {
        'flippedAt': '2026-10-22T09:00:00Z',
        'completedAt': '2026-10-22T09:30:00Z',
      });
      await mount(
        tester,
        agent: const {'id': 'a1', 'runtime': 'external', 'external': true},
        arrivalOnly: true,
      );
      expect(find.text('AGENT MIGRATION'), findsNothing);
    });

    testWidgets('a stalled switch shows the warning banner and the reference', (
      tester,
    ) async {
      transport.migration = _m('arriving', {
        'flippedAt': '2026-10-24T09:00:00Z',
        'failureReason': 'HOSTED_IMPORT_FAILED',
      });
      await mount(
        tester,
        agent: const {'id': 'a1', 'runtime': 'external', 'external': true},
        arrivalOnly: true,
      );
      expect(find.text('Move to the cloud needs attention'), findsOneWidget);
      expect(find.text('The cloud agent needs attention'), findsOneWidget);
      expect(find.text('The agent is already in the cloud.'), findsOneWidget);
      expect(find.text('mig_1'), findsOneWidget);
    });
  });
}
