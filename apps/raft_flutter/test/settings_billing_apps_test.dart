// Settings > Applications (IntegrationsSection): data lifecycle, gates and
// mutations against the mounted Web endpoints. (Plan & Billing is
// billing_overview_v124_test.dart.)
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/integrations_views.dart';
import 'package:raft_ui/raft_ui.dart';

class _Adapter implements HttpClientAdapter {
  final calls = <RequestOptions>[];
  final statuses = <String, int>{};
  final Map<String, FutureOr<dynamic> Function(RequestOptions)> routes = {};
  Completer<void>? gate;
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) async {
    calls.add(o);
    if (gate != null && !o.path.startsWith('/auth')) await gate!.future;
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
  List<RequestOptions> posts(String path) =>
      calls.where((c) => c.method == 'POST' && c.path == path).toList();
}

Future<(WorkspaceController, _Adapter)> _fixture(String role) async {
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
    'slug': 'test',
    'plan': 'free',
    'role': role,
  });
  w.servers = [w.server!];
  return (w, a);
}

Widget _host(Widget child, {double width = 1280}) => MediaQuery(
  data: MediaQueryData(size: Size(width, 2000)),
  child: MaterialApp(
    theme: raftTheme(),
    home: Scaffold(
      body: ListView(padding: const EdgeInsets.all(20), children: [child]),
    ),
  ),
);

void _surface(WidgetTester t, [double width = 1280]) {
  t.view.physicalSize = Size(width, 2000);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

void main() {
  group('Applications', () {
    Map<String, dynamic> listing(
      String id,
      String name, {
      String? installedAt,
      String category = 'Developer Tools',
      Map<String, dynamic>? badge,
    }) => {
      'id': id,
      'clientId': 'client_$id',
      'name': name,
      'description': '$name description',
      'category': category,
      'publisherName': 'Raft Labs',
      'homepageUrl': 'https://example.com/$id',
      'returnUrl': 'https://example.com/$id/callback',
      'allowedScopes': ['openid', 'profile'],
      'installedAt': installedAt,
      'privateShared': false,
      'publishStatus': 'published',
      'marketplaceInstallBadge': badge ?? {'kind': 'none'},
    };

    Future<(WorkspaceController, _Adapter)> mount(
      WidgetTester t, {
      String role = 'owner',
    }) async {
      final (w, a) = (await t.runAsync(() => _fixture(role)))!;
      addTearDown(w.dispose);
      a.routes['GET /integrations/marketplace'] = (_) => [
        listing(
          'slack',
          'Slack Bridge',
          badge: {'kind': 'bucket', 'bucket': '100_plus'},
        ),
        listing(
          'github',
          'GitHub Issues',
          installedAt: '2026-06-18T00:00:00.000Z',
          category: 'Productivity & Collaboration',
        ),
        {...listing('shared', 'Shared App'), 'privateShared': true},
      ];
      a.routes['GET /integrations/clients'] = (_) => [
        {
          'id': 'local',
          'clientId': 'client_local',
          'name': 'Local Tool',
          'appType': 'server_local',
          'publishStatus': 'private',
          'installationId': 'local-install',
          'category': 'Other',
        },
      ];
      a.routes['GET /integrations/overview'] = (_) => [
        {
          'id': 'g1',
          'type': 'active',
          'clientId': 'github',
          'scopes': ['openid'],
          'revokedAt': null,
        },
      ];
      a.routes['GET /integrations/marketplace/github/install/app-notifications'] =
          (_) => {
            'requested_groups': <String>[],
            'approved_groups': <String>[],
            'subscribed_events': <String>[],
            'effective_groups': <String>[],
            'effective_events': <String>[],
            'app_review_pending': false,
            'approval_required': false,
          };
      _surface(t);
      await t.pumpWidget(_host(IntegrationsView(controller: w)));
      await t.pumpAndSettle();
      return (w, a);
    }

    testWidgets('marketplace tab: counts, badges, search and category', (
      t,
    ) async {
      await mount(t);
      await t.tap(find.byKey(const ValueKey('connected-apps-tab-marketplace')));
      await t.pumpAndSettle();
      expect(find.text('Apps'), findsOneWidget);
      expect(find.text('Third-party apps for this server'), findsNothing);
      // Settings does not fetch the unfiltered Marketplace total for its tab.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('connected-apps-tab-marketplace')),
          matching: find.text('2'),
        ),
        findsNothing,
      );
      expect(find.text('Shared App'), findsNothing);
      expect(find.text('100+ installs'), findsOneWidget);
      expect(find.text('Install'), findsOneWidget);
      expect(find.text('Installed'), findsNWidgets(2)); // tab + state badge
      expect(find.text('Developer tools · by Raft Labs'), findsOneWidget);
      await t.enterText(
        find.byKey(const ValueKey('connected-apps-search')),
        'github',
      );
      await t.pumpAndSettle();
      expect(find.text('Slack Bridge'), findsNothing);
      expect(find.text('GitHub Issues'), findsOneWidget);
      await t.enterText(
        find.byKey(const ValueKey('connected-apps-search')),
        '',
      );
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('connected-apps-category-filter')));
      await t.pumpAndSettle();
      await t.tap(find.text('Communication').last);
      await t.pumpAndSettle();
      expect(find.text('No marketplace apps match this view'), findsOneWidget);
    });

    testWidgets('listing detail installs to this server', (t) async {
      final (_, a) = await mount(t);
      a.routes['POST /integrations/marketplace/slack/install'] = (_) => {
        'ok': true,
      };
      await t.tap(find.byKey(const ValueKey('connected-apps-tab-marketplace')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('connected-app-slack')));
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('connected-app-detail')),
        findsOneWidget,
      );
      expect(find.text('App detail'), findsOneWidget);
      expect(find.text('example.com'), findsOneWidget);
      expect(find.text('Install to this server'), findsOneWidget);
      final before = a.calls
          .where((c) => c.path == '/integrations/marketplace')
          .length;
      await t.tap(find.byKey(const ValueKey('connected-app-install')));
      await t.pumpAndSettle();
      expect(a.posts('/integrations/marketplace/slack/install'), hasLength(1));
      expect(find.byKey(const ValueKey('connected-app-detail')), findsNothing);
      expect(
        a.calls.where((c) => c.path == '/integrations/marketplace').length,
        before + 1,
      );
    });

    testWidgets('installed tab: access detail and confirmed uninstall', (
      t,
    ) async {
      final (_, a) = await mount(t);
      await t.tap(find.byKey(const ValueKey('connected-apps-tab-installed')));
      await t.pumpAndSettle();
      expect(find.text('Local Tool'), findsOneWidget);
      expect(find.text('This server'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('connected-app-installed-github')));
      await t.pumpAndSettle();
      expect(find.text('Installed app'), findsOneWidget);
      expect(find.text('No data access'), findsOneWidget);
      await t.tap(find.text('Close').last);
      await t.pumpAndSettle();
      a.routes['DELETE /integrations/marketplace/github/install'] = (_) => {
        'ok': true,
      };
      await t.tap(find.byKey(const ValueKey('connected-app-action-github')));
      await t.pumpAndSettle();
      expect(find.text('Uninstall GitHub Issues?'), findsOneWidget);
      await t.tap(
        find.byKey(const ValueKey('connected-app-uninstall-confirm-button')),
      );
      await t.pumpAndSettle();
      expect(
        a.calls.where(
          (c) =>
              c.method == 'DELETE' &&
              c.path == '/integrations/marketplace/github/install',
        ),
        hasLength(1),
      );
    });

    testWidgets('members browse read-only', (t) async {
      final (_, a) = await mount(t, role: 'member');
      await t.tap(find.byKey(const ValueKey('connected-apps-tab-marketplace')));
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('connected-apps-register')),
        findsNothing,
      );
      expect(find.text('Available'), findsOneWidget);
      expect(
        find.text(
          'Only server owners and admins can install, edit, or remove apps.',
        ),
        findsOneWidget,
      );
      await t.tap(find.byKey(const ValueKey('connected-app-slack')));
      await t.pumpAndSettle();
      expect(find.text('Install to this server'), findsNothing);
      expect(
        a.calls.where(
          (call) =>
              call.method != 'GET' &&
              !call.path.startsWith('/auth') &&
              !call.path.endsWith('/feature-flags/evaluate'),
        ),
        isEmpty,
      );
    });

    testWidgets('list layout shows summaries', (t) async {
      await mount(t);
      await t.tap(find.byKey(const ValueKey('connected-apps-tab-marketplace')));
      await t.pumpAndSettle();
      expect(find.text('Slack Bridge description'), findsNothing);
      await t.tap(find.byKey(const ValueKey('connected-apps-view-list')));
      await t.pumpAndSettle();
      expect(find.text('Slack Bridge description'), findsOneWidget);
    });
  });
}
