// Settings > Plan & Billing (PlanSection) and Applications
// (IntegrationsSection): data lifecycle, gates and mutations against the
// mounted Web endpoints. Checkout / portal URLs never leave the test (the
// external opener is substituted); no real purchase is possible.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/billing_view.dart';
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
    theme: raftTheme(RaftFamily.elegant),
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

final _now = DateTime.utc(2026, 6, 19, 12, 30);

Map<String, dynamic> _free({bool manage = true, bool stripe = true}) => {
  'plan': 'free',
  'displayName': 'Free',
  'capacity': {'maxHumans': 1, 'maxAgents': 2, 'maxUniversalSeats': -1},
  'usage': {'humans': 2, 'agents': 2, 'universalSeats': 0},
  'provisioned': {'humans': 1, 'agents': 2, 'proPackQuantity': 0},
  'fileUploadQuota': {
    'limited': true,
    'limitBytes': 524288000,
    'usedBytes': 188743680,
  },
  'price': null,
  'subscription': null,
  'stripeConfigured': stripe,
  'permissions': {'canReadBillingSummary': true, 'canManageBilling': manage},
};

Map<String, dynamic> _pro({
  bool cancelAtPeriodEnd = false,
  String status = 'active',
}) => {
  'plan': 'pro',
  'displayName': 'Pro',
  'capacity': {'maxHumans': -1, 'maxAgents': -1, 'maxUniversalSeats': 3},
  'usage': {'humans': 2, 'agents': 5, 'universalSeats': 2.5},
  'provisioned': {'humans': 3, 'agents': 30, 'proPackQuantity': 3},
  'price': {
    'billingInterval': 'annual',
    'monthlyUsd': 26.4,
    'annualUsd': 316.8,
  },
  'subscription': {
    'status': status,
    'billingInterval': 'annual',
    'cancelAtPeriodEnd': cancelAtPeriodEnd,
  },
  'stripeConfigured': true,
  'permissions': {'canReadBillingSummary': true, 'canManageBilling': true},
};

void main() {
  group('Plan & Billing', () {
    Future<(WorkspaceController, _Adapter, List<Uri>)> mount(
      WidgetTester t,
      Map<String, dynamic> billing, {
      String role = 'owner',
      double width = 1280,
      Map<String, Object?> server = const {},
    }) async {
      final (w, a) = (await t.runAsync(() => _fixture(role)))!;
      addTearDown(w.dispose);
      a.routes['GET /billing/subscription'] = (_) => billing;
      a.routes['GET /servers/s1/usage'] = (_) => {
        'agents': 2,
        'machines': 1,
        'channels': 4,
      };
      if (server.isNotEmpty) {
        w.server = RaftRecord({
          'id': 's1',
          'name': 'Test workspace',
          'slug': 'test',
          'plan': 'free',
          'role': role,
          ...server,
        });
        w.servers = [w.server!];
      }
      final opened = <Uri>[];
      _surface(t, width);
      await t.pumpWidget(
        _host(
          BillingView(
            controller: w,
            now: () => _now,
            openExternal: (uri) async {
              opened.add(uri);
              return true;
            },
          ),
          width: width,
        ),
      );
      await t.pumpAndSettle();
      return (w, a, opened);
    }

    testWidgets(
      'Free plan: trial notice, features, usage and checkout summary',
      (t) async {
        await mount(t, _free());
        expect(find.text('CURRENT PLAN'), findsOneWidget);
        expect(find.text('Final Trial Period'), findsOneWidget);
        expect(
          find.textContaining('remains active through Jun 22, 2026'),
          findsOneWidget,
        );
        expect(find.text('Start building with agents.'), findsOneWidget);
        expect(find.text('Unlimited message history'), findsOneWidget);
        expect(find.text('180 MB / 500 MB this month'), findsOneWidget);
        expect(find.text('30 days'), findsOneWidget);
        expect(find.text('UPGRADE TO PRO'), findsOneWidget);
        expect(find.text(r'$105.60 / year'), findsOneWidget);
        expect(find.text(r'$120 / year'), findsOneWidget);
        expect(find.text('up to 1 Human'), findsOneWidget);
        expect(find.text('or 10 Agents'), findsOneWidget);
        // Monthly: the struck annual original disappears.
        await t.tap(find.text('Monthly'));
        await t.pumpAndSettle();
        expect(find.text(r'$10 / month'), findsOneWidget);
        expect(find.text(r'$120 / year'), findsNothing);
        // Seat input: 3 seats → 30 agents, $30 / month.
        await t.enterText(
          find.byKey(const ValueKey('billing-seat-input')),
          '3',
        );
        await t.pumpAndSettle();
        expect(find.text('or 30 Agents'), findsOneWidget);
        expect(find.text(r'$30 / month'), findsOneWidget);
        // Below coverage is clamped on blur (Web commitSeatInput).
        await t.enterText(
          find.byKey(const ValueKey('billing-seat-input')),
          '0',
        );
        await t.pumpAndSettle();
        expect(
          find.text('Enter at least 1 seats to cover current server usage.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('checkout confirms, posts the Web payload and opens Stripe', (
      t,
    ) async {
      final (_, a, opened) = await mount(t, _free());
      a.routes['POST /billing/checkout'] = (_) => {
        'url': 'https://checkout.stripe.invalid/session',
      };
      await t.tap(find.byKey(const ValueKey('billing-upgrade')));
      await t.pumpAndSettle();
      expect(find.text('CONFIRM PRO CHECKOUT'), findsOneWidget);
      expect(find.text(r'Total: $105.60 / year'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('billing-confirm')));
      await t.pumpAndSettle();
      final body = a.posts('/billing/checkout').single.data as Map;
      expect(body['targetPlan'], 'pro');
      expect(body['billingInterval'], 'annual');
      expect(body['seatQuantity'], 1);
      expect(body['humanSeatQuantity'], 1);
      expect(body['agentSeatQuantity'], 10);
      expect(body['successUrl'], endsWith('/s/test/settings/billing'));
      expect(opened.single.host, 'checkout.stripe.invalid');
    });

    testWidgets('a canceled confirm never posts', (t) async {
      final (_, a, opened) = await mount(t, _free());
      await t.tap(find.byKey(const ValueKey('billing-upgrade')));
      await t.pumpAndSettle();
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(a.posts('/billing/checkout'), isEmpty);
      expect(opened, isEmpty);
    });

    testWidgets('Pro: seat usage, portal, seat update with promotion preview', (
      t,
    ) async {
      final (_, a, opened) = await mount(t, _pro());
      expect(
        find.text(
          '3 seats purchased. Each human uses 1 seat; each agent uses 0.1 seat.',
        ),
        findsOneWidget,
      );
      expect(find.text('2.5 / 3 used'), findsOneWidget);
      expect(find.text('MANAGE SEATS'), findsOneWidget);
      expect(find.text('Billing interval: Yearly'), findsOneWidget);
      expect(find.text(r'$316.80 / year'), findsWidgets);
      a.routes['POST /billing/portal'] = (_) => {
        'url': 'https://billing.stripe.invalid/p',
      };
      await t.tap(find.byKey(const ValueKey('billing-portal')));
      await t.pumpAndSettle();
      expect(opened.single.host, 'billing.stripe.invalid');
      // No change: the review button stays disabled.
      await t.tap(find.byKey(const ValueKey('billing-update-seats')));
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('billing-confirm-dialog')),
        findsNothing,
      );
      await t.enterText(find.byKey(const ValueKey('billing-seat-input')), '4');
      await t.pumpAndSettle();
      expect(find.text('ADDED CAPACITY'), findsNothing);
      expect(find.text('Added capacity'), findsOneWidget);
      await t.enterText(
        find.byKey(const ValueKey('billing-promotion-input')),
        'spring',
      );
      await t.pumpAndSettle();
      a.routes['POST /billing/seat-pack-quantity/preview'] = (_) => {
        'status': 'preview',
        'currency': 'usd',
        'prorationAmount': 5280,
        'recurringAmount': 42240,
        'discountAmount': 1000,
        'promotion': {'code': 'SPRING'},
        'previewToken': 'preview-token',
      };
      a.routes['POST /billing/seat-pack-quantity'] = (_) => {
        'status': 'updated',
      };
      await t.tap(find.byKey(const ValueKey('billing-update-seats')));
      await t.pumpAndSettle();
      final preview =
          a.posts('/billing/seat-pack-quantity/preview').single.data as Map;
      expect(preview['promotionCode'], 'spring');
      expect(preview['seatQuantity'], 4);
      expect(find.text('Applied promotion: SPRING'), findsOneWidget);
      expect(find.text(r'Estimated prorated charge: $52.80'), findsOneWidget);
      expect(find.text(r'Discount: -$10.00'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('billing-confirm')));
      await t.pumpAndSettle();
      final update = a.posts('/billing/seat-pack-quantity').single.data as Map;
      expect(update['previewToken'], 'preview-token');
      expect(update['agentSeatQuantity'], 40);
      expect(
        find.text(
          'Seat update confirmed. Capacity has been refreshed from Stripe.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('cancel subscription posts after the warning confirm', (
      t,
    ) async {
      final (_, a, _) = await mount(t, _pro());
      a.routes['POST /billing/cancel'] = (_) => {'ok': true};
      await t.tap(find.byKey(const ValueKey('billing-cancel')));
      await t.pumpAndSettle();
      expect(find.text('CANCEL SUBSCRIPTION'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('billing-confirm')));
      await t.pumpAndSettle();
      expect(a.posts('/billing/cancel'), hasLength(1));
      expect(
        find.text(
          'Subscription cancellation scheduled for the end of the current billing period.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a scheduled cancellation offers reactivation', (t) async {
      await mount(t, _pro(cancelAtPeriodEnd: true));
      expect(find.byKey(const ValueKey('billing-cancel')), findsNothing);
      expect(find.text('Reactivate subscription'), findsOneWidget);
      expect(
        find.text('Billing interval: Yearly · cancellation scheduled'),
        findsOneWidget,
      );
    });

    testWidgets('without canManageBilling the controls are inert', (t) async {
      final (_, a, _) = await mount(t, _free(manage: false), role: 'admin');
      expect(find.text('Only server owners can change billing.'), findsWidgets);
      await t.tap(find.byKey(const ValueKey('billing-upgrade')));
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('billing-confirm-dialog')),
        findsNothing,
      );
      expect(
        a.calls.where(
          (c) => c.method == 'POST' && c.path.startsWith('/billing'),
        ),
        isEmpty,
      );
    });

    testWidgets('a downgrade inside the grace period matches the Web card', (
      t,
    ) async {
      // Web DowngradeWarningCard: planDowngradedAt plus the 7-day grace.
      // The frozen clock is 2026-06-19 12:30Z, so this stamp leaves 7 days.
      await mount(
        t,
        _free(),
        server: {'planDowngradedAt': '2026-06-19T12:30:00.000Z'},
      );
      expect(find.text('Plan Downgraded'), findsOneWidget);
      expect(
        find.text(
          '7 days remaining in grace period. All resources are within free limits.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('over limit'), findsNothing);
    });

    testWidgets('an ended grace period matches the Web card', (t) async {
      await mount(
        t,
        _free(),
        server: {'planDowngradedAt': '2026-06-11T12:30:00.000Z'},
      );
      expect(find.text('Grace Period Expired'), findsOneWidget);
      expect(
        find.text(
          'The grace period has ended. Excess agents have been stopped. Upgrade to reactivate them.',
        ),
        findsOneWidget,
      );
      expect(find.text('Plan Downgraded'), findsNothing);
    });

    test('past_due Pro keeps the active billing controls', () {
      final pastDue = billingControls('pro', 'past_due');
      expect(pastDue, billingControls('pro', 'active'));
      expect(pastDue.canOpenPortal, isTrue);
      expect(pastDue.canUpdatePacks, isTrue);
      expect(pastDue.canCheckout, isFalse);
    });

    testWidgets('past_due Pro opens the portal and seat update, not checkout', (
      t,
    ) async {
      final (_, a, opened) = await mount(t, _pro(status: 'past_due'));
      expect(find.byKey(const ValueKey('billing-upgrade')), findsNothing);
      expect(find.text('MANAGE SEATS'), findsOneWidget);
      a.routes['POST /billing/portal'] = (_) => {
        'url': 'https://billing.stripe.invalid/p',
      };
      await t.tap(find.byKey(const ValueKey('billing-portal')));
      await t.pumpAndSettle();
      expect(opened.single.host, 'billing.stripe.invalid');
      await t.enterText(find.byKey(const ValueKey('billing-seat-input')), '4');
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('billing-update-seats')));
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('billing-confirm-dialog')),
        findsOneWidget,
      );
      expect(a.posts('/billing/checkout'), isEmpty);
    });

    testWidgets('without Stripe the billing controls stay disabled', (t) async {
      final (_, a, _) = await mount(t, _free(stripe: false));
      expect(find.text('Paid plans are not available yet.'), findsWidgets);
      expect(find.text('Stripe billing is not configured'), findsNothing);
      await t.tap(find.byKey(const ValueKey('billing-upgrade')));
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('billing-confirm-dialog')),
        findsNothing,
      );
      expect(
        a.calls.where(
          (c) => c.method == 'POST' && c.path.startsWith('/billing'),
        ),
        isEmpty,
      );
    });

    testWidgets('cold load shows the skeleton; a revisit is final at once', (
      t,
    ) async {
      final (w, a) = (await t.runAsync(() => _fixture('owner')))!;
      addTearDown(w.dispose);
      a.routes['GET /billing/subscription'] = (_) => _free();
      a.routes['GET /servers/s1/usage'] = (_) => {'agents': 2};
      a.gate = Completer<void>();
      _surface(t);
      await t.pumpWidget(_host(BillingView(controller: w, now: () => _now)));
      expect(find.byType(RaftPlanBillingLoading), findsOneWidget);
      a.gate!.complete();
      a.gate = null;
      await t.pumpAndSettle();
      expect(find.text('Final Trial Period'), findsOneWidget);
      final plan = find.byKey(const ValueKey('billing-current-plan-card'));
      final rect = t.getRect(plan);
      _surface(t);
      await t.pumpWidget(_host(const SizedBox()));
      await t.pumpAndSettle();
      a.gate = Completer<void>();
      _surface(t);
      await t.pumpWidget(_host(BillingView(controller: w, now: () => _now)));
      // First frame: the accepted projection, no skeleton.
      expect(find.byType(RaftPlanBillingLoading), findsNothing);
      expect(t.getRect(plan), rect);
      a.gate!.complete();
      a.gate = null;
      await t.pumpAndSettle();
      expect(t.getRect(plan), rect);
    });

    testWidgets('phone-width billing reloads when the plan revision bumps', (
      t,
    ) async {
      final (w, a) = (await t.runAsync(() => _fixture('owner')))!;
      addTearDown(w.dispose);
      a.routes['GET /billing/subscription'] = (_) => _free();
      a.routes['GET /servers/s1/usage'] = (_) => {'agents': 2};
      _surface(t, 600);
      await t.pumpWidget(
        _host(BillingView(controller: w, now: () => _now), width: 600),
      );
      await t.pumpAndSettle();
      int reads() =>
          a.calls.where((c) => c.path == '/billing/subscription').length;
      final before = reads();
      w.planRevision++;
      w.notifyListeners();
      await t.pumpAndSettle();
      expect(reads(), before + 1);
    });

    testWidgets('mobile width stacks the features and the summary', (t) async {
      // 600 keeps the Ahem test font (1em glyphs) inside the 390px layout's
      // single-column rules without nowrap labels overflowing.
      await mount(t, _free(), width: 600);
      final summary = t.getRect(
        find.byKey(const ValueKey('billing-summary-card')),
      );
      final upgrade = t.getRect(find.byKey(const ValueKey('billing-upgrade')));
      expect(summary.top, greaterThan(upgrade.bottom));
      expect(
        t.getRect(find.text('Not included')).top,
        greaterThan(t.getRect(find.text('Included')).bottom),
      );
    });
  });

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
      expect(find.text('APPLICATIONS'), findsOneWidget);
      expect(find.text('Third-party apps for this server'), findsOneWidget);
      // Private-shared listings stay out of the marketplace; Installed holds
      // the installed listing plus the server-local client.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('connected-apps-tab-marketplace')),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
      expect(find.text('Shared App'), findsNothing);
      expect(find.text('100+ installs'), findsOneWidget);
      expect(find.text('Install'), findsOneWidget);
      expect(find.text('Installed'), findsNWidgets(2)); // tab + state badge
      expect(find.text('Developer Tools · by Raft Labs'), findsOneWidget);
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
      expect(
        find.text('No third-party marketplace apps match this view.'),
        findsOneWidget,
      );
    });

    testWidgets('listing detail installs to this server', (t) async {
      final (_, a) = await mount(t);
      a.routes['POST /integrations/marketplace/slack/install'] = (_) => {
        'ok': true,
      };
      await t.tap(find.byKey(const ValueKey('connected-app-slack')));
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('connected-app-detail')),
        findsOneWidget,
      );
      expect(find.text('APP DETAIL'), findsOneWidget);
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
      expect(find.text('INSTALLED APP'), findsOneWidget);
      expect(find.text('No data access'), findsOneWidget);
      await t.tap(find.text('Close').last);
      await t.pumpAndSettle();
      a.routes['DELETE /integrations/marketplace/github/install'] = (_) => {
        'ok': true,
      };
      await t.tap(find.byKey(const ValueKey('connected-app-action-github')));
      await t.pumpAndSettle();
      expect(find.text('UNINSTALL GITHUB ISSUES?'), findsOneWidget);
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
        a.calls.where((c) => c.method != 'GET' && !c.path.startsWith('/auth')),
        isEmpty,
      );
    });

    testWidgets('list layout shows summaries', (t) async {
      await mount(t);
      expect(find.text('Slack Bridge description'), findsNothing);
      await t.tap(find.byKey(const ValueKey('connected-apps-view-list')));
      await t.pumpAndSettle();
      expect(find.text('Slack Bridge description'), findsOneWidget);
    });
  });
}
