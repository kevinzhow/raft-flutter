import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/connected_app_editor.dart';
import 'package:raft_flutter/features/integrations_views.dart';
import 'package:raft_ui/raft_ui.dart';

Future<void> _openRegistration(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('connected-apps-register')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Create a Raft app'));
  await tester.pumpAndSettle();
}

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
  a.routes['GET /integrations/clients/app-1/share-links'] = (_) => {
    'links': <dynamic>[],
  };
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
    await _openRegistration(t);
    expect(find.byKey(editor), findsOneWidget);
    expect(find.text('Create Raft app'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(t.getCenter(find.byKey(submit)).dy, greaterThan(400));
    for (final id in ['profile', 'login', 'permissions', 'notifications']) {
      expect(
        find.byKey(
          ValueKey('connected-app-editor-section-$id'),
          skipOffstage: false,
        ),
        findsOneWidget,
        reason: id,
      );
    }
    for (final id in ['distribution', 'danger']) {
      expect(
        find.byKey(ValueKey('connected-app-editor-section-$id')),
        findsNothing,
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
      await _openRegistration(t);
      await t.enterText(find.byKey(const ValueKey('connected-app-name')), 'X');
      await t.tap(find.byKey(submit));
      await t.pumpAndSettle();
      expect(find.byKey(editor), findsOneWidget);
      expect(find.text('Client ID already exists'), findsOneWidget);
      expect(find.text('Add app'), findsOneWidget);
    },
  );

  testWidgets('editing prefills the app, saves with PATCH and closes', (
    t,
  ) async {
    final (w, a) = (await t.runAsync(_fixture))!;
    addTearDown(w.dispose);
    _routes(a, [Map<String, dynamic>.from(_app)]);
    a.routes['PATCH /integrations/clients/app-1'] = (o) => {..._app, ...o.data};
    await _mount(t, w);
    final intro = find.textContaining('Raft Apps this server builds.');
    final introStyle = t.widget<Text>(intro).style!;
    expect(introStyle.fontSize! * introStyle.height!, 18);
    final visibility = find.widgetWithText(RaftBadge, 'Private');
    expect(
      t.widget<RaftBadge>(visibility).appearance,
      RaftBadgeRecipeAppearance.soft,
    );
    await t.tap(find.byKey(const ValueKey('connected-app-action-app-1')));
    await t.pumpAndSettle();
    expect(find.byKey(editor), findsOneWidget);
    expect(find.text('Edit db9 Drive'), findsOneWidget);
    expect(find.text('db9 Drive'), findsWidgets);
    expect(find.text('OAuth ready'), findsWidgets);
    final logo = find.descendant(
      of: find.byKey(editor),
      matching: find.byType(RaftAppLogo),
    );
    final upload = find.text('Upload');
    expect(t.getCenter(upload).dy, closeTo(t.getCenter(logo).dy, 2));
    expect(t.getTopLeft(upload).dx, greaterThan(t.getTopRight(logo).dx));
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(find.byKey(editor), findsNothing);
    expect(a.calls.where((call) => call.method == 'PATCH'), isEmpty);
    await t.tap(find.byKey(const ValueKey('connected-app-action-app-1')));
    await t.pumpAndSettle();
    await t.enterText(
      find.byKey(const ValueKey('connected-app-name')),
      'db9 Drive v2',
    );
    final clientId = find.widgetWithText(RaftRecipeInput, 'db9');
    expect(t.widget<RaftRecipeInput>(clientId).enabled, isTrue);
    await t.enterText(clientId, ' db9-v2 ');
    await t.tap(find.byKey(submit));
    await t.pumpAndSettle();
    final patch = a.calls.singleWhere(
      (c) => c.method == 'PATCH' && c.path == '/integrations/clients/app-1',
    );
    expect(patch.data['name'], 'db9 Drive v2');
    expect(patch.data['clientId'], 'db9-v2');
    expect(patch.data['returnUrl'], 'https://db9.example/cb');
    expect(find.byKey(editor), findsNothing);
  });

  testWidgets('private share links: list, create for a target slug, revoke', (
    t,
  ) async {
    // Server v1.24.0 / Web ConnectedAppShareLinks: GET/POST
    // /integrations/clients/:id/share-links, DELETE .../share-links/:linkId;
    // the old single /share-link routes are gone.
    Future<void> tapVisible(Finder target) async {
      await t.ensureVisible(target);
      await t.pumpAndSettle();
      await t.tap(target);
      await t.pumpAndSettle();
    }

    t.view
      ..physicalSize = const Size(1280, 1600)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final (w, a) = (await t.runAsync(_fixture))!;
    addTearDown(w.dispose);
    _routes(a, [Map<String, dynamic>.from(_app)]);
    a.routes['GET /integrations/clients/app-1/share-links'] = (_) => {
      'links': [
        {
          'id': 'link-acme',
          'clientId': 'app-1',
          'targetServerSlug': 'acme',
          'expiresAt': null,
          'revokedAt': null,
          'createdAt': '2026-11-01T00:00:00.000Z',
        },
      ],
    };
    a.routes['POST /integrations/clients/app-1/share-links'] = (_) => {
      'link': {
        'id': 'link-beta',
        'clientId': 'app-1',
        'targetServerSlug': 'beta',
        'expiresAt': null,
        'revokedAt': null,
        'createdAt': '2026-11-13T00:00:00.000Z',
      },
      'token': 'invite-token',
      'client': _app,
    };
    a.routes['DELETE /integrations/clients/app-1/share-links/link-acme'] = (
      _,
    ) => {'ok': true};
    await _mount(t, w);
    await t.tap(find.byKey(const ValueKey('connected-app-action-app-1')));
    await t.pumpAndSettle();
    final input = find.byKey(
      const ValueKey('connected-app-share-target-input'),
    );
    await t.ensureVisible(input);
    await t.pumpAndSettle();
    expect(find.text('Target server'), findsOneWidget);
    expect(find.text('acme'), findsOneWidget);
    expect(find.text('Expires never'), findsOneWidget);

    await t.enterText(
      find.descendant(of: input, matching: find.byType(EditableText)),
      'Not A Slug!',
    );
    await t.pump();
    await tapVisible(
      find.byKey(const ValueKey('connected-app-share-create-button')),
    );
    expect(
      find.text(
        'Enter a server slug: lowercase letters, digits and hyphens, starting with a letter.',
      ),
      findsOneWidget,
    );
    bool sharePost(RequestOptions c) =>
        c.method == 'POST' && c.path.contains('/share-link');
    expect(a.calls.where(sharePost), isEmpty);

    await t.enterText(
      find.descendant(of: input, matching: find.byType(EditableText)),
      ' Beta ',
    );
    await t.pump();
    await tapVisible(
      find.byKey(const ValueKey('connected-app-share-create-button')),
    );
    final post = a.calls.singleWhere(sharePost);
    expect(post.path, '/integrations/clients/app-1/share-links');
    expect(post.data, {'targetServerSlug': 'beta'});
    expect(
      find.text("Link for beta. Copy it now: it's shown only once."),
      findsOneWidget,
    );
    expect(
      find.text('https://example.invalid/integration-invites/invite-token'),
      findsOneWidget,
    );
    expect(find.text('beta'), findsOneWidget);

    t.view.physicalSize = const Size(390, 844);
    await t.pumpAndSettle();
    final created = find.byKey(const ValueKey('connected-app-share-created'));
    final shareUrl = find.descendant(
      of: created,
      matching: find.byType(RaftAppEditorReadonlyInput),
    );
    final copyButton = find.descendant(
      of: created,
      matching: find.text('Copy'),
    );
    expect(t.getCenter(shareUrl).dy, t.getCenter(copyButton).dy);
    t.view.physicalSize = const Size(1280, 1600);
    await t.pumpAndSettle();

    await tapVisible(
      find.descendant(
        of: find.byKey(
          const ValueKey('connected-app-share-link-row-link-acme'),
        ),
        matching: find.text('Revoke'),
      ),
    );
    expect(
      a.calls.where((c) => c.method == 'DELETE').single.path,
      '/integrations/clients/app-1/share-links/link-acme',
    );
    expect(find.text('acme'), findsNothing);
    expect(find.text('beta'), findsOneWidget);
    expect(a.calls.where((c) => c.path.endsWith('/share-link')), isEmpty);
  });

  testWidgets('the rail jumps to a section and marks it current', (t) async {
    final (w, a) = (await t.runAsync(_fixture))!;
    addTearDown(w.dispose);
    _routes(a, []);
    await _mount(t, w, openMyApps: false);
    await _openRegistration(t);
    expect(t.getSize(find.byType(RaftDialogHeader)).height, closeTo(44, 1));
    final webhookItem = find.widgetWithText(RaftSettingsSidebarItem, 'Webhook');
    Focus.of(t.element(webhookItem)).requestFocus();
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pumpAndSettle();
    expect(t.widget<RaftSettingsSidebarItem>(webhookItem).active, isTrue);
    expect(
      find
          .byKey(const ValueKey('connected-app-editor-section-notifications'))
          .hitTestable(),
      findsOneWidget,
    );
  }, variant: const TargetPlatformVariant({TargetPlatform.linux}));

  testWidgets('the phone editor opens with its close and Save in the head', (
    t,
  ) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(390, 844);
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final (w, a) = (await t.runAsync(_fixture))!;
    addTearDown(w.dispose);
    _routes(a, [Map<String, dynamic>.from(_app)]);
    await _mount(t, w, openMyApps: false);
    await t.tap(find.byKey(const ValueKey('connected-apps-scope-select')));
    await t.pumpAndSettle();
    await t.tap(find.text('Developer'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('connected-app-action-app-1')));
    await t.pumpAndSettle();

    final close = find.bySemanticsLabel('Close app form');
    expect(close, findsOneWidget);
    expect(find.byKey(const ValueKey('raft-sheet-handle')), findsNothing);
    expect(
      t.getCenter(close).dy,
      closeTo(t.getCenter(find.byKey(submit)).dy, 1),
    );
    await t.tap(close);
    await t.pumpAndSettle();
    expect(find.byKey(editor), findsNothing);
    expect(a.calls.where((call) => call.method == 'PATCH'), isEmpty);
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
    final secretTitle = find.text('Client secret');
    final regenerate = find.descendant(
      of: button,
      matching: find.byType(RaftButton),
    );
    final section = find.byKey(
      const ValueKey('connected-app-editor-section-danger'),
    );
    final rowInset = t.getTopLeft(secretTitle).dx - t.getTopLeft(section).dx;
    final warningButton =
        t.widget<RaftButton>(regenerate).uiVariant == RaftButtonVariant.warning;
    await t.tap(button);
    await t.pumpAndSettle();
    expect(find.text('Regenerate client secret'), findsOneWidget);
    expect(find.textContaining('Regenerate client secret for'), findsOneWidget);
    expect(find.text('Regenerate'), findsOneWidget);
    await t.tap(
      find.byKey(
        const ValueKey('connected-app-regenerate-secret-confirm-button'),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('rotated-secret'), findsOneWidget);
    expect(find.byKey(editor), findsOneWidget);
    expect((rowInset, warningButton), (0, true));
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
    final deleteCopy = find.text(
      'Permanently deletes this app registration and its current credentials.',
    );
    final copyInset = t.getTopLeft(deleteCopy).dx - t.getTopLeft(card).dx;
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
    expect(copyInset, 0);
    expect(find.byKey(editor), findsNothing);
    expect(find.text('No Raft Apps yet'), findsOneWidget);
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
    expect(t.getSize(toggle).height, 20);
    expect(
      find.text(
        'Uses existing installation credentials and APIs. No login or webhook required.',
      ),
      findsNothing,
    );
    final deliveryBadge = t.widget<RaftSettingsRecipeBadge>(
      find.ancestor(
        of: find.text('Disabled'),
        matching: find.byType(RaftSettingsRecipeBadge),
      ),
    );
    expect(deliveryBadge.appearance, RaftBadgeRecipeAppearance.soft);
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
    final save = find.byKey(const ValueKey('app-notifications-save'));
    await t.ensureVisible(save);
    await t.tap(save);
    await t.pumpAndSettle();
    expect(find.text('whsec_once'), findsOneWidget);
  });

  testWidgets('webhook: deliveries only stop when the unchecked box is saved', (
    t,
  ) async {
    final (w, a) = (await t.runAsync(_fixture))!;
    addTearDown(w.dispose);
    _routes(a, [Map<String, dynamic>.from(_app)]);
    const path = '/integrations/clients/app-1/app-notifications';
    var enabled = true;
    a.routes['GET $path'] = (_) => {
      'current_groups': ['server'],
      'current_events': <String>[],
      'webhook': {
        'endpoint_url': 'https://hooks.example/raft',
        'enabled': enabled,
      },
    };
    a.routes['DELETE $path/webhook'] = (_) {
      enabled = false;
      return <String, dynamic>{};
    };
    await _mount(t, w);
    await t.tap(find.byKey(const ValueKey('connected-app-action-app-1')));
    await t.pumpAndSettle();
    final toggle = find.byKey(const ValueKey('app-notifications-enabled'));
    await t.ensureVisible(toggle);
    await t.tap(toggle);
    await t.pumpAndSettle();
    expect(enabled, isTrue);
    final save = find.byKey(const ValueKey('app-notifications-save'));
    await t.ensureVisible(save);
    await t.tap(save);
    await t.pumpAndSettle();
    expect(enabled, isFalse);
    expect(
      find.text('Events keep going to this endpoint until you save.'),
      findsNothing,
    );
  });

  testWidgets('webhook: rotating waits for confirmation', (t) async {
    final (w, a) = (await t.runAsync(_fixture))!;
    addTearDown(w.dispose);
    _routes(a, [Map<String, dynamic>.from(_app)]);
    const path = '/integrations/clients/app-1/app-notifications';
    a.routes['GET $path'] = (_) => {
      'current_groups': ['server'],
      'current_events': <String>[],
      'webhook': {
        'endpoint_url': 'https://hooks.example/raft',
        'enabled': true,
      },
    };
    var rotations = 0;
    a.routes['POST $path/webhook/rotate-secret'] = (_) {
      rotations++;
      return {'signing_secret': 'rotated-once'};
    };
    await _mount(t, w);
    await t.tap(find.byKey(const ValueKey('connected-app-action-app-1')));
    await t.pumpAndSettle();
    final rotate = find.text('Rotate secret');
    await t.ensureVisible(rotate);
    await t.tap(rotate);
    await t.pumpAndSettle();
    expect(rotations, 0);
    await t.tap(
      find.byKey(const ValueKey('app-notifications-rotate-secret-confirm')),
    );
    await t.pumpAndSettle();
    expect(rotations, 1);
    expect(find.text('rotated-once'), findsOneWidget);
  });
}
