import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/agent_migration_view.dart';
import 'package:raft_ui/raft_ui.dart';

class _MigrationTransport implements HttpClientAdapter {
  _MigrationTransport({this.disabled = false});
  final bool disabled;
  int revision = 2;
  final requests = <Map<String, dynamic>>[];
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
      case 'GET /agents/a1':
        data = {
          'id': 'a1',
          'name': 'Fixture agent',
          'creatorType': 'user',
          'creatorId': 'alice',
          'runtime': 'codex',
          'machineId': 'c1',
        };
      case 'GET /servers/s1/machines':
        data = {
          'machines': [
            {'id': 'c1', 'name': 'Source'},
            {'id': 'c2', 'name': 'Target', 'status': 'online'},
          ],
        };
      case 'GET /agents/a1/migration':
        status = disabled ? 403 : 200;
        data = disabled
            ? {'error': 'Agent migration UI is not enabled on this server'}
            : {
                'migration': {
                  'migrationRef': 'fixture-ref',
                  'revision': revision,
                  'state': 'in_transit',
                  'sourceMachineId': 'c1',
                  'targetMachineId': 'c2',
                },
              };
      case 'POST /agents/a1/migration/cancel':
        requests.add(Map<String, dynamic>.from(o.data));
        revision = 3;
        status = 409;
        data = {
          'error': 'Migration changed; refresh before retrying',
          'code': 'MIGRATION_REVISION_STALE',
        };
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

Future<WorkspaceController> _fixture(_MigrationTransport transport) async {
  final client = RaftClient(
    origin: 'https://example.invalid',
    sessionStore: MemorySessionStore(),
    transport: Dio()..httpClientAdapter = transport,
  );
  await client.login('fixture', 'fixture');
  client.selectServer('s1');
  final w = WorkspaceController(client)
    ..server = RaftRecord({'id': 's1', 'role': 'owner'});
  return w;
}

void main() {
  testWidgets(
    'disabled migration API exposes no actionable transfer controls',
    (tester) async {
      final t = _MigrationTransport(disabled: true);
      final w = (await tester.runAsync(() => _fixture(t)))!;
      addTearDown(w.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: AgentMigrationView(controller: w, agentId: 'a1'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('not enabled'), findsOneWidget);
      expect(find.text('Move agent'), findsNothing);
      expect(find.text('Assign computer'), findsNothing);
    },
  );
  testWidgets(
    'cancel carries the displayed revision and a stale write stays open for review',
    (tester) async {
      final t = _MigrationTransport();
      final w = (await tester.runAsync(() => _fixture(t)))!;
      addTearDown(w.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: AgentMigrationView(controller: w, agentId: 'a1'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel migration'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(RaftButton, 'Cancel migration'));
      await tester.pumpAndSettle();
      expect(t.requests, [
        {'migrationRef': 'fixture-ref', 'expectedRevision': 2},
      ]);
      expect(find.byType(RaftFormDialog), findsOneWidget);
      expect(find.textContaining('Migration changed'), findsOneWidget);
      expect(find.text('Move agent'), findsNothing);
    },
  );
}
