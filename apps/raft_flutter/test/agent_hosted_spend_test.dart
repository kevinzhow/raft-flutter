// Web HostedRuntimeSpendCard (Plan page: the server's cloud agent spend) and
// the v1.21.23 promotion code at checkout (`billing.checkoutPromotion*`).
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/billing_view.dart';
import 'package:raft_ui/raft_ui.dart';

class _Adapter implements HttpClientAdapter {
  final calls = <RequestOptions>[];
  final statuses = <String, int>{};
  final bodies = <String, Object?>{};
  final Map<String, FutureOr<dynamic> Function(RequestOptions)> routes = {};
  Completer<void>? gate;
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) async {
    calls.add(o);
    final key = '${o.method} ${o.path}';
    if (key == 'GET /billing/hosted-runtime-usage' && gate != null) {
      await gate!.future;
    }
    final route = routes[key];
    final data = route == null
        ? {'error': 'Unexpected endpoint'}
        : await route(o);
    return ResponseBody.fromString(
      jsonEncode(data),
      statuses[key] ?? (route == null ? 404 : 200),
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
  List<RequestOptions> reads(String path) =>
      calls.where((c) => c.method == 'GET' && c.path == path).toList();
  List<RequestOptions> posts(String path) =>
      calls.where((c) => c.method == 'POST' && c.path == path).toList();
}

Map<String, dynamic> _free({bool read = true}) => {
  'plan': 'free',
  'displayName': 'Free',
  'capacity': {'maxHumans': 1, 'maxAgents': 2, 'maxUniversalSeats': -1},
  'usage': {'humans': 2, 'agents': 2, 'universalSeats': 0},
  'provisioned': {'humans': 1, 'agents': 2, 'proPackQuantity': 0},
  'fileUploadQuota': {'limited': true, 'limitBytes': 524288000, 'usedBytes': 1},
  'price': null,
  'subscription': null,
  'stripeConfigured': true,
  'permissions': {'canReadBillingSummary': read, 'canManageBilling': true},
};

Map<String, dynamic> _spend({
  bool refusing = false,
  bool platform = false,
  num? limit = 5,
  bool estimated = false,
  List<Map<String, dynamic>>? periods,
  List<Map<String, dynamic>>? agents,
}) => {
  'currency': 'usd',
  'estimated': estimated,
  'today': {
    'day': '2026-06-19',
    'spentUsd': 1.25,
    'limitUsd': limit,
    'exempt': false,
    'platformLimitReached': platform,
    'refusing': refusing,
    'resetsAt': '2026-06-20T00:00:00.000Z',
  },
  'from': '2026-05-21',
  'to': '2026-06-19',
  'bucket': 'day',
  'totalUsd': 3.5,
  'periods':
      periods ??
      [
        {'start': '2026-06-19T00:00:00.000Z', 'totalUsd': 1.25, 'unpriced': []},
        {
          'start': '2026-06-18T00:00:00.000Z',
          'totalUsd': 2.25,
          'unpriced': ['tool.call'],
        },
      ],
  'agents':
      agents ??
      [
        {'agentId': 'a1', 'name': 'Cloud Bot', 'totalUsd': 3.0},
        {'agentId': null, 'name': null, 'totalUsd': 0.5},
      ],
};

final _now = DateTime.utc(2026, 6, 19, 12, 30);

void main() {
  late WorkspaceController w;
  late _Adapter a;

  /// [spend] answers the cloud spend read; [spendStatus] its HTTP status.
  Future<List<Uri>> mount(
    WidgetTester t,
    Map<String, dynamic> billing, {
    Object? spend,
    int spendStatus = 200,
    Completer<void>? gate,
  }) async {
    a = _Adapter()..gate = gate;
    a.routes['POST /auth/login'] = (_) => {
      'accessToken': 'fixture-only',
      'refreshToken': 'fixture-only',
      'user': {'id': 'alice'},
    };
    final client = (await t.runAsync(() async {
      final c = RaftClient(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
        transport: Dio()..httpClientAdapter = a,
      );
      await c.login('fixture', 'fixture');
      return c;
    }))!;
    client.selectServer('s1');
    w = WorkspaceController(client);
    w.server = RaftRecord({
      'id': 's1',
      'name': 'Test workspace',
      'slug': 'test',
      'plan': 'free',
      'role': 'owner',
    });
    w.servers = [w.server!];
    addTearDown(w.dispose);
    a.routes['GET /billing/subscription'] = (_) => billing;
    a.routes['GET /servers/s1/usage'] = (_) => {
      'agents': 2,
      'machines': 1,
      'channels': 4,
    };
    if (spend != null) {
      a.routes['GET /billing/hosted-runtime-usage'] = (_) => spend;
      a.statuses['GET /billing/hosted-runtime-usage'] = spendStatus;
    }
    t.view.physicalSize = const Size(1280, 3000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final opened = <Uri>[];
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              BillingView(
                controller: w,
                now: () => _now,
                openExternal: (uri) async {
                  opened.add(uri);
                  return true;
                },
              ),
            ],
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    return opened;
  }

  group('cloud agent spend card', () {
    testWidgets('shows today against the limit, 30 days and spend by agent', (
      t,
    ) async {
      await mount(t, _free(), spend: _spend());
      expect(find.text('Cloud agent spend'), findsOneWidget);
      expect(find.text(r'$1.25 of the $5.00 daily limit'), findsOneWidget);
      expect(find.textContaining('Resets '), findsOneWidget);
      expect(find.text(r'$3.50'), findsOneWidget);
      expect(find.text('Jun 19'), findsOneWidget);
      expect(find.text('Jun 18'), findsOneWidget);
      expect(find.text('Cloud Bot'), findsOneWidget);
      expect(find.text('Deleted agents'), findsOneWidget);
      expect(
        find.text('Some usage has no price and is not included.'),
        findsOneWidget,
      );
      expect(
        find.text(
          'In USD by UTC day, as reported by the cloud agent provider. For reference, not a bill.',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('hosted-runtime-spend-refusing')),
        findsNothing,
      );
      expect(a.reads('/billing/hosted-runtime-usage'), hasLength(1));
    });

    testWidgets('no daily limit, an estimate, and an empty month', (t) async {
      await mount(
        t,
        _free(),
        spend: _spend(limit: null, estimated: true, periods: [], agents: []),
      );
      expect(find.text(r'$1.25, no daily limit'), findsOneWidget);
      expect(find.text('No spend in the last 30 days'), findsOneWidget);
      expect(find.text('By agent'), findsNothing);
      expect(
        find.text(
          'Estimated, in USD by UTC day, as reported by the cloud agent provider. For reference, not a bill.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a refused day says whose limit it is', (t) async {
      await mount(t, _free(), spend: _spend(refusing: true));
      expect(
        find.textContaining(
          "This server has reached its daily limit. Cloud agents' model calls are refused until",
        ),
        findsOneWidget,
      );
    });

    testWidgets('the platform limit has its own words', (t) async {
      await mount(t, _free(), spend: _spend(refusing: true, platform: true));
      expect(
        find.textContaining("The platform's daily limit has been reached."),
        findsOneWidget,
      );
    });

    testWidgets('a 4xx hides the card', (t) async {
      await mount(t, _free(), spend: {'error': 'no'}, spendStatus: 403);
      expect(find.text('Cloud agent spend'), findsNothing);
    });

    for (final status in [502, 429, 400]) {
      testWidgets('a $status warns instead of hiding', (t) async {
        await mount(t, _free(), spend: {'error': 'down'}, spendStatus: status);
        expect(find.text('Cloud agent spend'), findsOneWidget);
        expect(find.text('Failed to load cloud agent spend'), findsOneWidget);
      });
    }

    testWidgets('only who can read the billing summary reads the spend', (
      t,
    ) async {
      await mount(t, _free(read: false), spend: _spend());
      expect(find.text('Cloud agent spend'), findsNothing);
      expect(a.reads('/billing/hosted-runtime-usage'), isEmpty);
    });

    testWidgets('a server without the route (older) shows nothing', (t) async {
      await mount(t, _free());
      expect(find.text('Cloud agent spend'), findsNothing);
    });

    testWidgets('a re-render does not read again', (t) async {
      await mount(t, _free(), spend: _spend());
      await t.pump(const Duration(seconds: 5));
      w.notifyListeners();
      await t.pumpAndSettle();
      expect(a.reads('/billing/hosted-runtime-usage'), hasLength(1));
    });
  });

  group('promotion code at checkout', () {
    testWidgets('the field and its hint are on the checkout form', (t) async {
      await mount(t, _free());
      expect(find.text('Promotion code (optional)'), findsWidgets);
      expect(
        find.text(
          'Stripe checks this code at Checkout. Leave blank to enter a code there.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a code is trimmed, reviewed and sent', (t) async {
      final opened = await mount(t, _free());
      a.routes['POST /billing/checkout'] = (_) => {
        'url': 'https://checkout.stripe.invalid/session',
      };
      await t.enterText(
        find.byKey(const ValueKey('billing-promotion-input')),
        ' spring26 ',
      );
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('billing-upgrade')));
      await t.pumpAndSettle();
      expect(
        find.textContaining(
          'Promotion code: spring26. The final discount is confirmed on Stripe Checkout.',
        ),
        findsOneWidget,
      );
      await t.tap(find.byKey(const ValueKey('billing-confirm')));
      await t.pumpAndSettle();
      final body = a.posts('/billing/checkout').single.data as Map;
      expect(body['promotionCode'], 'spring26');
      expect(opened.single.host, 'checkout.stripe.invalid');
    });

    testWidgets('no code sends none and reviews none', (t) async {
      await mount(t, _free());
      a.routes['POST /billing/checkout'] = (_) => {
        'url': 'https://checkout.stripe.invalid/session',
      };
      await t.tap(find.byKey(const ValueKey('billing-upgrade')));
      await t.pumpAndSettle();
      expect(find.textContaining('Promotion code:'), findsNothing);
      await t.tap(find.byKey(const ValueKey('billing-confirm')));
      await t.pumpAndSettle();
      final body = a.posts('/billing/checkout').single.data as Map;
      expect(body.containsKey('promotionCode'), isFalse);
    });

    testWidgets('an unavailable code says to check or remove it', (t) async {
      await mount(t, _free());
      a.routes['POST /billing/checkout'] = (_) => {
        'error': 'Promotion code unavailable',
        'code': 'promotion_code_unavailable',
      };
      a.statuses['POST /billing/checkout'] = 400;
      await t.enterText(
        find.byKey(const ValueKey('billing-promotion-input')),
        'GONE',
      );
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('billing-upgrade')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('billing-confirm')));
      await t.pumpAndSettle();
      expect(
        find.text(
          'This promotion code is unavailable. Check it or remove it to continue.',
        ),
        findsOneWidget,
      );
    });
  });
}
