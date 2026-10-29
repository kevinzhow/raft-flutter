import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/connected_app_editor.dart';
import 'package:raft_flutter/features/integrations_views.dart';
import 'package:raft_ui/raft_ui.dart';

class _Adapter implements HttpClientAdapter {
  final calls = <RequestOptions>[];
  final statuses = <String, int>{};
  final Map<String, FutureOr<dynamic> Function(RequestOptions)> routes = {};
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) async {
    calls.add(o);
    final route = routes['${o.method} ${o.path}'];
    final data = route == null
        ? {'error': 'Unexpected endpoint'}
        : await route(o);
    return ResponseBody.fromString(
      jsonEncode(data),
      statuses['${o.method} ${o.path}'] ?? (route == null ? 404 : 200),
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<(WorkspaceController, _Adapter)> _fixture() async {
  final a = _Adapter();
  a.routes['POST /auth/login'] = (_) => {
    'accessToken': 'fixture-only',
    'refreshToken': 'fixture-only',
    'user': {'id': 'alice'},
  };
  final client = RaftClient(
    origin: 'https://example.invalid',
    sessionStore: MemorySessionStore(),
    transport: Dio()..httpClientAdapter = a,
  );
  await client.login('fixture', 'fixture');
  client.selectServer('s1');
  final w = WorkspaceController(client);
  w.server = RaftRecord({
    'id': 's1',
    'name': 'Test workspace',
    'role': 'owner',
  });
  w.servers = [w.server!];
  return (w, a);
}

Widget _host(Widget child) => MaterialApp(
  theme: raftTheme(),
  home: Scaffold(body: child),
);

const _app = {
  'id': 'app-1',
  'clientId': 'db9',
  'name': 'db9 Drive',
  'description': 'Cloud drive',
  'homepageUrl': 'https://db9.example',
  'returnUrl': 'https://db9.example/cb',
  'allowedScopes': ['openid', 'profile', 'identity'],
  'category': 'Other',
  'publishStatus': 'private',
  'appType': 'server_local',
};

void _routes(_Adapter a, List<Map<String, dynamic>> apps) {
  a.routes['GET /integrations/clients'] = (_) => apps;
  a.routes['GET /integrations/marketplace'] = (_) => <dynamic>[];
  a.routes['GET /integrations/overview'] = (_) => <dynamic>[];
  a.routes['GET /integrations/clients/app-1/share-link'] = (_) => {
    'error': 'none',
  };
  a.statuses['GET /integrations/clients/app-1/share-link'] = 404;
  a.routes['GET /integrations/clients/app-1/app-notifications'] = (_) => {
    'request_revision': 0,
    'current_groups': ['server'],
    'current_events': <String>[],
    'pending_revision': null,
    'webhook': null,
  };
}

Future<void> _mount(
  WidgetTester t,
  WorkspaceController w, {
  bool openMyApps = true,
}) async {
  await t.pumpWidget(
    _host(SingleChildScrollView(child: IntegrationsView(controller: w))),
  );
  await t.pumpAndSettle();
  if (openMyApps) {
    await t.tap(find.byKey(const ValueKey('connected-apps-tab-my-apps')));
    await t.pumpAndSettle();
  }
}

void main() {
  const editor = ValueKey('connected-app-editor');
  const submit = ValueKey('connected-app-editor-submit');

  group('declared scope and permission helpers', () {
    test('identity scopes stay fixed and the rest keep catalog order', () {
      expect(toggleDeclaredScope(const ['openid'], 'profile'), [
        'openid',
        'profile',
        'identity',
      ]);
      expect(
        toggleDeclaredScope(const [
          'openid',
          'profile',
          'identity',
        ], 'agent:notification:write'),
        ['openid', 'profile', 'identity', 'agent:notification:write'],
      );
      expect(
        toggleDeclaredScope(const [
          'openid',
          'profile',
          'identity',
          'email',
        ], 'email'),
        ['openid', 'profile', 'identity'],
      );
    });
    test('unchecking a group drops the events that need it', () {
      final next = toggleNotificationGroup(
        const ['server', 'channel'],
        const ['server.member_added', 'channel.archived'],
        'channel',
        false,
      );
      expect(next.groups, ['server']);
      expect(next.events, ['server.member_added']);
    });
  });

  testWidgets('Register app opens the sectioned editor and registers', (
    t,
  ) async {
    final (w, a) = (await t.runAsync(_fixture))!;
    addTearDown(w.dispose);
    final apps = <Map<String, dynamic>>[];
    _routes(a, apps);
    a.routes['POST /integrations/clients'] = (o) {
      final created = {
        ..._app,
        'name': o.data['name'],
        'allowedScopes': o.data['allowedScopes'],
      };
      apps.add(created);
      return {'client': created, 'clientSecret': 'shown-once-secret'};
    };
    await _mount(t, w, openMyApps: false);
    await t.tap(find.byKey(const ValueKey('connected-apps-register')));
    await t.pumpAndSettle();
    expect(find.byKey(editor), findsOneWidget);
    expect(find.text('New connected app'), findsOneWidget);
    for (final id in [
      'profile',
      'login',
      'permissions',
      'notifications',
      'distribution',
      'danger',
    ]) {
      expect(
        find.byKey(
          ValueKey('connected-app-editor-section-$id'),
          skipOffstage: false,
        ),
        findsOneWidget,
        reason: id,
      );
    }
    // Needs details until name, description and homepage are filled.
    expect(find.text('Needs details'), findsWidgets);
    // Webhook and lifecycle actions wait for the first save.
    expect(find.text('Save app first'), findsWidgets);
    await t.enterText(
      find.byKey(const ValueKey('connected-app-name')),
      'Brand new',
    );
    await t.tap(find.byKey(submit));
    await t.pumpAndSettle();
    final post = a.calls.singleWhere(
      (c) => c.method == 'POST' && c.path == '/integrations/clients',
    );
    expect(post.data['name'], 'Brand new');
    expect(post.data['allowedScopes'], ['openid', 'profile', 'identity']);
    expect(post.data['category'], 'Other');
    expect(post.data.containsKey('clientId'), isFalse);
    // The editor closed, My apps lists the app, the secret strip is shown.
    expect(find.byKey(editor), findsNothing);
    expect(find.text('Brand new'), findsOneWidget);
    expect(find.text('shown-once-secret'), findsOneWidget);
  });

  testWidgets(
    'a registration failure stays in the editor with the server error',
    (t) async {
      final (w, a) = (await t.runAsync(_fixture))!;
      addTearDown(w.dispose);
      _routes(a, []);
      a.routes['POST /integrations/clients'] = (_) => {
        'error': 'Client ID already exists',
      };
      a.statuses['POST /integrations/clients'] = 409;
      await _mount(t, w, openMyApps: false);
      await t.tap(find.byKey(const ValueKey('connected-apps-register')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('connected-app-name')), 'X');
      await t.tap(find.byKey(submit));
      await t.pumpAndSettle();
      expect(find.byKey(editor), findsOneWidget);
      expect(find.text('Client ID already exists'), findsOneWidget);
      expect(find.text('Register App'), findsWidgets);
    },
  );

  testWidgets('editing prefills the app, saves with PATCH and closes', (
    t,
  ) async {
    final (w, a) = (await t.runAsync(_fixture))!;
    addTearDown(w.dispose);
    _routes(a, []);
    a.routes['POST /integrations/clients'] = (_) => {
      'error': 'Client ID already exists',
    };
    a.statuses['POST /integrations/clients'] = 409;
    await _mount(t, w, openMyApps: false);
    await t.tap(find.byKey(const ValueKey('connected-apps-register')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('connected-app-name')), 'X');
    await t.tap(find.byKey(submit));
    await t.pumpAndSettle();
    expect(find.byKey(editor), findsOneWidget);
    expect(find.text('Client ID already exists'), findsOneWidget);
    expect(find.text('Register App'), findsWidgets);
  });

  testWidgets('editing prefills the app, saves with PATCH and closes', (
    t,
  ) async {
    final (w, a) = (await t.runAsync(_fixture))!;
    addTearDown(w.dispose);
    _routes(a, [Map<String, dynamic>.from(_app)]);
    a.routes['PATCH /integrations/clients/app-1'] = (o) => {..._app, ...o.data};
    await _mount(t, w);
    await t.tap(find.byKey(const ValueKey('connected-app-action-app-1')));
    await t.pumpAndSettle();
    expect(find.byKey(editor), findsOneWidget);
    expect(find.text('Edit app'), findsOneWidget);
    expect(find.text('db9 Drive'), findsWidgets);
    expect(find.text('OAuth ready'), findsWidgets);
    await t.enterText(
      find.byKey(const ValueKey('connected-app-name')),
      'db9 Drive v2',
    );
    await t.tap(find.byKey(submit));
    await t.pumpAndSettle();
    final patch = a.calls.singleWhere(
      (c) => c.method == 'PATCH' && c.path == '/integrations/clients/app-1',
    );
    expect(patch.data['name'], 'db9 Drive v2');
    expect(patch.data['returnUrl'], 'https://db9.example/cb');
    expect(find.byKey(editor), findsNothing);
  });

  testWidgets('the rail jumps to a section and marks it current', (t) async {
    final (w, a) = (await t.runAsync(_fixture))!;
    addTearDown(w.dispose);
    _routes(a, []);
    await _mount(t, w, openMyApps: false);
    await t.tap(find.byKey(const ValueKey('connected-apps-register')));
    await t.pumpAndSettle();
    await t.tap(find.text('Danger zone').first);
    await t.pumpAndSettle();
    expect(
      find.text(
        'Save the app before lifecycle or credential actions become available.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('danger zone: regenerate confirms, then shows the new secret', (
    t,
  ) async {
    final (w, a) = (await t.runAsync(_fixture))!;
    addTearDown(w.dispose);
    _routes(a, [Map<String, dynamic>.from(_app)]);
    a.routes['POST /integrations/clients/app-1/regenerate-secret'] = (_) => {
      'client': _app,
      'clientSecret': 'rotated-secret',
    };
    await _mount(t, w);
    await t.tap(find.byKey(const ValueKey('connected-app-action-app-1')));
    await t.pumpAndSettle();
    final button = find.byKey(
      const ValueKey('connected-app-regenerate-secret-button'),
    );
    await t.ensureVisible(button);
    await t.tap(button);
    await t.pumpAndSettle();
    expect(find.text('Regenerate Client Secret'), findsOneWidget);
    expect(find.textContaining('Regenerate client secret for'), findsOneWidget);
    expect(find.text('Regenerate client secret'), findsOneWidget);
    await t.tap(
      find.byKey(
        const ValueKey('connected-app-regenerate-secret-confirm-button'),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('rotated-secret'), findsOneWidget);
    expect(find.byKey(editor), findsOneWidget);
  });

  testWidgets('danger zone: delete confirms and removes the app', (t) async {
    final (w, a) = (await t.runAsync(_fixture))!;
    addTearDown(w.dispose);
    final apps = [Map<String, dynamic>.from(_app)];
    _routes(a, apps);
    a.routes['DELETE /integrations/clients/app-1'] = (_) {
      apps.clear();
      return {'ok': true};
    };
    await _mount(t, w);
    await t.tap(find.byKey(const ValueKey('connected-app-action-app-1')));
    await t.pumpAndSettle();
    final card = find.byKey(const ValueKey('connected-app-delete-card'));
    await t.ensureVisible(card);
    await t.tap(
      find.descendant(of: card, matching: find.text('Delete app')).last,
    );
    await t.pumpAndSettle();
    expect(find.text('Delete app'), findsWidgets);
    await t.tap(
      find.byKey(const ValueKey('connected-app-delete-confirm-button')),
    );
    await t.pumpAndSettle();
    expect(
      a.calls.where(
        (c) => c.method == 'DELETE' && c.path == '/integrations/clients/app-1',
      ),
      hasLength(1),
    );
    expect(find.byKey(editor), findsNothing);
    expect(find.text('No registered apps yet.'), findsOneWidget);
  });

  testWidgets('a revoked permission closes the editor and drops private rows', (
    t,
  ) async {
    final (w, a) = (await t.runAsync(_fixture))!;
    addTearDown(w.dispose);
    _routes(a, [Map<String, dynamic>.from(_app)]);
    a.routes['PATCH /integrations/clients/app-1'] = (_) => {
      'error': 'Permission changed',
    };
    a.statuses['PATCH /integrations/clients/app-1'] = 403;
    await _mount(t, w);
    await t.tap(find.byKey(const ValueKey('connected-app-action-app-1')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(submit));
    await t.pumpAndSettle();
    expect(find.byKey(editor), findsNothing);
    expect(find.text('db9 Drive'), findsNothing);
    expect(find.textContaining('Permission changed'), findsOneWidget);
  });

  testWidgets('webhook: enabling reveals the endpoint form and saves it', (
    t,
  ) async {
    final (w, a) = (await t.runAsync(_fixture))!;
    addTearDown(w.dispose);
    _routes(a, [Map<String, dynamic>.from(_app)]);
    a.routes['PUT /integrations/clients/app-1/app-notifications/webhook'] =
        (o) {
          expect(o.data, {'endpointUrl': 'https://hooks.example/raft'});
          a.routes['GET /integrations/clients/app-1/app-notifications'] = (_) =>
              {
                'request_revision': 1,
                'current_groups': ['server'],
                'current_events': <String>[],
                'pending_revision': null,
                'webhook': {
                  'endpoint_url': 'https://hooks.example/raft',
                  'config_revision': 1,
                  'enabled': true,
                },
              };
          return {'signing_secret': 'whsec_once'};
        };
    await _mount(t, w);
    await t.tap(find.byKey(const ValueKey('connected-app-action-app-1')));
    await t.pumpAndSettle();
    final toggle = find.byKey(const ValueKey('app-notifications-enabled'));
    await t.ensureVisible(toggle);
    await t.tap(toggle);
    await t.pumpAndSettle();
    expect(find.text('HTTPS endpoint'), findsOneWidget);
    expect(find.text('Webhook events'), findsOneWidget);
    await t.enterText(
      find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.hintText == 'https://example.com/raft/events',
      ),
      'https://hooks.example/raft',
    );
    await t.pump();
    await t.tap(find.text('Save endpoint'));
    await t.pumpAndSettle();
    expect(find.text('whsec_once'), findsOneWidget);
  });
}
