import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/activity_rollout_flags.dart';
import 'package:raft_flutter/features/labs_view.dart';
import 'package:raft_ui/raft_ui.dart';

class _Adapter implements HttpClientAdapter {
  final calls = <RequestOptions>[];
  final routes = <String, FutureOr<dynamic> Function(RequestOptions)>{};
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) async {
    calls.add(o);
    final route = routes['${o.method} ${o.path}'];
    final data = route == null ? {'error': 'x'} : await route(o);
    return ResponseBody.fromString(
      jsonEncode(data),
      route == null ? 404 : 200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _readback(bool enrolled) => {
  'serverId': 's1',
  'accessEnabled': true,
  'version': 4,
  'canManageAccess': true,
  'canManageEnrollments': true,
  'labs': [
    {
      'labKey': 'grid_v0',
      'name': 'Workspace grid',
      'description': 'Editor groups.',
      'state': 'open',
      'enrolled': enrolled,
    },
  ],
};

void main() {
  // LabsSection.tsx:106-107: once the mutation is published the server's flags
  // are read again, so a lab that gates a feature takes effect this session.
  testWidgets('a lab toggle re-reads the session flags', (tester) async {
    final a = _Adapter();
    a.routes['POST /auth/login'] = (_) => {
      'accessToken': 'fixture-only',
      'refreshToken': 'fixture-only',
      'user': {'id': 'alice'},
    };
    a.routes['POST /feature-flags/evaluate'] = (_) => {'evaluations': []};
    a.routes['GET /servers/s1/labs'] = (_) => _readback(false);
    a.routes['PUT /servers/s1/labs/grid_v0'] = (_) => _readback(true);
    final w = (await tester.runAsync(() async {
      final client = RaftClient(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
        transport: Dio()..httpClientAdapter = a,
      );
      await client.login('fixture', 'fixture');
      client.selectServer('s1');
      final w = WorkspaceController(client);
      w.server = RaftRecord({'id': 's1', 'name': 'Test', 'role': 'owner'});
      w.servers = [w.server!];
      return w;
    }))!;
    addTearDown(w.dispose);
    ActivityRolloutFlags.of(w);
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(body: LabsView(controller: w)),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    int evaluations() =>
        a.calls.where((c) => c.path == '/feature-flags/evaluate').length;
    final before = evaluations();
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('server-lab-grid_v0')),
        matching: find.byType(RaftSwitch),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(evaluations(), before + 1);
  });
}
