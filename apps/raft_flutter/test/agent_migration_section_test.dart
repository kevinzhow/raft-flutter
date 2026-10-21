import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/agent_migration_section.dart';
import 'package:raft_ui/raft_ui.dart';

/// Answers the section's three reads and holds the start request until
/// [gate] completes, so the in-flight dialog can be inspected.
class _Transport implements HttpClientAdapter {
  Map<String, dynamic>? migration;
  Map<String, dynamic>? startError;
  Completer<void>? gate;
  final posted = <String>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) async {
    dynamic data;
    var status = 200;
    switch ('${o.method} ${o.path}') {
      case 'POST /auth/login':
        data = {
          'accessToken': 'fixture',
          'refreshToken': 'fixture',
          'user': {'id': 'alice'},
        };
      case 'GET /billing/subscription':
        data = {'plan': 'pro'};
      case 'GET /agents/a1/migration':
        data = {'migration': migration};
      case 'POST /agents/a1/migrate':
        posted.add('${o.data['targetComputer']}');
        await gate?.future;
        status = startError == null ? 200 : 409;
        data = startError ?? {'migration': {}};
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
  {'id': 'c3', 'name': 'Sleepy', 'status': 'offline', 'isComputer': true},
];

void main() {
  late _Transport transport;
  late List<Uri> opened;

  Future<void> mount(
    WidgetTester tester, {
    List<Map<String, dynamic>> machines = _machines,
  }) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final client = _EventClient(
      transport: Dio()..httpClientAdapter = transport,
    );
    client.selectServer('s1');
    final w = WorkspaceController(client)
      ..server = RaftRecord({'id': 's1', 'role': 'owner', 'slug': 'acme'});
    addTearDown(() async {
      w.dispose();
      await client.stream.close();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: Scaffold(
          body: SingleChildScrollView(
            child: AgentMigrationSection(
              controller: w,
              agent: const {'id': 'a1', 'runtime': 'codex', 'machineId': 'c1'},
              machines: machines,
              openExternal: (uri) async {
                opened.add(uri);
                return true;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    transport = _Transport();
    opened = [];
  });

  final migrate = find.widgetWithText(RaftButton, 'Migrate');
  final dialogMigrate = find.descendant(
    of: find.byType(RaftFormDialog),
    matching: find.widgetWithText(RaftButton, 'Migrate'),
  );
  final target = find.byKey(const ValueKey('migration-target-computer'));

  testWidgets('its own section: title, Pro badge, description, Migrate', (
    tester,
  ) async {
    await mount(tester);
    expect(find.byType(RaftPanelSection), findsOneWidget);
    expect(find.text('AGENT MIGRATION'), findsOneWidget);
    expect(find.text('Pro'), findsOneWidget);
    expect(
      find.text(
        'Move this agent and its workspace to another computer. The agent stops while it migrates, then starts again there.',
      ),
      findsOneWidget,
    );
    expect(migrate, findsOneWidget);
  });

  testWidgets('the description gives way to a running migration', (
    tester,
  ) async {
    transport.migration = {
      'migrationRef': 'ref-1',
      'revision': 2,
      'state': 'in_transit',
      'sourceMachineId': 'c1',
      'targetMachineId': 'c2',
    };
    await mount(tester);
    expect(
      find.textContaining('Move this agent and its workspace'),
      findsNothing,
    );
    expect(find.text('Migrating to Target'), findsOneWidget);
    expect(migrate, findsNothing);
    expect(find.widgetWithText(RaftButton, 'Cancel'), findsOneWidget);
  });

  testWidgets('the start dialog says what happens next', (tester) async {
    await mount(tester);
    await tester.tap(migrate);
    await tester.pumpAndSettle();
    expect(find.text('Move to another computer'), findsOneWidget);
    expect(
      find.text(
        'Your agent will stop while it migrates, then start again on the new computer.',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('Migrating moves the workspace files'),
      findsOneWidget,
    );
    expect(dialogMigrate, findsOneWidget);
    expect(find.text('Start migration'), findsNothing);
  });

  testWidgets('with no other computer the select is disabled', (tester) async {
    await mount(tester, machines: [_machines.first]);
    await tester.tap(migrate);
    await tester.pumpAndSettle();
    expect(find.text('No other computers available'), findsOneWidget);
    expect(tester.widget<RaftAgentCombobox>(target).enabled, isFalse);
    expect(tester.widget<RaftButton>(dialogMigrate).onPressed, isNull);
  });

  testWidgets('the destination picker filters and says "No matches"', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(migrate);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
    expect(find.text('Target'), findsWidgets);
    expect(find.text('Sleepy'), findsOneWidget);
    await tester.enterText(
      find.descendant(of: target, matching: find.byType(EditableText)),
      'sle',
    );
    await tester.pumpAndSettle();
    expect(find.text('Sleepy'), findsOneWidget);
    await tester.enterText(
      find.descendant(of: target, matching: find.byType(EditableText)),
      'zzz',
    );
    await tester.pumpAndSettle();
    expect(find.text('No matches'), findsOneWidget);
    expect(find.text('No results'), findsNothing);
  });

  testWidgets('submitting reads "Starting migration…" until it is accepted', (
    tester,
  ) async {
    transport.gate = Completer<void>();
    await mount(tester);
    await tester.tap(migrate);
    await tester.pumpAndSettle();
    await tester.tap(dialogMigrate);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Starting migration…'), findsOneWidget);
    expect(find.text('Migrate'), findsOneWidget, reason: 'the section action');
    transport.gate!.complete();
    await tester.pumpAndSettle();
    expect(transport.posted, ['c2']);
    expect(find.byType(RaftFormDialog), findsNothing);
  });

  testWidgets('Open computer settings keeps the dialog and the chosen target', (
    tester,
  ) async {
    transport.startError = {
      'error': 'capability',
      'code': 'COMPUTER_CAPABILITY_INSUFFICIENT',
      'details': {
        'failures': [
          {'side': 'target', 'reason': 'runtime_missing', 'runtime': 'codex'},
        ],
      },
    };
    await mount(tester);
    await tester.tap(migrate);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sleepy'));
    await tester.pumpAndSettle();
    await tester.tap(dialogMigrate);
    await tester.pumpAndSettle();
    expect(transport.posted, ['c3']);
    await tester.tap(find.text('Open computer settings'));
    await tester.pumpAndSettle();
    expect(opened.map((u) => u.toString()), [
      'https://example.invalid/s/acme/computer/c3',
    ]);
    expect(find.byType(RaftFormDialog), findsOneWidget);
    expect(find.text('Open computer settings'), findsOneWidget);
    expect(
      find.descendant(of: target, matching: find.text('Sleepy')),
      findsOneWidget,
    );
  });

  testWidgets('closing after only a target change does not ask to discard', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(migrate);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sleepy'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(RaftFormDialog), findsNothing);
    expect(find.textContaining('Discard'), findsNothing);
    expect(transport.posted, isEmpty);
  });

  testWidgets('the copy button is named with the migration ID', (tester) async {
    final semantics = tester.ensureSemantics();
    transport.migration = {
      'migrationRef': 'fixture-ref',
      'revision': 2,
      'state': 'failed',
      'sourceMachineId': 'c1',
      'targetMachineId': 'c2',
      'failureReason': 'MIGRATION_LEASE_EXPIRED',
    };
    await mount(tester);
    expect(
      find.bySemanticsLabel('Copy migration ID fixture-ref'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(RaftButton, 'Try migration again'),
      findsOneWidget,
    );
    semantics.dispose();
  });
}
