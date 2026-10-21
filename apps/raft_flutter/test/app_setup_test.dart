// Web v1.21.23 app installation setup (AppSetup.tsx): the URL rules, the
// per-installation panel, the listing / installed details, the publisher
// editor and the install action card.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/app_setup.dart';
import 'package:raft_flutter/features/connected_app_editor.dart';
import 'package:raft_flutter/features/integrations_views.dart';
import 'package:raft_flutter/features/message_action_card.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/integ_fixture.dart';

Map<String, dynamic> _setup({
  String status = 'pending',
  bool canConfigure = true,
  String? url = 'https://setup.example.com/start?installation_id=i1',
  String? description = 'Connect your Acme account.',
}) => {
  'status': status,
  'url': url,
  'description': description,
  'revision': 2,
  'completedAt': status == 'complete' ? '2026-10-21T00:00:00.000Z' : null,
  'canConfigure': canConfigure,
};

Map<String, dynamic> _listing({
  String? installedAt,
  String? setupUrl = 'https://setup.example.com/start',
}) => {
  'id': 'app1',
  'clientId': 'client_app1',
  'name': 'Acme',
  'description': 'desc',
  'category': 'Developer Tools',
  'publisherName': 'Labs',
  'homepageUrl': 'https://example.com',
  'returnUrl': 'https://example.com/cb',
  'allowedScopes': ['openid', 'profile'],
  'installedAt': installedAt,
  'privateShared': false,
  'publishStatus': 'published',
  'appNotificationGroups': ['server'],
  'appNotificationEvents': <String>[],
  'setupUrl': ?setupUrl,
  'setupDescription': ?(setupUrl == null ? null : 'Connect your Acme account.'),
};

void main() {
  group('setup URL rules (normalizeAppSetupUrl)', () {
    test('accepts https, loopback http, and empty as "no setup"', () {
      expect(normalizeAppSetupUrl(null), isNull);
      expect(normalizeAppSetupUrl(''), isNull);
      expect(normalizeAppSetupUrl('   '), isNull);
      expect(
        normalizeAppSetupUrl(' https://a.example/setup '),
        'https://a.example/setup',
      );
      expect(
        normalizeAppSetupUrl('http://localhost:3000/setup'),
        'http://localhost:3000/setup',
      );
      expect(
        normalizeAppSetupUrl('http://127.0.0.1/setup'),
        'http://127.0.0.1/setup',
      );
    });
    test('rejects plain http, credentials, fragments, schemes and length', () {
      for (final bad in [
        'http://a.example/setup',
        'https://user:pw@a.example/setup',
        'https://a.example/setup#frag',
        'javascript:alert(1)',
        'ftp://a.example/x',
        'not a url',
        'https://a.example/${'x' * 2000}',
      ]) {
        expect(
          () => normalizeAppSetupUrl(bad),
          throwsFormatException,
          reason: bad,
        );
      }
    });
    test('domain shows the host and a non-default port', () {
      expect(
        appSetupDomain('https://setup.example.com/a?b=1'),
        'setup.example.com',
      );
      expect(appSetupDomain('http://localhost:8080/x'), 'localhost:8080');
      expect(appSetupDomain('http://evil.example/x'), isNull);
      expect(appSetupDomain(null), isNull);
    });
  });

  group('setup state body', () {
    test('parses the three statuses', () {
      expect(AppSetupState.parse(_setup())!.complete, isFalse);
      expect(AppSetupState.parse(_setup(status: 'complete'))!.complete, isTrue);
      final none = AppSetupState.parse(
        _setup(status: 'not_required', url: null, description: null),
      );
      expect(none!.status, 'not_required');
    });
    test('rejects what Web rejects', () {
      expect(AppSetupState.parse(_setup(status: 'done')), isNull);
      expect(AppSetupState.parse({..._setup(), 'revision': 0}), isNull);
      expect(AppSetupState.parse({..._setup(), 'canConfigure': 'yes'}), isNull);
      expect(AppSetupState.parse(_setup(url: null)), isNull);
      expect(AppSetupState.parse(_setup(url: 'http://evil.example/x')), isNull);
      // A member without authority gets no URL; that is fine.
      expect(
        AppSetupState.parse(_setup(canConfigure: false, url: null)),
        isNotNull,
      );
    });
  });

  group('AppSetupPanel', () {
    testWidgets('an admin sees pending status and opens the setup page', (
      t,
    ) async {
      final (w, a) = (await t.runAsync(() => integFixture('owner')))!;
      addTearDown(w.dispose);
      a.routes['GET /integrations/clients/app1/setup'] = (_) => _setup();
      final opened = <String>[];
      await t.pumpWidget(
        integHost(
          AppSetupPanel(
            controller: w,
            clientId: 'app1',
            open: (u) async => opened.add(u),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Installation setup'), findsOneWidget);
      expect(find.text('Installed, setup pending'), findsOneWidget);
      expect(find.text('Connect your Acme account.'), findsOneWidget);
      expect(find.text('Opens setup.example.com in a new tab'), findsOneWidget);
      await t.tap(find.text('Continue setup'));
      await t.pumpAndSettle();
      expect(opened, ['https://setup.example.com/start?installation_id=i1']);
    });

    testWidgets('a member sees the status and who can configure', (t) async {
      final (w, a) = (await t.runAsync(() => integFixture('member')))!;
      addTearDown(w.dispose);
      a.routes['GET /integrations/clients/app1/setup'] = (_) =>
          _setup(canConfigure: false, url: null);
      await t.pumpWidget(
        integHost(AppSetupPanel(controller: w, clientId: 'app1')),
      );
      await t.pumpAndSettle();
      expect(find.text('Continue setup'), findsNothing);
      expect(
        find.text('Ask a Server administrator to complete configuration.'),
        findsOneWidget,
      );
    });

    testWidgets('complete offers Manage configuration', (t) async {
      final (w, a) = (await t.runAsync(() => integFixture('admin')))!;
      addTearDown(w.dispose);
      a.routes['GET /integrations/clients/app1/setup'] = (_) =>
          _setup(status: 'complete');
      await t.pumpWidget(
        integHost(AppSetupPanel(controller: w, clientId: 'app1')),
      );
      await t.pumpAndSettle();
      expect(find.text('Configured'), findsOneWidget);
      expect(find.text('Manage configuration'), findsOneWidget);
    });

    testWidgets('an App with no setup page shows nothing', (t) async {
      final (w, a) = (await t.runAsync(() => integFixture('owner')))!;
      addTearDown(w.dispose);
      a.routes['GET /integrations/clients/app1/setup'] = (_) =>
          _setup(status: 'not_required', url: null, description: null);
      await t.pumpWidget(
        integHost(AppSetupPanel(controller: w, clientId: 'app1')),
      );
      await t.pumpAndSettle();
      expect(find.text('Installation setup'), findsNothing);
    });

    testWidgets('a bad body is an error, Refresh status reads again', (
      t,
    ) async {
      final (w, a) = (await t.runAsync(() => integFixture('owner')))!;
      addTearDown(w.dispose);
      var bad = true;
      a.routes['GET /integrations/clients/app1/setup'] = (_) =>
          bad ? {'status': 'wat'} : _setup();
      await t.pumpWidget(
        integHost(AppSetupPanel(controller: w, clientId: 'app1')),
      );
      await t.pumpAndSettle();
      expect(
        find.text('Could not load configuration status. Try again.'),
        findsOneWidget,
      );
      bad = false;
      await t.tap(find.text('Refresh status'));
      await t.pumpAndSettle();
      expect(find.text('Installed, setup pending'), findsOneWidget);
      expect(a.calls.where((c) => c.path.endsWith('/setup')), hasLength(2));
    });

    testWidgets('returning to the app refreshes the state', (t) async {
      final (w, a) = (await t.runAsync(() => integFixture('owner')))!;
      addTearDown(w.dispose);
      var status = 'pending';
      a.routes['GET /integrations/clients/app1/setup'] = (_) =>
          _setup(status: status);
      await t.pumpWidget(
        integHost(AppSetupPanel(controller: w, clientId: 'app1')),
      );
      await t.pumpAndSettle();
      expect(find.text('Installed, setup pending'), findsOneWidget);
      status = 'complete';
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pumpAndSettle();
      expect(find.text('Configured'), findsOneWidget);
    });
  });

  group('app details', () {
    Future<void> openIntegrations(
      WidgetTester t,
      Map<String, dynamic> listing,
    ) async {
      final (w, a) = (await t.runAsync(() => integFixture('owner')))!;
      addTearDown(w.dispose);
      var installed = listing['installedAt'] != null;
      a.routes['GET /integrations/marketplace'] = (_) => [
        {
          ...listing,
          'installedAt': installed ? '2026-10-21T00:00:00.000Z' : null,
        },
      ];
      a.routes['GET /integrations/clients'] = (_) => <dynamic>[];
      a.routes['GET /integrations/overview'] = (_) => <dynamic>[];
      a.routes['POST /integrations/marketplace/app1/install'] = (_) {
        installed = true;
        return {};
      };
      a.routes['GET /integrations/marketplace/app1/install/app-notifications'] =
          (_) => {
            'requested_groups': <String>[],
            'approved_groups': <String>[],
            'subscribed_events': <String>[],
            'effective_groups': <String>[],
            'effective_events': <String>[],
            'app_review_pending': false,
            'approval_required': false,
          };
      a.routes['GET /integrations/clients/app1/setup'] = (_) => _setup();
      t.view.physicalSize = const Size(1280, 2400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(integHost(IntegrationsView(controller: w)));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('connected-app-app1')));
      await t.pumpAndSettle();
    }

    testWidgets('a listing that needs setup says so before the install', (
      t,
    ) async {
      await openIntegrations(t, _listing());
      expect(find.text('Setup required'), findsOneWidget);
      expect(
        find.text(
          'After installation, continue configuration at setup.example.com.',
        ),
        findsOneWidget,
      );
      expect(find.text('Connect your Acme account.'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('app-installation-setup')),
        findsNothing,
      );
    });

    testWidgets('a listing without a setup page shows neither', (t) async {
      await openIntegrations(t, _listing(setupUrl: null));
      expect(find.text('Setup required'), findsNothing);
      expect(
        find.byKey(const ValueKey('app-installation-setup')),
        findsNothing,
      );
    });

    testWidgets('installing stays open on the setup panel', (t) async {
      await openIntegrations(t, _listing());
      await t.tap(find.byKey(const ValueKey('connected-app-install')));
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('connected-app-detail')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('app-installation-setup')),
        findsOneWidget,
      );
      expect(find.text('Installed, setup pending'), findsOneWidget);
      expect(find.text('Continue setup'), findsOneWidget);
    });

    testWidgets('installing an App with no setup closes the detail', (t) async {
      await openIntegrations(t, _listing(setupUrl: null));
      await t.tap(find.byKey(const ValueKey('connected-app-install')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('connected-app-detail')), findsNothing);
    });

    testWidgets('an installed App shows the panel in the installed detail', (
      t,
    ) async {
      await openIntegrations(t, _listing(installedAt: 'x'));
      expect(
        find.byKey(const ValueKey('app-installation-setup')),
        findsOneWidget,
      );
    });
  });

  group('publisher editor', () {
    Future<(IntegAdapter, ValueNotifier<ConnectedAppSecret?>)> pump(
      WidgetTester t, {
      Map<String, dynamic>? app,
    }) async {
      final (w, a) = (await t.runAsync(() => integFixture('owner')))!;
      addTearDown(w.dispose);
      a.routes['PATCH /integrations/clients/app-1'] = (_) => {};
      a.routes['POST /integrations/clients'] = (_) => {
        'client': {'id': 'new'},
      };
      a.routes['GET /integrations/clients/app-1/share-link'] = (_) => {};
      a.routes['GET /integrations/clients/app-1/app-notifications'] = (_) => {
        'request_revision': 0,
        'current_groups': ['server'],
        'current_events': <String>[],
        'pending_revision': null,
        'webhook': {'enabled': false},
      };
      t.view.physicalSize = const Size(1400, 3000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final secret = ValueNotifier<ConnectedAppSecret?>(null);
      addTearDown(secret.dispose);
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Scaffold(
            body: ConnectedAppEditor(
              controller: w,
              secret: secret,
              app: app,
              onSaved: ({created}) async {},
              onClose: () {},
              onDenied: (_) => false,
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      return (a, secret);
    }

    const base = {
      'id': 'app-1',
      'clientId': 'db9',
      'name': 'db9 Drive',
      'description': 'd',
      'homepageUrl': 'https://example.com',
      'allowedScopes': ['openid', 'profile', 'identity'],
      'category': 'Other',
      'publishStatus': 'private',
      'appType': 'server_local',
    };

    testWidgets('the setup section starts off, the fields appear on demand', (
      t,
    ) async {
      await pump(t, app: base);
      expect(find.text('No setup required'), findsOneWidget);
      expect(find.byKey(const ValueKey('app-setup-url')), findsNothing);
      await t.ensureVisible(find.byKey(const ValueKey('app-setup-required')));
      await t.tap(find.byKey(const ValueKey('app-setup-required')));
      await t.pumpAndSettle();
      expect(find.text('Setup required'), findsOneWidget);
      expect(find.byKey(const ValueKey('app-setup-url')), findsOneWidget);
      expect(
        find.textContaining('Configuration instructions', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('saving sends the setup URL and instructions', (t) async {
      final (a, _) = await pump(t, app: base);
      await t.ensureVisible(find.byKey(const ValueKey('app-setup-required')));
      await t.tap(find.byKey(const ValueKey('app-setup-required')));
      await t.pumpAndSettle();
      await t.enterText(
        find.byKey(const ValueKey('app-setup-url')),
        'https://setup.example.com/start',
      );
      await t.enterText(
        find.byKey(const ValueKey('app-setup-description')),
        'Connect your account',
      );
      await t.tap(find.byKey(const ValueKey('connected-app-editor-submit')));
      await t.pumpAndSettle();
      final patch = a.calls.singleWhere((c) => c.method == 'PATCH');
      expect(patch.data['setupUrl'], 'https://setup.example.com/start');
      expect(patch.data['setupDescription'], 'Connect your account');
    });

    testWidgets('a bad URL blocks the save with the Web message', (t) async {
      final (a, _) = await pump(t, app: base);
      await t.ensureVisible(find.byKey(const ValueKey('app-setup-required')));
      await t.tap(find.byKey(const ValueKey('app-setup-required')));
      await t.pumpAndSettle();
      await t.enterText(
        find.byKey(const ValueKey('app-setup-url')),
        'http://insecure.example.com/setup',
      );
      await t.tap(find.byKey(const ValueKey('connected-app-editor-submit')));
      await t.pumpAndSettle();
      expect(
        find.text(
          'Enter an HTTPS setup URL (loopback HTTP is allowed for local development).',
        ),
        findsOneWidget,
      );
      expect(a.calls.where((c) => c.method == 'PATCH'), isEmpty);
    });

    testWidgets('turning it off clears the setup page on the server', (
      t,
    ) async {
      final (a, _) = await pump(
        t,
        app: {
          ...base,
          'setupUrl': 'https://setup.example.com/start',
          'setupDescription': 'x',
        },
      );
      expect(find.text('Setup required'), findsOneWidget);
      await t.ensureVisible(find.byKey(const ValueKey('app-setup-required')));
      await t.tap(find.byKey(const ValueKey('app-setup-required')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('connected-app-editor-submit')));
      await t.pumpAndSettle();
      final patch = a.calls.singleWhere((c) => c.method == 'PATCH');
      expect(patch.data.containsKey('setupUrl'), isTrue);
      expect(patch.data['setupUrl'], isNull);
      expect(patch.data['setupDescription'], isNull);
    });

    testWidgets('registering without a setup page sends no setup fields', (
      t,
    ) async {
      final (a, _) = await pump(t);
      await t.enterText(
        find.byKey(const ValueKey('connected-app-name')),
        'New app',
      );
      await t.tap(find.byKey(const ValueKey('connected-app-editor-submit')));
      await t.pumpAndSettle();
      final post = a.calls.singleWhere(
        (c) => c.method == 'POST' && c.path == '/integrations/clients',
      );
      expect(post.data.containsKey('setupUrl'), isFalse);
      expect(post.data.containsKey('setupDescription'), isFalse);
    });
  });

  group('action cards', () {
    RaftMessage card(
      String type, {
      String state = 'prepared',
      Map<String, dynamic> action = const {},
      Map<String, dynamic>? result,
    }) => RaftMessage({
      'id': 'm1',
      'channelId': 'c1',
      'content': 'Action',
      'actionMetadata': {
        'kind': 'action-card',
        'sourceServerId': 's1',
        'state': state,
        'confirmationVersion': 7,
        'executedByUserName': ?(state == 'executed' ? 'Alice' : null),
        'result': ?result,
        'action': {'type': type, ...action},
      },
    });

    Future<void> show(WidgetTester t, RaftMessage message) async {
      final (w, _) = (await t.runAsync(() => integFixture('owner')))!;
      addTearDown(w.dispose);
      w.channel = RaftChannel({'id': 'c1', 'name': 'test', 'joined': true});
      w.channels = [w.channel!];
      await t.pumpWidget(
        integHost(MessageActionCard(controller: w, message: message)),
      );
      await t.pumpAndSettle();
    }

    testWidgets('the install card says the App needs setup', (t) async {
      await show(
        t,
        card(
          'integration:install_marketplace_app',
          action: {
            'clientName': 'Acme',
            'agentName': 'bot',
            'scopes': ['openid'],
            'setupUrl': 'https://setup.example.com/start',
            'setupDescription': 'Connect your Acme account.',
          },
        ),
      );
      expect(find.text('Setup required'), findsOneWidget);
      expect(find.text('Connect your Acme account.'), findsOneWidget);
    });

    testWidgets('an install card with no setup page has no setup notice', (
      t,
    ) async {
      await show(
        t,
        card(
          'integration:install_marketplace_app',
          action: {
            'clientName': 'Acme',
            'agentName': 'bot',
            'scopes': ['openid'],
          },
        ),
      );
      expect(find.text('Setup required'), findsNothing);
    });

    testWidgets('register and update cards list the setup page', (t) async {
      for (final type in [
        'integration:register_app',
        'integration:update_app_registration',
      ]) {
        await show(
          t,
          card(
            type,
            action: {
              'clientKey': 'acme',
              'returnUrl': 'https://example.com/cb',
              'name': 'Acme',
              'setupUrl': 'https://setup.example.com/start',
              'setupDescription': 'Connect your account.',
            },
          ),
        );
        expect(
          find.textContaining('Setup page URL:'),
          findsOneWidget,
          reason: type,
        );
        expect(
          find.textContaining('https://setup.example.com/start'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Configuration instructions:'),
          findsOneWidget,
        );
        await t.pumpWidget(const SizedBox());
      }
    });

    testWidgets('an installed App offers Continue setup for a safe URL only', (
      t,
    ) async {
      Map<String, dynamic> installed(String? url) => {
        'kind': 'marketplace-app-installation',
        'clientName': 'Acme',
        'setupUrl': ?url,
      };
      await show(
        t,
        card(
          'integration:install_marketplace_app',
          state: 'executed',
          action: {'clientName': 'Acme', 'agentName': 'bot', 'scopes': []},
          result: installed('https://setup.example.com/start'),
        ),
      );
      expect(
        find.byKey(const ValueKey('action-card-continue-setup')),
        findsOneWidget,
      );
      await t.pumpWidget(const SizedBox());
      for (final url in [
        null,
        'http://evil.example/x',
        'javascript:alert(1)',
      ]) {
        await show(
          t,
          card(
            'integration:install_marketplace_app',
            state: 'executed',
            action: {'clientName': 'Acme', 'agentName': 'bot', 'scopes': []},
            result: installed(url),
          ),
        );
        expect(
          find.byKey(const ValueKey('action-card-continue-setup')),
          findsNothing,
          reason: '$url',
        );
        await t.pumpWidget(const SizedBox());
      }
    });
  });
}
