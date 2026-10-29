// Web v1.21.23 removed the Agent access JWT card (Agent JWT is built in for
// every App; `PUT /integrations/clients/:id/agent-jwt` answers 410). The app
// must show no card and never call the endpoint.
import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/integrations_views.dart';
import 'package:raft_ui/raft_ui.dart';

class _Adapter implements HttpClientAdapter {
  final calls = <String>[];
  final Map<String, Object? Function()> routes = {};
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) async {
    final key = '${o.method} ${o.path}';
    calls.add(key);
    final route = routes[key];
    return ResponseBody.fromString(
      jsonEncode(route == null ? {'error': 'Unexpected endpoint'} : route()),
      route == null ? 404 : 200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _listing(String id, {String? installedAt}) => {
  'id': id,
  'clientId': 'client_$id',
  'name': 'App $id',
  'description': 'desc',
  'category': 'Developer Tools',
  'publisherName': 'Labs',
  'homepageUrl': 'https://example.com/$id',
  'returnUrl': 'https://example.com/$id/cb',
  'allowedScopes': ['openid', 'profile'],
  'installedAt': installedAt,
  'privateShared': false,
  'publishStatus': 'published',
  'appNotificationGroups': ['server'],
  'appNotificationEvents': <String>[],
};

void main() {
  testWidgets('installed app and marketplace details show no Agent JWT card', (
    t,
  ) async {
    final a = _Adapter();
    a.routes['POST /auth/login'] = () => {
      'accessToken': 'fixture-only',
      'refreshToken': 'fixture-only',
      'user': {'id': 'alice'},
    };
    final w = (await t.runAsync(() async {
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
    a.routes['GET /integrations/marketplace'] = () => [
      _listing('inst', installedAt: '2026-06-18T00:00:00.000Z'),
    ];
    a.routes['GET /integrations/clients'] = () => <dynamic>[];
    a.routes['GET /integrations/overview'] = () => <dynamic>[];
    a.routes['GET /integrations/marketplace/inst/install/app-notifications'] =
        () => {
          'requested_groups': <String>[],
          'approved_groups': <String>[],
          'subscribed_events': <String>[],
          'effective_groups': <String>[],
          'effective_events': <String>[],
          'app_review_pending': false,
          'approval_required': false,
        };
    t.view.physicalSize = const Size(1280, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: SingleChildScrollView(child: IntegrationsView(controller: w)),
        ),
      ),
    );
    await t.pumpAndSettle();

    // Marketplace detail of an installed app.
    await t.tap(find.byKey(const ValueKey('connected-app-inst')));
    await t.pumpAndSettle();
    expect(find.byType(RaftConnectedAppDetailSection), findsWidgets);
    expect(find.text('Agent access JWT'), findsNothing);
    expect(find.byKey(const ValueKey('agent-jwt-settings')), findsNothing);
    await t.tap(find.text('Cancel').last);
    await t.pumpAndSettle();

    // Installed tab detail.
    await t.tap(find.byKey(const ValueKey('connected-apps-tab-installed')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('connected-app-installed-inst')));
    await t.pumpAndSettle();
    expect(find.text('Agent access JWT'), findsNothing);
    expect(find.byKey(const ValueKey('agent-jwt-settings')), findsNothing);

    expect(a.calls.where((c) => c.contains('agent-jwt')), isEmpty);
  });
}
