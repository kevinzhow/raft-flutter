import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/agent_migration_section.dart';
import 'package:raft_ui/raft_ui.dart';

class _MigrationTransport implements HttpClientAdapter {
  _MigrationTransport({this.disabled = false});
  final bool disabled;
  int revision = 2;
  final requests = <Map<String, dynamic>>[];

  /// The migration state served by the status endpoint; `completed` also
  /// moves the agent to the target computer, as the server does.
  String state = 'in_transit';

  /// `GET /billing/subscription` plan; null answers 404 (billing unavailable).
  String? plan = 'pro';

  /// Answer `POST /agents/a1/migrate` with MIGRATION_PRO_PLAN_REQUIRED.
  bool startDenied = false;

  /// Answer `POST /agents/a1/migrate` with this error body (status 409).
  Map<String, dynamic>? startError;

  /// Fields merged into the served migration (timestamps, failure reason...).
  Map<String, dynamic> extra = {};

  /// How many cancel requests are refused as stale before one is accepted;
  /// each refusal bumps the revision, as a running migration does.
  int staleCancels = 99;

  /// Answer `GET /agents/a1/migration` with a 500 instead.
  bool statusFails = false;
  final posted = <String>[];
  final calls = <String>[];
  int count(String route) => calls.where((c) => c == route).length;
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) async {
    dynamic data;
    var status = 200;
    calls.add('${o.method} ${o.path}');
    switch ('${o.method} ${o.path}') {
      case 'POST /auth/login':
        data = {
          'accessToken': 'fixture',
          'refreshToken': 'fixture',
          'user': {'id': 'alice'},
        };
      case 'GET /agents/a1':
        data = {
          'id': 'a1',
          'name': 'Fixture agent',
          'creatorType': 'user',
          'creatorId': 'alice',
          'runtime': 'codex',
          'machineId': state == 'completed' ? 'c2' : 'c1',
        };
      case 'GET /agents':
        data = [
          {
            'id': 'a1',
            'name': 'Fixture agent',
            'machineId': state == 'completed' ? 'c2' : 'c1',
          },
        ];
      case 'GET /billing/subscription':
        status = plan == null ? 404 : 200;
        data = plan == null ? {'error': 'Not found'} : {'plan': plan};
      case 'POST /agents/a1/migrate':
        posted.add('${o.data['targetComputer']}');
        status = startDenied
            ? 403
            : startError != null
            ? 409
            : 200;
        data = startDenied
            ? {
                'error': 'Agent migration requires a Pro plan',
                'code': 'MIGRATION_PRO_PLAN_REQUIRED',
              }
            : startError ?? {'migration': {}};
      case 'GET /servers/s1/machines':
        data = {
          'machines': [
            {
              'id': 'c1',
              'name': 'Source',
              'status': 'online',
              'isComputer': true,
            },
            {
              'id': 'c2',
              'name': 'Target',
              'status': 'online',
              'isComputer': true,
            },
            {
              'id': 'c3',
              'name': 'Sleepy',
              'status': 'offline',
              'isComputer': true,
            },
            {'id': 'c4', 'name': 'Legacy', 'status': 'online'},
          ],
        };
      case 'GET /agents/a1/migration':
        status = disabled
            ? 403
            : statusFails
            ? 500
            : 200;
        data = disabled
            ? {'error': 'Agent migration UI is not enabled on this server'}
            : statusFails
            ? {'error': 'Boom internal detail'}
            : {
                'migration': {
                  'migrationRef': 'fixture-ref',
                  'revision': revision,
                  'state': state,
                  'sourceMachineId': 'c1',
                  'targetMachineId': 'c2',
                  ...extra,
                },
              };
      case 'POST /agents/a1/migration/cancel':
        requests.add(Map<String, dynamic>.from(o.data));
        if (staleCancels > 0) {
          staleCancels--;
          revision++;
          status = 409;
          data = {
            'error': 'Migration changed; refresh before retrying',
            'code': 'MIGRATION_REVISION_STALE',
          };
        } else {
          state = 'cancel_requested_pre_flip';
          revision++;
          data = {'migration': {}};
        }
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
      );
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
}

Future<WorkspaceController> _fixture(_MigrationTransport transport) async {
  final client = _EventClient(transport: Dio()..httpClientAdapter = transport);
  await client.login('fixture', 'fixture');
  client.selectServer('s1');
  final w = WorkspaceController(client)
    ..server = RaftRecord({'id': 's1', 'role': 'owner'});
  return w;
}

const _machines = <Map<String, dynamic>>[
  {'id': 'c1', 'name': 'Source', 'status': 'online', 'isComputer': true},
  {'id': 'c2', 'name': 'Target', 'status': 'online', 'isComputer': true},
  {'id': 'c3', 'name': 'Sleepy', 'status': 'offline', 'isComputer': true},
  {'id': 'c4', 'name': 'Legacy', 'status': 'online'},
];

/// The agent detail's mount of the section: the agent row and the computers
/// come from the parent. A completed migration has moved the agent to c2.
Widget _host(
  WorkspaceController w, {
  bool completed = false,
  DateTime Function()? now,
  Locale? locale,
}) => MaterialApp(
  locale: locale,
  supportedLocales: const [Locale('en'), Locale('zh')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  theme: raftTheme(RaftFamily.elegant),
  home: Scaffold(
    body: SingleChildScrollView(
      child: AgentMigrationSection(
        controller: w,
        agent: {
          'id': 'a1',
          'runtime': 'codex',
          'machineId': completed ? 'c2' : 'c1',
        },
        machines: _machines,
        now: now,
      ),
    ),
  ),
);

final _migrateButton = find.widgetWithText(RaftButton, 'Migrate');
final _dialogMigrate = find.descendant(
  of: find.byType(RaftFormDialog),
  matching: find.widgetWithText(RaftButton, 'Migrate'),
);

void main() {
  testWidgets('a disabled migration API is a banner and offers nothing else', (
    tester,
  ) async {
    final t = _MigrationTransport(disabled: true);
    final w = (await tester.runAsync(() => _fixture(t)))!;
    addTearDown(w.dispose);
    await tester.pumpWidget(_host(w));
    await tester.pumpAndSettle();
    expect(find.text("Can't load migration status"), findsOneWidget);
    expect(_migrateButton, findsOneWidget);
    expect(find.text('Assign computer'), findsNothing);
  });
  Future<(_MigrationTransport, WorkspaceController)> mount(
    WidgetTester tester, {
    String state = 'in_transit',
    String? plan = 'pro',
    DateTime Function()? now,
    Locale? locale,
    void Function(_MigrationTransport t)? setup,
  }) async {
    final t = _MigrationTransport()
      ..state = state
      ..plan = plan;
    setup?.call(t);
    final w = (await tester.runAsync(() => _fixture(t)))!;
    addTearDown(() async {
      w.dispose();
      await (w.client as _EventClient).stream.close();
    });
    await tester.pumpWidget(
      _host(w, completed: state == 'completed', now: now, locale: locale),
    );
    await tester.pumpAndSettle();
    return (t, w);
  }

  group('missed-event fallback (Web realtime.ts)', () {
    testWidgets('an active migration is polled every 2s until it ends', (
      tester,
    ) async {
      final (t, _) = await mount(tester);
      final first = t.count('GET /agents/a1/migration');
      expect(find.text('Migrating to Target'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(t.count('GET /agents/a1/migration'), first);
      await tester.pump(const Duration(seconds: 1, milliseconds: 100));
      expect(t.count('GET /agents/a1/migration'), first + 1);
      // The server finishes without any push reaching this client.
      t.state = 'completed';
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('Migrated to Target'), findsOneWidget);
      final settled = t.count('GET /agents/a1/migration');
      await tester.pump(const Duration(seconds: 10));
      expect(t.count('GET /agents/a1/migration'), settled);
    });

    testWidgets('a settled migration is not polled', (tester) async {
      final (t, _) = await mount(tester, state: 'completed');
      final first = t.count('GET /agents/a1/migration');
      await tester.pump(const Duration(seconds: 10));
      expect(t.count('GET /agents/a1/migration'), first);
    });

    testWidgets('leaving the section stops the polling', (tester) async {
      final (t, _) = await mount(tester);
      await tester.pumpWidget(const SizedBox());
      final left = t.count('GET /agents/a1/migration');
      await tester.pump(const Duration(seconds: 10));
      expect(t.count('GET /agents/a1/migration'), left);
    });

    testWidgets('rooms:joined and connected refetch the migration', (
      tester,
    ) async {
      final (t, w) = await mount(tester, state: 'completed');
      final stream = (w.client as _EventClient).stream;
      final first = t.count('GET /agents/a1/migration');
      stream.add(const RaftEvent('rooms:joined', null));
      await tester.pumpAndSettle();
      expect(t.count('GET /agents/a1/migration'), first + 1);
      stream.add(const RaftEvent('connected', null));
      await tester.pumpAndSettle();
      expect(t.count('GET /agents/a1/migration'), first + 2);
      stream.add(
        const RaftEvent('agent:migration-updated', {'agentId': 'other'}),
      );
      await tester.pumpAndSettle();
      expect(t.count('GET /agents/a1/migration'), first + 2);
    });
  });

  group('stale agent rows after a migration (Web loadAgents)', () {
    testWidgets(
      'watching a migration complete re-reads the entity directory agents',
      (tester) async {
        final t = _MigrationTransport();
        final w = (await tester.runAsync(() => _fixture(t)))!;
        addTearDown(() async {
          w.dispose();
          await (w.client as _EventClient).stream.close();
        });
        await tester.runAsync(w.entityDirectory.preload);
        expect(w.entityDirectory.agent('a1')?['machineId'], 'c1');
        await tester.pumpWidget(_host(w));
        await tester.pumpAndSettle();
        expect(find.text('Migrating to Target'), findsOneWidget);
        final reads = t.count('GET /agents');
        t.state = 'completed';
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        expect(find.text('Migrated to Target'), findsOneWidget);
        await tester.pump(const Duration(seconds: 1));
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        expect(t.count('GET /agents'), greaterThan(reads));
        expect(w.entityDirectory.agent('a1')?['machineId'], 'c2');
      },
    );

    testWidgets('a migration that was never seen active does not re-read', (
      tester,
    ) async {
      final t = _MigrationTransport(), reads = <int>[];
      t.state = 'completed';
      final w = (await tester.runAsync(() => _fixture(t)))!;
      addTearDown(() async {
        w.dispose();
        await (w.client as _EventClient).stream.close();
      });
      await tester.runAsync(w.entityDirectory.preload);
      reads.add(t.count('GET /agents'));
      await tester.pumpWidget(_host(w, completed: true));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
      expect(t.count('GET /agents'), reads.single);
    });
  });

  group('Pro plan gating (Web billing.ts)', () {
    final after = DateTime.utc(2026, 10, 16);

    testWidgets('a free plan opening Move sees the upgrade dialog', (
      tester,
    ) async {
      final (t, w) = await mount(
        tester,
        state: 'completed',
        plan: 'free',
        now: () => after,
      );
      expect(t.count('GET /billing/subscription'), 1);
      await tester.tap(_migrateButton);
      await tester.pumpAndSettle();
      expect(find.text('UPGRADE TO PRO TO MIGRATE AGENTS'), findsOneWidget);
      expect(
        find.textContaining(
          'After upgrading, you can migrate an agent and its workspace',
        ),
        findsOneWidget,
      );
      expect(find.byType(RaftFormDialog), findsNothing);
      // "Upgrade" opens Plan & Billing settings.
      await tester.tap(
        find.widgetWithText(RaftSettingsRecipeButton, 'Upgrade'),
      );
      await tester.pumpAndSettle();
      expect(w.section, 'billing');
    });

    testWidgets('the upgrade dialog uses the Web zh-cn copy', (tester) async {
      await mount(
        tester,
        state: 'completed',
        plan: 'free',
        now: () => after,
        locale: const Locale('zh'),
      );
      await tester.tap(find.widgetWithText(RaftButton, '迁移'));
      await tester.pumpAndSettle();
      expect(find.text('升级至 PRO 以迁移 AGENT'), findsOneWidget);
      expect(find.textContaining('升级后，可以把 Agent 连同工作区'), findsOneWidget);
      expect(
        find.widgetWithText(RaftSettingsRecipeButton, '升级'),
        findsOneWidget,
      );
    });

    testWidgets('closing the upgrade dialog stays on the section', (
      tester,
    ) async {
      final (_, w) = await mount(
        tester,
        state: 'completed',
        plan: 'free',
        now: () => after,
      );
      await tester.tap(_migrateButton);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(RaftSettingsRecipeButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('UPGRADE TO PRO TO MIGRATE AGENTS'), findsNothing);
      expect(find.byType(AgentMigrationSection), findsOneWidget);
      expect(w.section, isNot('billing'));
    });

    testWidgets('pro, partner, founder and an active trial open the form', (
      tester,
    ) async {
      for (final (plan, clock) in [
        ('pro', after),
        ('founder', after),
        ('partner', after),
        ('free', DateTime.utc(2026, 5, 1)),
      ]) {
        await tester.pumpWidget(const SizedBox());
        final (_, _) = await mount(
          tester,
          state: 'completed',
          plan: plan,
          now: () => clock,
        );
        await tester.tap(_migrateButton);
        await tester.pumpAndSettle();
        expect(find.byType(RaftFormDialog), findsOneWidget, reason: plan);
        expect(find.text('UPGRADE TO PRO TO MIGRATE AGENTS'), findsNothing);
      }
    });

    testWidgets('an unavailable billing read never invents a denial', (
      tester,
    ) async {
      await mount(tester, state: 'completed', plan: null, now: () => after);
      await tester.tap(_migrateButton);
      await tester.pumpAndSettle();
      expect(find.byType(RaftFormDialog), findsOneWidget);
    });

    testWidgets(
      'MIGRATION_PRO_PLAN_REQUIRED on submit swaps the form for the upgrade dialog and reloads billing',
      (tester) async {
        // The billing projection still says Pro; the server is the authority.
        final (t, _) = await mount(tester, state: 'completed', plan: 'pro');
        t.startDenied = true;
        final billingReads = t.count('GET /billing/subscription');
        await tester.tap(_migrateButton);
        await tester.pumpAndSettle();
        await tester.tap(_dialogMigrate);
        await tester.pumpAndSettle();
        expect(t.count('POST /agents/a1/migrate'), 1);
        expect(find.byType(RaftFormDialog), findsNothing);
        expect(find.text('UPGRADE TO PRO TO MIGRATE AGENTS'), findsOneWidget);
        expect(find.textContaining('requires the Pro plan'), findsNothing);
        expect(t.count('GET /billing/subscription'), billingReads + 1);
      },
    );
  });

  group('progress panel (Web MigrationProgressPanel)', () {
    testWidgets('an active run shows the five steps and the state notice', (
      tester,
    ) async {
      await mount(tester);
      expect(find.text('Migrating to Target'), findsOneWidget);
      for (final step in [
        'Stop agent',
        'Pack workspace',
        'Transfer files',
        'Start on new computer',
        'Migration complete',
      ]) {
        expect(find.text(step), findsOneWidget, reason: step);
      }
      expect(find.text('Transferring workspace to Target.'), findsOneWidget);
      expect(find.textContaining('Migration status:'), findsNothing);
      // The support reference only appears when something needs attention.
      expect(find.text('Migration ID'), findsNothing);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('packing shows the file count and size', (tester) async {
      await mount(
        tester,
        state: 'provisioning',
        setup: (t) => t.extra = {
          'sourceQuiescedAt': '2026-10-16T11:00:00Z',
          'sourceBuildProgress': {'files': 1234, 'bytes': 3 * 1024 * 1024},
        },
      );
      expect(
        find.text(
          'Packing the workspace on Source: 1,234 files, 3.0 MB so far.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('packing shows the elapsed minutes without progress', (
      tester,
    ) async {
      await mount(
        tester,
        state: 'provisioning',
        now: () => DateTime.utc(2026, 10, 16, 11, 7),
        setup: (t) => t.extra = {'sourceQuiescedAt': '2026-10-16T11:00:00Z'},
      );
      expect(find.textContaining('(7 minutes so far)'), findsOneWidget);
    });

    testWidgets(
      'a failure before the flip says the agent is still on the source',
      (tester) async {
        await mount(
          tester,
          state: 'failed',
          setup: (t) => t.extra = {
            'failureReason': 'MIGRATION_LEASE_EXPIRED',
            'agentId': 'a1',
          },
        );
        expect(
          find.text('Migration to Target needs attention'),
          findsOneWidget,
        );
        expect(find.text('Migration failed'), findsOneWidget);
        expect(
          find.text('The agent is still on Source and works as usual.'),
          findsOneWidget,
        );
        expect(
          find.text('Something went wrong during the transfer. Try again.'),
          findsOneWidget,
        );
        // Technical details are collapsed until opened.
        expect(find.textContaining('MIGRATION_LEASE_EXPIRED'), findsNothing);
        await tester.tap(find.text('Technical details'));
        await tester.pump();
        expect(find.textContaining('MIGRATION_LEASE_EXPIRED'), findsOneWidget);
        // The reference shows on a failure, with a copy action.
        expect(find.text('Migration ID'), findsOneWidget);
        expect(find.text('fixture-ref'), findsOneWidget);
        expect(find.text('Try migration again'), findsOneWidget);
        expect(find.text('Cancel'), findsNothing);
      },
    );

    testWidgets('a failure after the flip says the agent is on the target', (
      tester,
    ) async {
      await mount(
        tester,
        state: 'failed',
        setup: (t) => t.extra = {
          'flippedAt': '2026-10-16T11:30:00Z',
          'failureReason': 'MIGRATION_LEASE_EXPIRED',
        },
      );
      expect(
        find.textContaining(
          'The agent moved to Target but could not start there.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('still on Source'), findsNothing);
    });

    testWidgets('an agent that did not start after the move is shown failed', (
      tester,
    ) async {
      await mount(
        tester,
        state: 'starting',
        setup: (t) => t.extra = {'failureReason': 'auto_start_failed'},
      );
      expect(find.text('Agent did not start'), findsOneWidget);
      expect(
        find.text(
          'The workspace moved to Target, but the agent did not start automatically.',
        ),
        findsOneWidget,
      );
      expect(find.text('Migration ID'), findsOneWidget);
    });

    testWidgets('a requested cancellation reads as canceling, not attention', (
      tester,
    ) async {
      await mount(tester, state: 'cancel_requested_post_flip');
      expect(find.text('Canceling migration to Target'), findsOneWidget);
      expect(
        find.text('Stopping the agent on the new computer'),
        findsOneWidget,
      );
      expect(find.text('Migration ID'), findsNothing);
      expect(find.text('Cancel'), findsNothing);
      expect(find.text('Migrate'), findsNothing);
    });

    testWidgets('cancellation attention shows the title, code and reference', (
      tester,
    ) async {
      await mount(
        tester,
        state: 'cancel_requested_pre_flip',
        setup: (t) => t.extra = {
          'cancelNeedsAttention': true,
          'cancelErrorCode': 'CLEANUP_TIMEOUT',
        },
      );
      expect(find.text('Migration to Target needs attention'), findsOneWidget);
      expect(find.text("Cancellation couldn't finish"), findsOneWidget);
      await tester.tap(find.text('Technical details'));
      await tester.pump();
      expect(find.textContaining('CLEANUP_TIMEOUT'), findsOneWidget);
      expect(find.text('Migration ID'), findsOneWidget);
    });

    testWidgets('canceled and completed runs show no reference or cancel', (
      tester,
    ) async {
      await mount(tester, state: 'canceled_pre_flip');
      expect(find.text('Migration to Target canceled'), findsOneWidget);
      expect(find.text('Migration canceled'), findsNothing);
      expect(
        find.textContaining('canceled before the agent switched computers'),
        findsOneWidget,
      );
      expect(find.text('Migration ID'), findsNothing);
      expect(find.text('Migrate'), findsOneWidget);
    });

    testWidgets('the panel uses the Web zh-cn copy', (tester) async {
      await mount(tester, locale: const Locale('zh'));
      expect(find.text('正在迁移到 Target'), findsOneWidget);
      expect(find.text('停止 Agent'), findsOneWidget);
      expect(find.text('迁移完成'), findsOneWidget);
      expect(find.text('正在将工作区传输到 Target。'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
    });

    testWidgets('the steps stack when the row does not fit', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await mount(tester);
      final first = tester.getTopLeft(find.text('Stop agent'));
      final second = tester.getTopLeft(find.text('Pack workspace'));
      expect(second.dy, greaterThan(first.dy));
      expect(second.dx, first.dx);
    });
  });

  group('cancel (Web AgentMigrationCancelDialog)', () {
    Future<void> openCancel(WidgetTester tester) async {
      await tester.tap(find.widgetWithText(RaftButton, 'Cancel'));
      await tester.pumpAndSettle();
    }

    testWidgets('the dialog explains what cancelling does', (tester) async {
      await mount(tester);
      await openCancel(tester);
      expect(find.text('CANCEL MIGRATION?'), findsOneWidget);
      expect(find.text('Canceling is safe'), findsOneWidget);
      expect(
        find.textContaining(
          'Raft will stop the migration from Source to Target and clean up on both computers.',
        ),
        findsOneWidget,
      );
      expect(find.text('fixture-ref'), findsOneWidget);
      expect(
        find.text(
          'Canceling finishes only after both computers confirm. Keep both computers online until then.',
        ),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(RaftSettingsRecipeButton, 'Stop'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(RaftSettingsRecipeButton, 'Continue'),
        findsOneWidget,
      );
    });

    testWidgets('Continue keeps the migration and sends nothing', (
      tester,
    ) async {
      final (t, _) = await mount(tester);
      await openCancel(tester);
      await tester.tap(
        find.widgetWithText(RaftSettingsRecipeButton, 'Continue'),
      );
      await tester.pumpAndSettle();
      expect(find.text('CANCEL MIGRATION?'), findsNothing);
      expect(t.requests, isEmpty);
    });

    testWidgets('a stale revision re-reads the status and retries', (
      tester,
    ) async {
      final (t, _) = await mount(tester, setup: (t) => t.staleCancels = 2);
      await openCancel(tester);
      await tester.tap(find.widgetWithText(RaftSettingsRecipeButton, 'Stop'));
      await tester.pumpAndSettle();
      // The revision the dialog opened with, then each re-read revision.
      expect(t.requests, [
        {'migrationRef': 'fixture-ref', 'expectedRevision': 2},
        {'migrationRef': 'fixture-ref', 'expectedRevision': 3},
        {'migrationRef': 'fixture-ref', 'expectedRevision': 4},
      ]);
      expect(find.text('CANCEL MIGRATION?'), findsNothing);
      expect(find.text('Canceling migration to Target'), findsOneWidget);
    });

    testWidgets('three stale attempts stop and keep the dialog open', (
      tester,
    ) async {
      final (t, _) = await mount(tester);
      await openCancel(tester);
      await tester.tap(find.widgetWithText(RaftSettingsRecipeButton, 'Stop'));
      await tester.pumpAndSettle();
      expect(t.requests, hasLength(3));
      expect(find.text('CANCEL MIGRATION?'), findsOneWidget);
      expect(
        find.text(
          'The migration moved on before your request went through. Check the latest status and try again. (MIGRATION_REVISION_STALE)',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('refresh before retrying'), findsNothing);
    });

    testWidgets('a stale answer for another migration is not retried', (
      tester,
    ) async {
      final (t, _) = await mount(tester, setup: (t) => t.staleCancels = 2);
      await openCancel(tester);
      t.extra = {'migrationRef': 'other-ref'};
      await tester.tap(find.widgetWithText(RaftSettingsRecipeButton, 'Stop'));
      await tester.pumpAndSettle();
      expect(t.requests, hasLength(1));
      expect(find.text('CANCEL MIGRATION?'), findsOneWidget);
    });
  });

  group('start errors (Web AgentMigrationDialog)', () {
    Future<void> submitMove(WidgetTester tester) async {
      await tester.tap(_migrateButton);
      await tester.pumpAndSettle();
      await tester.tap(_dialogMigrate);
      await tester.pumpAndSettle();
    }

    testWidgets('lists every other computer, offline ones included', (
      tester,
    ) async {
      await mount(tester, state: 'completed');
      await tester.tap(_migrateButton);
      await tester.pumpAndSettle();
      // The first choice is selected; open the menu to see all of them.
      await tester.tap(find.byKey(const ValueKey('migration-target-computer')));
      await tester.pumpAndSettle();
      // Completed moved the agent to c2: the source is Target now.
      expect(find.text('Source'), findsWidgets);
      expect(find.text('Sleepy'), findsWidgets);
      expect(find.text('Legacy'), findsNothing);
    });

    testWidgets('an offline target is submitted and the server answers', (
      tester,
    ) async {
      final (t, _) = await mount(
        tester,
        state: 'completed',
        setup: (t) => t.startError = {
          'error': 'offline',
          'code': 'TARGET_COMPUTER_OFFLINE',
        },
      );
      await submitMove(tester);
      expect(t.posted, ['c1']);
      expect(
        find.text(
          'The target computer is offline. Start Raft Computer on it and try again.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a capability failure names the computer and offers recovery', (
      tester,
    ) async {
      await mount(
        tester,
        state: 'completed',
        setup: (t) => t.startError = {
          'error': 'capability',
          'code': 'COMPUTER_CAPABILITY_INSUFFICIENT',
          'details': {
            'failures': [
              {
                'side': 'target',
                'reason': 'runtime_missing',
                'runtime': 'codex',
              },
            ],
          },
        },
      );
      await submitMove(tester);
      expect(
        find.text(
          'Fix these computer requirements before starting the migration:',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Source does not support Codex CLI.'),
        findsOneWidget,
      );
      expect(find.text('Open computer settings'), findsOneWidget);
      // The submit action now reads Try again.
      expect(find.widgetWithText(RaftButton, 'Try again'), findsOneWidget);
      expect(_dialogMigrate, findsNothing);
    });

    testWidgets('a resumable capability gap names the computer to update', (
      tester,
    ) async {
      await mount(
        tester,
        state: 'completed',
        setup: (t) => t.startError = {
          'error': 'resumable',
          'code': 'MIGRATION_RESUMABLE_CAPABILITY_REQUIRED',
          'details': {'side': 'both', 'reason': 'capability_missing'},
        },
      );
      await submitMove(tester);
      expect(
        find.textContaining('Target and Source need a Raft Computer update'),
        findsOneWidget,
      );
      expect(find.text('Open Computers'), findsOneWidget);
    });

    testWidgets('an error without details has no recovery', (tester) async {
      await mount(
        tester,
        state: 'completed',
        setup: (t) => t.startError = {'error': 'x', 'code': 'AGENT_NOT_FOUND'},
      );
      await submitMove(tester);
      expect(
        find.text('This agent is no longer available. Refresh and try again.'),
        findsOneWidget,
      );
      expect(find.text('Open Computers'), findsNothing);
      expect(_dialogMigrate, findsOneWidget);
    });
  });

  group('availability (Web AgentMigrationSection)', () {
    testWidgets('Move is hidden only while a migration is active', (
      tester,
    ) async {
      await mount(tester);
      expect(find.text('Migrate'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await mount(tester, state: 'failed');
      expect(find.text('Try migration again'), findsOneWidget);
    });

    testWidgets('a status read failure is a banner and keeps Move', (
      tester,
    ) async {
      await mount(tester, setup: (t) => t.statusFails = true);
      expect(find.text("Can't load migration status"), findsOneWidget);
      expect(
        find.text(
          'Migration status could not be loaded. Refresh and try again.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Boom internal detail'), findsNothing);
      expect(find.text('Migrate'), findsOneWidget);
    });
  });
}
