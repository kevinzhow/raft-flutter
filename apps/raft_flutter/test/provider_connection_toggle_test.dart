// Provider connections: the enable / disable switch on each row (Web
// ManagedConnectionRow `handleToggle`: PATCH {enabled}, then the catalog is
// read again; a failed switch says "The provider connection could not be
// updated.").
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/provider_views.dart';
import 'package:raft_ui/raft_ui.dart';

class _Adapter implements HttpClientAdapter {
  final calls = <RequestOptions>[];
  bool enabled = true;
  bool failPatch = false;
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) async {
    calls.add(o);
    var status = 200;
    dynamic data;
    switch ('${o.method} ${o.path}') {
      case 'POST /auth/login':
        data = {
          'accessToken': 'fixture-only',
          'refreshToken': 'fixture-only',
          'user': {'id': 'alice'},
        };
      case 'POST /feature-flags/evaluate':
        data = {
          'evaluations': [
            {'key': 'provider_connections_v0', 'enabled': true},
          ],
        };
      case 'GET /provider-connections':
        data = {
          'connections': [
            {
              'id': 'p1',
              'name': 'Team gateway',
              'providerId': 'openai',
              'status': 'ready',
              'enabled': enabled,
              'assignedAgentCount': 0,
            },
          ],
          'providerOptions': [
            {'id': 'openai', 'label': 'OpenAI', 'providerKind': 'preset'},
          ],
        };
      case 'PATCH /provider-connections/p1':
        if (failPatch) {
          status = 500;
          data = {'error': 'internal detail'};
        } else {
          enabled = (o.data as Map)['enabled'] as bool;
          data = {'id': 'p1', 'enabled': enabled};
        }
      default:
        status = 404;
        data = {'error': 'Unexpected endpoint'};
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

void main() {
  late WorkspaceController w;
  late _Adapter a;

  Future<void> start(WidgetTester t) async {
    a = _Adapter();
    w = (await t.runAsync(() async {
      final client = RaftClient(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
        transport: Dio()..httpClientAdapter = a,
      );
      await client.login('fixture', 'fixture');
      client.selectServer('s1');
      final workspace = WorkspaceController(client)
        ..server = RaftRecord({'id': 's1', 'name': 'Test', 'role': 'owner'});
      workspace.servers = [workspace.server!];
      return workspace;
    }))!;
    addTearDown(w.dispose);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: Scaffold(body: ProviderConnectionsView(controller: w)),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('disabling and enabling a connection patches enabled and '
      'refreshes the row', (t) async {
    await start(t);
    expect(find.textContaining('Enabled'), findsOneWidget);
    await t.ensureVisible(find.text('Disable connection'));
    await t.tap(find.text('Disable connection'));
    await t.pumpAndSettle();
    var patch = a.calls.where((c) => c.method == 'PATCH').single;
    expect(patch.path, '/provider-connections/p1');
    expect(patch.data, {'enabled': false});
    expect(find.text('Enable connection'), findsOneWidget);
    expect(find.text('Disable connection'), findsNothing);
    expect(find.textContaining('Disabled'), findsOneWidget);

    await t.tap(find.text('Enable connection'));
    await t.pumpAndSettle();
    patch = a.calls.where((c) => c.method == 'PATCH').last;
    expect(patch.data, {'enabled': true});
    expect(find.text('Disable connection'), findsOneWidget);
  });

  testWidgets('a failed switch shows the Web message, never the server text', (
    t,
  ) async {
    await start(t);
    a.failPatch = true;
    await t.ensureVisible(find.text('Disable connection'));
    await t.tap(find.text('Disable connection'));
    await t.pumpAndSettle();
    expect(
      find.text('The provider connection could not be updated.'),
      findsOneWidget,
    );
    expect(find.textContaining('internal detail'), findsNothing);
    expect(find.text('Disable connection'), findsOneWidget);
  });
}
