// Settings > Plan & Billing at Web v1.24 (BillingTabContent, PlanSection,
// PlanSectionContent, DowngradeWarningCard): the app only SHOWS the plan,
// seats, usage and payment-method status; every paid or billing-changing
// button opens the Web Plan & Billing page (Kevin 2654e77c). No checkout,
// seat, portal or cancel request is ever sent from here.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/billing_view.dart';
import 'package:raft_flutter/platform/web_billing.dart';
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

  List<RequestOptions> gets(String path) =>
      calls.where((c) => c.method == 'GET' && c.path == path).toList();

  /// Every request that could change billing: any non-GET to /billing or the
  /// seat/usage routes.
  List<RequestOptions> get billingWrites => calls
      .where(
        (c) =>
            c.method != 'GET' &&
            (c.path.startsWith('/billing') ||
                c.path.startsWith('/servers/s1/seat')),
      )
      .toList();
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

Widget _host(Widget child, {double width = 1280, bool dark = false}) =>
    MediaQuery(
      data: MediaQueryData(size: Size(width, 2400)),
      child: MaterialApp(
        theme: dark ? raftTheme(dark: true) : raftTheme(),
        builder: (context, child) => RaftToastHost(child: child!),
        home: Scaffold(
          body: ListView(padding: const EdgeInsets.all(20), children: [child]),
        ),
      ),
    );

void _surface(WidgetTester t, [double width = 1280]) {
  t.view.physicalSize = Size(width, 2400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

final _now = DateTime.utc(2026, 6, 19, 12, 30);

Map<String, dynamic> _free({bool manage = true, bool stripe = true}) => {
  'plan': 'free',
  'displayName': 'Free',
  'source': 'server',
  'capacity': {'maxHumans': 1, 'maxAgents': 2, 'maxUniversalSeats': -1},
  'usage': {'humans': 2, 'agents': 2, 'universalSeats': 2.2},
  'provisioned': {'humans': 1, 'agents': 2, 'proPackQuantity': 0},
  'fileUploadQuota': {
    'month': '2026-06',
    'limited': true,
    'limitBytes': 524288000,
    'usedBytes': 188743680,
    'remainingBytes': 335544320,
  },
  'price': null,
  'subscription': null,
  'stripeConfigured': stripe,
  'permissions': {'canReadBillingSummary': false, 'canManageBilling': manage},
};

Map<String, dynamic> _pro({
  bool cancelAtPeriodEnd = false,
  String status = 'active',
  bool manage = true,
  num universal = 1.5,
}) => {
  'plan': 'pro',
  'displayName': 'Pro',
  'source': 'subscription',
  'capacity': {'maxHumans': -1, 'maxAgents': -1, 'maxUniversalSeats': 3},
  'usage': {'humans': 1, 'agents': 5, 'universalSeats': universal},
  'provisioned': {'humans': 3, 'agents': 30, 'proPackQuantity': 3},
  'price': {
    'billingInterval': 'annual',
    'monthlyUsd': 26.4,
    'annualUsd': 316.8,
  },
  'subscription': {
    'status': status,
    'billingInterval': 'annual',
    'currentPeriodEnd': '2026-12-20T12:00:00.000Z',
    'cancelAtPeriodEnd': cancelAtPeriodEnd,
  },
  'stripeConfigured': true,
  'permissions': {'canReadBillingSummary': false, 'canManageBilling': manage},
};

Map<String, dynamic> _prepaid({required bool inGrace, int daysLeft = 3}) {
  final ends = _now.add(Duration(days: inGrace ? -2 : daysLeft));
  return {
    ..._pro(),
    'source': 'prepaid',
    'subscription': null,
    'prepaid': {
      'endsAt': ends.toIso8601String(),
      'graceEndsAt': ends.add(const Duration(days: 7)).toIso8601String(),
      'inGrace': inGrace,
      'seatQuantity': 3,
    },
  };
}

void main() {
  late List<Uri> opened;
  final savedLauncher = webBillingLauncher;
  setUp(() {
    opened = [];
    webBillingLauncher = (uri) async {
      opened.add(uri);
      return true;
    };
  });
  tearDown(() => webBillingLauncher = savedLauncher);

  Uri web(WorkspaceController w, {String? gate}) => webBillingUri(
    coordinator: w.client.origin,
    slug: w.server?.string('slug'),
    gate: gate,
  );

  Future<(WorkspaceController, _Adapter)> mount(
    WidgetTester t,
    Map<String, dynamic>? billing, {
    String role = 'owner',
    double width = 1280,
    bool dark = false,
    Map<String, Object?> server = const {},
    Map<String, Object?> paymentMethod = const {'paymentMethod': null},
    int paymentStatus = 200,
    bool prepaidFlag = true,
    bool settle = true,
  }) async {
    final (w, a) = (await t.runAsync(() => _fixture(role)))!;
    addTearDown(w.dispose);
    if (billing != null) {
      a.routes['GET /billing/subscription'] = (_) => billing;
    } else {
      a.statuses['GET /billing/subscription'] = 500;
      a.routes['GET /billing/subscription'] = (_) => {'error': 'down'};
    }
    a.routes['GET /servers/s1/usage'] = (_) => {
      'agents': 2,
      'machines': 1,
      'channels': 4,
    };
    a.routes['GET /billing/payment-method'] = (_) => paymentMethod;
    a.statuses['GET /billing/payment-method'] = paymentStatus;
    a.routes['POST /feature-flags/evaluate'] = (_) => {
      'evaluations': [
        {'key': 'pro_prepaid', 'enabled': prepaidFlag},
      ],
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
    _surface(t, width);
    await t.pumpWidget(
      _host(
        BillingView(controller: w, now: () => _now),
        width: width,
        dark: dark,
      ),
    );
    if (settle) await t.pumpAndSettle();
    return (w, a);
  }

  Finder key(String k) => find.byKey(ValueKey(k));

  group('Free', () {
    testWidgets('owner: plan, usage and the upgrade card', (t) async {
      final (w, a) = await mount(t, _free());
      expect(key('billing-overview'), findsOneWidget);
      expect(find.text('Free'), findsWidgets);
      expect(
        find.text(
          'Messages from the last 30 days · 100 MB of file uploads a month',
        ),
        findsOneWidget,
      );
      expect(find.text('Usage'), findsOneWidget);
      expect(find.text('File uploads this month'), findsOneWidget);
      expect(find.text('180 MB of 500 MB used · resets Jul 1'), findsOneWidget);
      expect(find.text('Message history'), findsOneWidget);
      expect(find.text('2 people · 2 agents'), findsOneWidget);
      expect(key('billing-upgrade-card'), findsOneWidget);
      expect(
        find.text(
          r'$10 per seat a month, or $8.80 a month billed yearly. Each person takes 1 seat and each agent 0.1; this server needs 3 seats today.',
        ),
        findsOneWidget,
      );
      expect(find.text('Unlimited message history'), findsOneWidget);
      expect(find.text('Use external channels'), findsOneWidget);
      expect(find.text('Upgrade to Pro'), findsNWidgets(2));
      expect(key('billing-details-card'), findsNothing);
      expect(key('billing-cancel-card'), findsNothing);
      expect(a.gets('/billing/payment-method'), isEmpty);

      await t.tap(key('billing-upgrade'));
      await t.pumpAndSettle();
      expect(opened, [web(w, gate: WebBillingGate.general)]);
      expect(a.billingWrites, isEmpty);
    });

    testWidgets('non-owner admin: asks an owner, which opens the Web page', (
      t,
    ) async {
      final (w, a) = await mount(t, _free(manage: false), role: 'admin');
      expect(find.text('Ask an owner to upgrade'), findsOneWidget);
      expect(find.text('Upgrade to Pro'), findsOneWidget);
      await t.tap(key('billing-upgrade'));
      await t.pumpAndSettle();
      expect(opened, [web(w, gate: WebBillingGate.general)]);
      expect(a.billingWrites, isEmpty);
    });

    testWidgets('Compare plans leaves for the pricing page', (t) async {
      await mount(t, _free());
      await t.tap(key('billing-compare-plans'));
      await t.pumpAndSettle();
      expect(opened.single.toString(), 'https://raft.build/pricing');
    });

    testWidgets('a browser that will not open says so, not silence', (t) async {
      await mount(t, _free());
      webBillingLauncher = (uri) async => false;
      await t.tap(key('billing-upgrade'));
      await t.pump();
      expect(find.text('Could not open this address.'), findsOneWidget);
      await t.pumpAndSettle(const Duration(seconds: 6));
    });

    testWidgets('the tap opens the browser with no request first', (t) async {
      final (_, a) = await mount(t, _free());
      final before = a.calls.length;
      await t.tap(key('billing-upgrade'));
      expect(opened, hasLength(1));
      expect(a.calls.length, before);
    });

    testWidgets('without Stripe the upgrade button is off and says why', (
      t,
    ) async {
      await mount(t, _free(stripe: false));
      expect(find.text('Paid plans are not available yet.'), findsOneWidget);
      await t.tap(key('billing-upgrade'), warnIfMissed: false);
      await t.pumpAndSettle();
      expect(opened, isEmpty);
    });
  });

  group('Pro', () {
    testWidgets('owner: billing card with the card on file, seats, cancel', (
      t,
    ) async {
      final (w, a) = await mount(
        t,
        _pro(),
        paymentMethod: {
          'paymentMethod': {
            'type': 'card',
            'brand': 'visa',
            'last4': '4242',
            'expMonth': 12,
            'expYear': 2029,
          },
        },
      );
      expect(
        find.text('\$316.80 a year · 3 seats · Renews Dec 20, 2026'),
        findsOneWidget,
      );
      expect(find.text('Seats'), findsWidgets);
      expect(find.text('1.5 of 3 used'), findsOneWidget);
      expect(find.text('1 · 1 seat'), findsOneWidget);
      expect(find.text('5 · 0.5 seats'), findsOneWidget);
      expect(key('billing-details-card'), findsOneWidget);
      expect(find.text('Yearly'), findsOneWidget);
      expect(find.text('Visa ending in 4242 · expires 12/29'), findsOneWidget);
      expect(
        find.text('Invoices, receipts and the payment method are in Stripe.'),
        findsOneWidget,
      );
      expect(key('billing-cancel-card'), findsOneWidget);
      expect(a.gets('/billing/payment-method'), hasLength(1));

      for (final k in [
        'billing-add-seats',
        'billing-manage-stripe',
        'billing-manage-seats',
        'billing-cancel',
      ]) {
        opened.clear();
        await t.ensureVisible(key(k));
        await t.tap(key(k));
        await t.pumpAndSettle();
        expect(opened, [web(w)], reason: k);
      }
      expect(a.billingWrites, isEmpty);
    });

    testWidgets('no spare seat: no Manage seats link', (t) async {
      await mount(t, _pro(universal: 3));
      expect(key('billing-manage-seats'), findsNothing);
      expect(key('billing-add-seats'), findsOneWidget);
    });

    testWidgets('payment method: bank, none, other', (t) async {
      await mount(
        t,
        _pro(),
        paymentMethod: {
          'paymentMethod': {'type': 'bank_account', 'last4': '6789'},
        },
      );
      expect(find.text('Bank account ending in 6789'), findsOneWidget);
    });

    testWidgets('payment method: none on file', (t) async {
      await mount(t, _pro());
      expect(find.text('None on file'), findsOneWidget);
    });

    testWidgets('payment method: another kind is just saved in Stripe', (
      t,
    ) async {
      await mount(
        t,
        _pro(),
        paymentMethod: {
          'paymentMethod': {'type': 'link'},
        },
      );
      expect(find.text('Saved in Stripe'), findsOneWidget);
    });

    testWidgets('payment method: a failed read leaves the row out', (t) async {
      await mount(t, _pro(), paymentStatus: 503);
      expect(key('billing-payment-method'), findsNothing);
      expect(key('billing-details-card'), findsOneWidget);
      expect(find.text('Billed'), findsOneWidget);
    });

    testWidgets('payment method loads for owners only', (t) async {
      final (_, a) = await mount(t, _pro(manage: false), role: 'admin');
      expect(a.gets('/billing/payment-method'), isEmpty);
      expect(key('billing-payment-method'), findsNothing);
      expect(
        find.text('Only server owners can change billing or see invoices.'),
        findsOneWidget,
      );
      expect(key('billing-cancel-card'), findsNothing);
      expect(key('billing-add-seats'), findsNothing);
      expect(key('billing-manage-stripe'), findsNothing);
    });

    testWidgets('past due: banner with Update payment method', (t) async {
      final (w, a) = await mount(t, _pro(status: 'past_due'));
      expect(key('billing-past-due'), findsOneWidget);
      expect(find.text('Payment failed'), findsWidgets);
      expect(key('billing-add-seats'), findsNothing);
      expect(key('billing-keep-pro'), findsNothing);
      await t.tap(key('billing-past-due-action'));
      await t.pumpAndSettle();
      expect(opened, [web(w)]);
      expect(a.billingWrites, isEmpty);
    });

    testWidgets('past due, for a member: no button', (t) async {
      await mount(t, _pro(status: 'past_due', manage: false), role: 'admin');
      expect(key('billing-past-due'), findsOneWidget);
      expect(key('billing-past-due-action'), findsNothing);
      expect(
        find.textContaining('An owner needs to update the payment method'),
        findsOneWidget,
      );
    });

    testWidgets('ending: banner with Keep Pro, no seats, no cancel', (t) async {
      final (w, a) = await mount(t, _pro(cancelAtPeriodEnd: true));
      expect(key('billing-ending'), findsOneWidget);
      expect(find.text('Pro ends on Dec 20, 2026'), findsOneWidget);
      expect(find.text('Last day of Pro'), findsOneWidget);
      expect(key('billing-add-seats'), findsNothing);
      expect(key('billing-cancel-card'), findsNothing);
      await t.tap(key('billing-keep-pro'));
      await t.pumpAndSettle();
      expect(opened, [web(w)]);
      expect(a.billingWrites, isEmpty);
    });

    testWidgets('prepaid ending: banner, status and Renew', (t) async {
      final (w, a) = await mount(t, _prepaid(inGrace: false));
      expect(key('billing-prepaid-ending'), findsOneWidget);
      expect(find.textContaining('Pro ends on '), findsWidgets);
      expect(
        find.textContaining('Paid once with Alipay · 3 seats · until '),
        findsOneWidget,
      );
      await t.tap(key('billing-prepaid-banner-renew'));
      await t.pumpAndSettle();
      expect(opened, [web(w)]);
      expect(a.billingWrites, isEmpty);
    });

    testWidgets('prepaid grace: warning banner', (t) async {
      await mount(t, _prepaid(inGrace: true));
      expect(key('billing-prepaid-grace'), findsOneWidget);
      expect(find.textContaining('Prepaid Pro ended on '), findsOneWidget);
      expect(find.textContaining('Ended '), findsOneWidget);
    });

    testWidgets('prepaid without the renewal flag: nothing to press', (
      t,
    ) async {
      await mount(t, _prepaid(inGrace: false), prepaidFlag: false);
      expect(key('billing-prepaid-ending'), findsOneWidget);
      expect(key('billing-prepaid-banner-renew'), findsNothing);
      expect(
        find.text("Prepaid Pro doesn't renew on its own."),
        findsOneWidget,
      );
    });
  });

  group('states', () {
    testWidgets('load failed: banner, Try again reads again', (t) async {
      final (_, a) = await mount(t, null);
      expect(key('billing-load-failed'), findsOneWidget);
      expect(find.text("Couldn't load billing"), findsOneWidget);
      a.statuses.remove('GET /billing/subscription');
      a.routes['GET /billing/subscription'] = (_) => _free();
      await t.tap(key('billing-retry'));
      await t.pumpAndSettle();
      expect(key('billing-load-failed'), findsNothing);
      expect(key('billing-upgrade-card'), findsOneWidget);
    });

    testWidgets('downgrade warning: owner is told upgrading brings it back', (
      t,
    ) async {
      await mount(
        t,
        _free(),
        server: {'planDowngradedAt': '2026-06-15T12:30:00.000Z'},
      );
      expect(find.text('Test workspace is on Free now'), findsOneWidget);
      expect(
        find.text(
          'Messages over 30 days old are hidden. Pro features are off. Upgrade to bring them back.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('downgrade warning: a member is not asked to pay', (t) async {
      await mount(
        t,
        _free(manage: false),
        role: 'admin',
        server: {'planDowngradedAt': '2026-06-15T12:30:00.000Z'},
      );
      expect(
        find.text(
          'Messages over 30 days old are hidden. Pro features are off.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('downgrade warning ends after a week', (t) async {
      await mount(
        t,
        _free(),
        server: {'planDowngradedAt': '2026-06-11T12:30:00.000Z'},
      );
      expect(find.text('Test workspace is on Free now'), findsNothing);
    });

    testWidgets('cold load is the two-card skeleton; a revisit is final', (
      t,
    ) async {
      final (w, a) = (await t.runAsync(() => _fixture('owner')))!;
      addTearDown(w.dispose);
      a.routes['GET /billing/subscription'] = (_) => _free();
      a.routes['GET /servers/s1/usage'] = (_) => {'agents': 2};
      a.gate = Completer<void>();
      _surface(t);
      await t.pumpWidget(_host(BillingView(controller: w, now: () => _now)));
      expect(key('billing-overview-loading'), findsOneWidget);
      a.gate!.complete();
      a.gate = null;
      await t.pumpAndSettle();
      expect(key('billing-overview-loading'), findsNothing);
      final plan = key('billing-current-plan-card');
      final rect = t.getRect(plan);
      await t.pumpWidget(_host(const SizedBox()));
      await t.pumpAndSettle();
      a.gate = Completer<void>();
      await t.pumpWidget(_host(BillingView(controller: w, now: () => _now)));
      expect(key('billing-overview-loading'), findsNothing);
      expect(t.getRect(plan), rect);
      a.gate!.complete();
      a.gate = null;
      await t.pumpAndSettle();
      expect(t.getRect(plan), rect);
    });

    testWidgets('reloads when the plan revision bumps', (t) async {
      final (w, a) = await mount(t, _free(), width: 600);
      int reads() => a.gets('/billing/subscription').length;
      final before = reads();
      w.planRevision++;
      w.notifyListeners();
      await t.pumpAndSettle();
      expect(reads(), before + 1);
    });

    testWidgets('a viewer without viewBilling sees the restricted card', (
      t,
    ) async {
      await mount(t, _free(manage: false), role: 'member');
      expect(
        find.text('Only server owners and admins can view billing.'),
        findsOneWidget,
      );
      expect(key('billing-overview'), findsNothing);
    });

    for (final dark in [false, true]) {
      testWidgets('renders in ${dark ? 'dark' : 'light'}', (t) async {
        await mount(t, _pro(), dark: dark);
        expect(t.takeException(), isNull);
        expect(key('billing-details-card'), findsOneWidget);
      });
    }
  });

  // Evidence render (not a pixel gate): RAFT_BILLING_CAPTURE_DIR=<dir> writes
  // the Free and Pro pages, light and dark, as PNGs with the bundled fonts.
  final captureDir = Platform.environment['RAFT_BILLING_CAPTURE_DIR'];
  group('capture', () {
    Map<String, dynamic> devFree() => {
      ..._free(),
      'usage': {'humans': 1, 'agents': 0, 'universalSeats': 0},
      'fileUploadQuota': {
        'month': '2026-11',
        'limited': true,
        'limitBytes': 104857600,
        'usedBytes': 0,
        'remainingBytes': 104857600,
      },
      'stripeConfigured': false,
    };
    Map<String, dynamic> devPro() => {
      ..._pro(),
      'source': 'server',
      'subscription': null,
      'price': null,
      'capacity': {'maxHumans': -1, 'maxAgents': -1, 'maxUniversalSeats': 1},
      'usage': {'humans': 6, 'agents': 4, 'universalSeats': 6.4},
      'provisioned': {'humans': 0, 'agents': 0, 'proPackQuantity': 0},
      'stripeConfigured': false,
    };
    final cases = {
      'free': devFree(),
      'pro': devPro(),
      'pro-subscription': _pro(),
    };
    for (final entry in cases.entries) {
      for (final dark in [false, true]) {
        testWidgets('${entry.key} ${dark ? 'dark' : 'light'}', (t) async {
          await t.runAsync(() async {
            for (final family in ['SpaceGrotesk', 'SpaceMono', 'Inter']) {
              final data = await rootBundle.load(
                'packages/raft_ui/assets/fonts/$family.ttf',
              );
              await (FontLoader(
                'packages/raft_ui/$family',
              )..addFont(Future.value(data))).load();
            }
          });
          await mount(
            t,
            entry.value,
            width: 976,
            dark: dark,
            paymentMethod: {
              'paymentMethod': {
                'type': 'card',
                'brand': 'visa',
                'last4': '4242',
                'expMonth': 12,
                'expYear': 2029,
              },
            },
          );
          final boundary = t.renderObject(
            find.byType(RepaintBoundary).first,
          ) as RenderRepaintBoundary;
          await t.runAsync(() async {
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            File(
              '$captureDir/flutter-${entry.key}-${dark ? 'dark' : 'light'}.png',
            ).writeAsBytesSync(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }, skip: captureDir == null);
      }
    }
  });
}
