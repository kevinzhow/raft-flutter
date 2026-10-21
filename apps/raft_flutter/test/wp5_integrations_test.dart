// WP5 (Web v1.21.12): Agent access JWT card, permission-update review,
// "When to use" counter and "Update Slack authorization".
import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/app_when_to_use.dart';
import 'package:raft_flutter/features/im_bridges_view.dart';
import 'package:raft_flutter/features/integrations_views.dart';
import 'package:raft_ui/raft_ui.dart';

import 'slack_bridge_contract_test.dart' show bridgeFixture;

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
  List<RequestOptions> of(String method, String path) =>
      calls.where((c) => c.method == method && c.path == path).toList();
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
  w.server = RaftRecord({'id': 's1', 'name': 'Test', 'role': 'owner'});
  w.servers = [w.server!];
  return (w, a);
}

Widget _host(Widget child) => MaterialApp(
  theme: raftTheme(RaftFamily.elegant),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

Map<String, dynamic> _jwt({
  String scope = 'installation',
  bool enabled = false,
  bool canEnable = true,
}) => {
  'scope': scope,
  'enabled': enabled,
  'appEnabled': true,
  'effectiveEnabled': enabled,
  'canEnable': canEnable,
  'audience': 'https://app.example/aud',
  'expiresIn': 300,
};

Map<String, dynamic> _listing(
  String id, {
  String? installedAt,
  Map<String, dynamic> extra = const {},
}) => {
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
  ...extra,
};

Future<(WorkspaceController, _Adapter)> _mountApps(
  WidgetTester t,
  List<Map<String, dynamic>> Function() marketplace,
) async {
  final (w, a) = (await t.runAsync(_fixture))!;
  addTearDown(w.dispose);
  a.routes['GET /integrations/marketplace'] = (_) => marketplace();
  a.routes['GET /integrations/clients'] = (_) => <dynamic>[];
  a.routes['GET /integrations/overview'] = (_) => <dynamic>[];
  a.routes['GET /integrations/marketplace/inst/install/app-notifications'] =
      (_) => {
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
  await t.pumpWidget(_host(IntegrationsView(controller: w)));
  await t.pumpAndSettle();
  return (w, a);
}

void main() {
  group('Agent access JWT card', () {
    testWidgets('installed app detail loads, saves and re-reads the settings', (
      t,
    ) async {
      final (_, a) = await _mountApps(
        t,
        () => [_listing('inst', installedAt: '2026-06-18T00:00:00.000Z')],
      );
      var saved = _jwt();
      a.routes['GET /integrations/clients/inst/agent-jwt'] = (_) => saved;
      a.routes['PUT /integrations/clients/inst/agent-jwt'] = (o) {
        saved = _jwt(enabled: (o.data as Map)['enabled'] == true);
        return saved;
      };
      await t.tap(find.byKey(const ValueKey('connected-apps-tab-installed')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('connected-app-installed-inst')));
      await t.pumpAndSettle();
      expect(find.text('Agent access JWT'), findsOneWidget);
      expect(find.text('Allow Agent JWTs on this Server'), findsOneWidget);
      expect(
        find.textContaining('Audience: https://app.example/aud.'),
        findsOneWidget,
      );
      final save = find.byKey(const ValueKey('agent-jwt-save'));
      // Unchanged draft: nothing to save yet.
      expect(t.widget<RaftSettingsRecipeButton>(save).onPressed, isNull);
      await t.tap(find.byKey(const ValueKey('agent-jwt-switch')));
      await t.pumpAndSettle();
      expect(t.widget<RaftSettingsRecipeButton>(save).onPressed, isNotNull);
      await t.tap(save);
      await t.pumpAndSettle();
      final puts = a.of('PUT', '/integrations/clients/inst/agent-jwt');
      expect(puts, hasLength(1));
      expect(puts.single.data, {'enabled': true});
      expect(t.widget<RaftSettingsRecipeButton>(save).onPressed, isNull);
      expect(
        t
            .widget<RaftSwitch>(find.byKey(const ValueKey('agent-jwt-switch')))
            .value,
        isTrue,
      );
    });

    testWidgets('canEnable false keeps the switch off with the reason', (
      t,
    ) async {
      final (_, a) = await _mountApps(
        t,
        () => [_listing('inst', installedAt: '2026-06-18T00:00:00.000Z')],
      );
      a.routes['GET /integrations/clients/inst/agent-jwt'] = (_) =>
          _jwt(scope: 'app', canEnable: false);
      await t.tap(find.byKey(const ValueKey('connected-app-inst')));
      await t.pumpAndSettle();
      expect(find.text('Enable Agent JWT support'), findsOneWidget);
      expect(
        find.text(
          'Enable the App and its openid/profile login scopes before turning on JWT access.',
        ),
        findsOneWidget,
      );
      expect(
        t
            .widget<RaftSwitch>(find.byKey(const ValueKey('agent-jwt-switch')))
            .enabled,
        isFalse,
      );
    });

    testWidgets(
      'a failed load shows the retry warning; not installed hides it',
      (t) async {
        final (_, a) = await _mountApps(
          t,
          () => [
            _listing('inst', installedAt: '2026-06-18T00:00:00.000Z'),
            _listing('new'),
          ],
        );
        a.statuses['GET /integrations/clients/inst/agent-jwt'] = 500;
        await t.tap(find.byKey(const ValueKey('connected-app-inst')));
        await t.pumpAndSettle();
        expect(
          find.text(
            'Could not load or save JWT settings. Retry before relying on this change.',
          ),
          findsOneWidget,
        );
        await t.tap(find.text('Cancel').last);
        await t.pumpAndSettle();
        await t.tap(find.byKey(const ValueKey('connected-app-new')));
        await t.pumpAndSettle();
        expect(find.text('Agent access JWT'), findsNothing);
      },
    );
  });

  group('Permission update review', () {
    Map<String, dynamic> pending({bool reviewer = true}) => _listing(
      'rev',
      extra: {
        'appNotificationReviewPending': true,
        'appNotificationPendingRevisionId': 'rev-seen-by-reviewer',
        'appNotificationPendingGroups': ['server', 'agent'],
        'appNotificationPendingEvents': <String>[],
        'canReviewAppNotifications': reviewer,
      },
    );

    testWidgets('reviewer sees the requested groups and approves that revision', (
      t,
    ) async {
      var current = pending();
      final (_, a) = await _mountApps(t, () => [current]);
      a.routes['POST /integrations/clients/rev/app-notifications/permissions/review'] =
          (_) {
            current = _listing(
              'rev',
              extra: {
                'appNotificationGroups': ['server', 'agent'],
                'canReviewAppNotifications': true,
              },
            );
            return {'revision': 2};
          };
      await t.tap(find.byKey(const ValueKey('connected-app-rev')));
      await t.pumpAndSettle();
      expect(find.text('Permission update pending review'), findsOneWidget);
      expect(find.text('REQUESTED DATA GROUPS'), findsOneWidget);
      expect(find.text('REQUESTED NOTIFICATION EVENTS'), findsOneWidget);
      expect(
        find.text('A marketplace reviewer can approve this permission update.'),
        findsOneWidget,
      );
      await t.tap(
        find.byKey(const ValueKey('app-notifications-review-approve')),
      );
      await t.pumpAndSettle();
      final posts = a.of(
        'POST',
        '/integrations/clients/rev/app-notifications/permissions/review',
      );
      expect(posts, hasLength(1));
      expect(posts.single.data, {
        'expected_revision_id': 'rev-seen-by-reviewer',
      });
      // The listing reloaded: no pending state left.
      expect(find.text('Permission update pending review'), findsNothing);
      expect(find.text('DATA GROUPS'), findsOneWidget);
      expect(find.text('Approve update'), findsNothing);
    });

    testWidgets('a stale revision (409) surfaces the server message', (
      t,
    ) async {
      final (_, a) = await _mountApps(t, () => [pending()]);
      const path =
          'POST /integrations/clients/rev/app-notifications/permissions/review';
      a.routes[path] = (_) => {
        'error': 'The displayed permission request has been replaced.',
        'code': 'permission_revision_stale',
      };
      a.statuses[path] = 409;
      await t.tap(find.byKey(const ValueKey('connected-app-rev')));
      await t.pumpAndSettle();
      await t.tap(
        find.byKey(const ValueKey('app-notifications-review-approve')),
      );
      await t.pumpAndSettle();
      expect(
        find.text('The displayed permission request has been replaced.'),
        findsOneWidget,
      );
      expect(find.text('Permission update pending review'), findsOneWidget);
    });

    testWidgets('a non-reviewer sees the pending request but no action', (
      t,
    ) async {
      await _mountApps(t, () => [pending(reviewer: false)]);
      await t.tap(find.byKey(const ValueKey('connected-app-rev')));
      await t.pumpAndSettle();
      expect(find.text('Permission update pending review'), findsOneWidget);
      expect(find.text('REQUESTED DATA GROUPS'), findsOneWidget);
      expect(find.text('Approve update'), findsNothing);
    });

    testWidgets('without a displayed revision id the action stays disabled', (
      t,
    ) async {
      final listing = pending()..['appNotificationPendingRevisionId'] = null;
      await _mountApps(t, () => [listing]);
      await t.tap(find.byKey(const ValueKey('connected-app-rev')));
      await t.pumpAndSettle();
      expect(
        t
            .widget<RaftSettingsRecipeButton>(
              find.byKey(const ValueKey('app-notifications-review-approve')),
            )
            .onPressed,
        isNull,
      );
    });
  });

  group('When to use counter', () {
    test('counts trimmed Unicode code points against 160', () {
      expect(countAppWhenToUseCharacters('  hi  '), 2);
      expect(countAppWhenToUseCharacters('😀' * 3), 3);
      expect(isAppWhenToUseTooLong('a' * 160), isFalse);
      expect(isAppWhenToUseTooLong('${'a' * 160}b'), isTrue);
      expect(isAppWhenToUseTooLong('${'a' * 160}   '), isFalse);
    });

    testWidgets('shows a live count and blocks saving past the limit', (
      t,
    ) async {
      final (_, a) = await _mountApps(t, () => []);
      a.routes['POST /integrations/clients'] = (_) => {
        'client': {'id': 'x'},
      };
      await t.tap(find.text('Register app'));
      await t.pumpAndSettle();
      await t.enterText(
        find.byKey(const ValueKey('connected-app-name')),
        'Long hint app',
      );
      final field = find.byKey(const ValueKey('connected-app-when-to-use'));
      final count = find.byKey(
        const ValueKey('connected-app-when-to-use-count'),
      );
      expect(t.widget<Text>(count).data, '0 / 160 characters');
      await t.enterText(field, 'a' * 161);
      await t.pumpAndSettle();
      // No hard cap: the 161st character stays and the count says so.
      expect(t.widget<Text>(count).data, '161 / 160 characters');
      expect(
        find.text('Use no more than 160 characters before saving.'),
        findsOneWidget,
      );
      final submit = find.byKey(const ValueKey('connected-app-editor-submit'));
      await t.tap(submit, warnIfMissed: false);
      await t.pumpAndSettle();
      expect(a.of('POST', '/integrations/clients'), isEmpty);
      await t.enterText(field, 'a' * 160);
      await t.pumpAndSettle();
      expect(
        find.text('Use no more than 160 characters before saving.'),
        findsNothing,
      );
      await t.tap(submit);
      await t.pumpAndSettle();
      expect(a.of('POST', '/integrations/clients'), hasLength(1));
    });
  });

  group('Update Slack authorization', () {
    Future<(_Adapter, List<String>)> mount(
      WidgetTester t, {
      String stage = 'health',
    }) async {
      final (w, a) = (await t.runAsync(_fixture))!;
      addTearDown(w.dispose);
      final launched = <String>[];
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/url_launcher'),
        (call) async {
          if (call.method == 'launch') {
            launched.add((call.arguments as Map)['url'] as String);
          }
          return true;
        },
      );
      addTearDown(
        () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/url_launcher'),
          null,
        ),
      );
      a.routes['POST /feature-flags/evaluate'] = (_) => {
        'evaluations': [
          {'key': 'slack_bridge_v0', 'enabled': true},
        ],
      };
      const authority = {
        'registrationId': '11111111-1111-4111-8111-111111111111',
        'serverGrantId': '22222222-2222-4222-8222-222222222222',
        'grantEpoch': 2,
      };
      a.routes['GET /slack-bridge/provisioning'] = (_) => bridgeFixture()
        ..['snapshot']['stage'] = stage
        ..['oauthAuthority'] = authority;
      a.routes['POST /slack-bridge/oauth/start'] = (_) => {
        'authorizationUrl': 'https://slack.example/oauth/authorize?state=abc',
        'expiresAt': '2026-10-21T00:00:00Z',
      };
      t.view.physicalSize = const Size(1280, 2400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Scaffold(body: IMBridgesView(controller: w)),
        ),
      );
      await t.pumpAndSettle();
      return (a, launched);
    }

    testWidgets('re-posts the OAuth start with the loaded authority', (
      t,
    ) async {
      final (a, launched) = await mount(t);
      final button = find.byKey(const ValueKey('slack-bridge-reauthorize'));
      expect(find.text('Update Slack authorization'), findsOneWidget);
      expect(find.text('Disconnect Slack workspace'), findsOneWidget);
      final before = a.of('GET', '/slack-bridge/provisioning').length;
      await t.ensureVisible(button);
      await t.tap(button);
      await t.pumpAndSettle();
      // Reloads the snapshot first, then starts OAuth from its authority.
      expect(a.of('GET', '/slack-bridge/provisioning').length, before + 1);
      final starts = a.of('POST', '/slack-bridge/oauth/start');
      expect(starts, hasLength(1));
      expect(starts.single.data, {
        'registrationId': '11111111-1111-4111-8111-111111111111',
        'serverGrantId': '22222222-2222-4222-8222-222222222222',
        'grantEpoch': 2,
      });
      expect(launched, ['https://slack.example/oauth/authorize?state=abc']);
    });

    testWidgets('is not offered at the OAuth stage', (t) async {
      await mount(t, stage: 'oauth');
      expect(find.text('Update Slack authorization'), findsNothing);
    });
  });
}
