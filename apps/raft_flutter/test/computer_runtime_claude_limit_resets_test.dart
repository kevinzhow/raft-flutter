import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/runtime_usage_chip.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/runtime_auth_fixture.dart';

/// Web v1.24 useClaudeLimitResets + ClaudeLimitResetsDialog: Claude limit
/// resets on the usage card (flag `claude_limit_reset`), against a fake
/// Computer.
class _FlagClient extends FixtureClient {
  bool flagOn = true;
  @override
  Future<dynamic> post(String path, {dynamic data}) async => {
    'evaluations': [
      {'key': 'claude_limit_reset', 'enabled': flagOn},
    ],
  };
}

Map<String, dynamic> claudeUsage({bool atLimit = false, double used = .42}) => {
  'state': 'fresh',
  'snapshot': {
    'provider': 'claude',
    'collectedAt': DateTime.now()
        .subtract(const Duration(minutes: 5))
        .toUtc()
        .toIso8601String(),
    'accounts': [
      {
        'accountKey': 'k',
        'planLabel': 'Max',
        'maskedLabel': 'ali****@example.com',
        'health': atLimit ? 'rate_limited' : 'ok',
        'windows': [
          {
            'id': '5h',
            'label': 'Current session',
            'status': atLimit ? 'limit_reached' : 'ok',
            'usedRatio': atLimit ? 1 : used,
            'resetsAt': DateTime.now()
                .add(const Duration(hours: 3))
                .toUtc()
                .toIso8601String(),
          },
        ],
      },
    ],
  },
};

void main() {
  late FixtureWorkspace w;
  late FakeComputerApi api;
  late _FlagClient client;
  TestGesture? hovering;
  setUp(() {
    api = FakeComputerApi();
    addTearDown(api.dispose);
  });
  const readPath = '/runtime-account-usage/claude/limit-resets/read';
  const redeemPath = '/runtime-account-usage/claude/limit-reset';

  Map<String, dynamic> view({
    String? resets = 'ok',
    bool canUse = true,
    bool canConsent = true,
    bool canAct = true,
  }) => {
    ...authView(
      canAct: canAct,
      runtimes: {
        'claude': {'kind': 'logged_in'},
      },
    ),
    'claudeLimitResets': ?resets,
    'claudeLimitResetAccess': {'canUse': canUse, 'canConsent': canConsent},
  };

  Map<String, dynamic> read(
    List<Map<String, dynamic>> resets, {
    String? program,
    bool? spent,
  }) => {
    'result': {
      'kind': 'read',
      'program': ?program,
      'fiveHourSpent': ?spent,
      'resets': resets,
    },
  };
  final available = <Map<String, dynamic>>[
    {'kind': 'five_hour', 'state': 'none'},
    {
      'kind': 'weekly',
      'state': 'available',
      'resetsLeft': 2,
      'expiresText': 'Nov 20',
    },
    {'kind': 'fable', 'state': 'not_offered'},
    {'kind': 'full', 'state': 'unknown'},
  ];

  Future<void> mount(
    WidgetTester t, {
    Map<String, dynamic>? authViewJson,
    Map<String, dynamic>? usage,
    bool flag = true,
  }) async {
    client = _FlagClient()..flagOn = flag;
    w = FixtureWorkspace(client);
    addTearDown(() async {
      w.dispose();
      await client.stream.close();
      await client.dispose();
    });
    await w.entityDirectory.preload();
    api
      ..view = authViewJson ?? view()
      ..usage = usage ?? claudeUsage();
    await t.pumpWidget(
      fixtureHost(
        runtimeUsageGateChip(
          controller: w,
          enabled: true,
          runtimeId: 'claude',
          machineId: 'c',
          label: 'Claude Code',
          runtimeVersion: '2.1.0',
          client: api.usageClient,
          authClient: api.auth,
          chip: (status) => RaftRuntimeChip(
            label: 'Claude Code',
            detected: true,
            trailing: status,
          ),
        ),
      ),
    );
    await settle(t);
  }

  Future<void> open(WidgetTester t) async {
    await hovering?.removePointer();
    final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(t.getCenter(find.byType(RaftRuntimeUsageChip)));
    await t.pump(const Duration(milliseconds: 210));
    await settle(t);
    hovering = mouse;
    addTearDown(mouse.removePointer);
  }

  Future<void> tapKey(WidgetTester t, String id) async {
    await t.tap(find.byKey(ValueKey(id)));
    await settle(t, 10);
  }

  Finder key(String id) => find.byKey(ValueKey(id));
  const view_ = 'claude-limit-resets-view-action';
  const five = 'claude-limit-reset-five-hour-action';

  group('the card', () {
    testWidgets('flag off: no Claude actions', (t) async {
      await mount(t, flag: false);
      await open(t);
      expect(key(view_), findsNothing);
      expect(key(five), findsNothing);
    });

    testWidgets('no claudeLimitResets in the view: nothing to offer', (
      t,
    ) async {
      await mount(t, authViewJson: view(resets: null));
      await open(t);
      expect(key(view_), findsNothing);
    });

    testWidgets('a person who may not act on the runtimes sees no actions', (
      t,
    ) async {
      await mount(t, authViewJson: view(canAct: false));
      await open(t);
      expect(key(view_), findsNothing);
    });

    testWidgets('computer_upgrade_required: Web draws no Claude action or '
        'line (the card stays as it is)', (t) async {
      await mount(t, authViewJson: view(resets: 'computer_upgrade_required'));
      await open(t);
      expect(key('runtime-usage-card'), findsOneWidget);
      expect(key(view_), findsNothing);
      expect(key(five), findsNothing);
      expect(key('claude-limit-resets-owner-only'), findsNothing);
    });

    testWidgets('ok below the limit: View available resets, no Use 5-hour', (
      t,
    ) async {
      await mount(t);
      await open(t);
      expect(find.text('View available resets'), findsOneWidget);
      expect(key(five), findsNothing);
    });

    testWidgets('at the 5-hour limit: Use 5-hour reset is offered too', (
      t,
    ) async {
      await mount(t, usage: claudeUsage(atLimit: true));
      await open(t);
      expect(key(view_), findsOneWidget);
      expect(key(five), findsOneWidget);
    });

    testWidgets('owner only (canUse false): the line, View but no Use', (
      t,
    ) async {
      await mount(
        t,
        authViewJson: view(canUse: false),
        usage: claudeUsage(atLimit: true),
      );
      await open(t);
      expect(key('claude-limit-resets-owner-only'), findsOneWidget);
      expect(key(view_), findsOneWidget);
      expect(key(five), findsNothing);
    });
  });

  group('the list', () {
    Future<void> view0(WidgetTester t, {bool atLimit = false}) async {
      await mount(t, usage: claudeUsage(atLimit: atLimit));
      await open(t);
      await tapKey(t, view_);
    }

    testWidgets('below the limit it reads at once, without consent, and '
        'lists each kind with what Claude Code showed', (t) async {
      api.answers[readPath] = (body) => read(available);
      await view0(t);
      expect(api.posts.where((p) => p.endsWith(readPath)), hasLength(1));
      expect(
        api.bodies.entries.firstWhere((e) => e.key.endsWith(readPath)).value,
        isEmpty,
      );
      expect(find.text('Claude limit resets'), findsOneWidget);
      expect(find.text('2 left · use by Nov 20'), findsOneWidget);
      expect(find.text('None'), findsOneWidget);
      expect(find.text('Not on this account'), findsOneWidget);
      expect(find.text("Couldn't read"), findsOneWidget);
      // Nothing is chosen for the person: Use stays off until they pick.
      expect(
        t.widget<RaftButton>(key('claude-limit-resets-use')).onPressed,
        isNull,
      );
      await t.tap(key('claude-limit-reset-weekly'));
      await settle(t);
      expect(
        t.widget<RaftButton>(key('claude-limit-resets-use')).onPressed,
        isNotNull,
      );
      // A kind that is not available cannot be chosen.
      await t.tap(key('claude-limit-reset-full'));
      await settle(t);
      expect(
        t.widget<RaftButton>(key('claude-limit-resets-use')).onPressed,
        isNotNull,
      );
    });

    testWidgets('at the 5-hour limit the read waits for consent; Cancel '
        'never reads', (t) async {
      api.answers[readPath] = (body) => read(available);
      await view0(t, atLimit: true);
      expect(key('claude-limit-resets-consent'), findsOneWidget);
      expect(
        find.text('Check your resets at the 5-hour limit?'),
        findsOneWidget,
      );
      expect(api.posts.where((p) => p.endsWith(readPath)), isEmpty);
      await t.tap(find.text('Cancel'));
      await settle(t);
      expect(key('claude-limit-resets-consent'), findsNothing);
      expect(api.posts.where((p) => p.endsWith(readPath)), isEmpty);
    });

    testWidgets('Continue reads once with consent; at the limit only a 5-hour '
        'reset can be used and the hint says where the rest is', (t) async {
      api.answers[readPath] = (body) => read([
        {'kind': 'five_hour', 'state': 'available', 'resetsLeft': 1},
        ...available.skip(1),
      ]);
      await view0(t, atLimit: true);
      await tapKey(t, 'claude-limit-resets-consent-continue');
      expect(
        api.bodies.entries.firstWhere((e) => e.key.endsWith(readPath)).value,
        {'consent': true},
      );
      expect(key('claude-limit-resets-at-limit-hint'), findsOneWidget);
      await t.tap(key('claude-limit-reset-weekly'));
      await settle(t);
      expect(
        t.widget<RaftButton>(key('claude-limit-resets-use')).onPressed,
        isNull,
      );
      await t.tap(key('claude-limit-reset-five_hour'));
      await settle(t);
      expect(
        t.widget<RaftButton>(key('claude-limit-resets-use')).onPressed,
        isNotNull,
      );
    });

    testWidgets('a viewer who cannot consent gets no Continue to press', (
      t,
    ) async {
      await mount(
        t,
        authViewJson: view(canConsent: false),
        usage: claudeUsage(atLimit: true),
      );
      await open(t);
      await tapKey(t, view_);
      expect(
        t
            .widget<RaftButton>(key('claude-limit-resets-consent-continue'))
            .onPressed,
        isNull,
      );
      expect(
        find.text(
          'Only the person who connected this Computer can use its Claude resets.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('owner only: the kinds are listed, Use is never enabled', (
      t,
    ) async {
      await mount(t, authViewJson: view(canUse: false));
      api.answers[readPath] = (body) => read(available);
      await open(t);
      await tapKey(t, view_);
      await t.tap(key('claude-limit-reset-weekly'));
      await settle(t);
      expect(key('claude-limit-resets-owner-only'), findsOneWidget);
      expect(
        t.widget<RaftButton>(key('claude-limit-resets-use')).onPressed,
        isNull,
      );
    });

    for (final c in <(String, Map<String, dynamic>, String)>[
      (
        'reauth_required',
        {'kind': 'reauth_required'},
        'Sign in to Claude Code again on this Computer. No reset was used.',
      ),
      (
        'unsupported not_attempted',
        {'kind': 'unsupported', 'reason': 'not_attempted'},
        'Nothing was used: the Computer was busy or ran out of time. Try again.',
      ),
      (
        'unsupported not_installed',
        {'kind': 'unsupported', 'reason': 'not_installed'},
        'Claude Code is not installed on this Computer.',
      ),
      (
        'unsupported capability_unavailable',
        {'kind': 'unsupported', 'reason': 'capability_unavailable'},
        "Claude Code on this Computer can't use a limit reset from here. No reset was used.",
      ),
      ('unknown', {'kind': 'unknown'}, "Couldn't read your resets. Try again."),
    ]) {
      testWidgets('read answer ${c.$1}: its Web copy, nothing to use', (
        t,
      ) async {
        await mount(t);
        api.answers[readPath] = (body) => {'result': c.$2};
        await open(t);
        await tapKey(t, view_);
        expect(find.text(c.$3), findsOneWidget);
        expect(key('claude-limit-resets-failed'), findsOneWidget);
        expect(
          t.widget<RaftButton>(key('claude-limit-resets-use')).onPressed,
          isNull,
        );
      });
    }

    testWidgets('unsupported_platform: the dialog says so and the card '
        'stops offering resets', (t) async {
      await mount(t);
      api.answers[readPath] = (body) => {
        'result': {'kind': 'unsupported', 'reason': 'unsupported_platform'},
      };
      await open(t);
      await tapKey(t, view_);
      expect(
        find.text(
          "Claude limit resets aren't supported on this Computer. No reset was used.",
        ),
        findsOneWidget,
      );
      await t.tap(find.text('Cancel'));
      await settle(t);
      await open(t);
      expect(key(view_), findsNothing);
    });

    testWidgets('consent_required below the limit asks for consent and then '
        'reads with it', (t) async {
      await mount(t);
      var n = 0;
      api.answers[readPath] = (body) => body['consent'] == true
          ? read(available)
          : {
              'result': {'kind': 'unsupported', 'reason': 'consent_required'},
              'n': ++n,
            };
      await open(t);
      await tapKey(t, view_);
      expect(key('claude-limit-resets-consent'), findsOneWidget);
      await tapKey(t, 'claude-limit-resets-consent-continue');
      expect(find.text('Claude limit resets'), findsOneWidget);
      expect(find.text('Available'), findsNothing);
      expect(find.text('2 left · use by Nov 20'), findsOneWidget);
    });

    testWidgets('a request that failed says the Computer did not answer', (
      t,
    ) async {
      await mount(t);
      api.answers[readPath] = (body) =>
          throw RaftApiException.response('timeout', status: 504);
      await open(t);
      await tapKey(t, view_);
      expect(
        find.text("The Computer didn't answer in time. Try again."),
        findsOneWidget,
      );
    });

    testWidgets('legacy program: nothing to list, and at the 5-hour limit the '
        'card keeps only Use 5-hour reset', (t) async {
      await mount(t, usage: claudeUsage(atLimit: true));
      api.answers[readPath] = (body) => read([
        {'kind': 'five_hour', 'state': 'none'},
        {'kind': 'weekly', 'state': 'not_offered'},
      ], program: 'legacy');
      await open(t);
      await tapKey(t, view_);
      await tapKey(t, 'claude-limit-resets-consent-continue');
      expect(key('claude-limit-resets-legacy'), findsOneWidget);
      expect(key('claude-limit-reset-weekly'), findsNothing);
      await t.tap(find.text('Cancel'));
      await settle(t);
      await open(t);
      expect(key(view_), findsNothing);
      expect(key(five), findsOneWidget);
    });

    testWidgets('legacy and the 5-hour reset spent by opening the list: '
        'said, and the usage is read again', (t) async {
      await mount(t, usage: claudeUsage(atLimit: true));
      api.answers[readPath] = (body) => read(
        [
          {'kind': 'five_hour', 'state': 'unknown'},
        ],
        program: 'legacy',
        spent: true,
      );
      await open(t);
      await tapKey(t, view_);
      await tapKey(t, 'claude-limit-resets-consent-continue');
      expect(key('claude-limit-resets-five-hour-spent'), findsOneWidget);
      expect(api.posts.any((p) => p.endsWith('/refresh')), isTrue);
    });
  });

  group('using a reset', () {
    final fresh = claudeUsage(used: .1)['snapshot'];

    testWidgets('from the list: the confirm names the kind and the account, '
        'the chosen kind is sent, the note is said once on the card and the '
        'snapshot the Computer read replaces the usage', (t) async {
      await mount(t);
      api.answers[readPath] = (body) => read(available);
      api.answers[redeemPath] = (body) => {
        'result': {'kind': 'reset'},
        'snapshot': fresh,
      };
      await open(t);
      await tapKey(t, view_);
      await t.tap(key('claude-limit-reset-weekly'));
      await settle(t);
      await tapKey(t, 'claude-limit-resets-use');
      expect(find.text('Use your weekly reset?'), findsOneWidget);
      expect(
        find.textContaining('ali****@example.com', findRichText: true),
        findsOneWidget,
      );
      await tapKey(t, 'claude-limit-reset-confirm-action');
      await settle(t, 12);
      expect(
        api.bodies[api.posts.firstWhere(
          (p) => p.endsWith(redeemPath),
        )]!['kind'],
        'weekly',
      );
      // Both dialogs are gone.
      expect(find.text('Claude limit resets'), findsNothing);
      expect(find.text('Use your weekly reset?'), findsNothing);
      await open(t);
      expect(find.text('Used your weekly reset.'), findsOneWidget);
      expect(find.text('10% used · resets in 3 hours'), findsOneWidget);
      // Resolved: the next manual refresh drops the note.
      await tapKey(t, 'runtime-usage-refresh');
      expect(find.text('Used your weekly reset.'), findsNothing);
    });

    testWidgets('Use 5-hour reset at the limit opens the confirm directly '
        'and sends five_hour', (t) async {
      await mount(t, usage: claudeUsage(atLimit: true));
      api.answers[redeemPath] = (body) => {
        'result': {'kind': 'reset'},
        'snapshot': fresh,
      };
      await open(t);
      await tapKey(t, five);
      expect(find.text('Use your 5-hour reset?'), findsOneWidget);
      expect(api.posts.where((p) => p.endsWith(readPath)), isEmpty);
      await tapKey(t, 'claude-limit-reset-confirm-action');
      await settle(t, 12);
      expect(
        api.bodies[api.posts.firstWhere(
          (p) => p.endsWith(redeemPath),
        )]!['kind'],
        'five_hour',
      );
      await open(t);
      expect(find.text('Used your 5-hour reset.'), findsOneWidget);
      expect(key(five), findsNothing);
    });

    testWidgets('one idempotency key until the attempt is settled: a request '
        'with no answer keeps it, an answer retires it', (t) async {
      await mount(t, usage: claudeUsage(atLimit: true));
      final keys = <String>[];
      var calls = 0;
      api.answers[redeemPath] = (body) {
        keys.add(body['idempotencyKey'] as String);
        if (++calls == 1) {
          throw RaftApiException.response('timeout', status: 504);
        }
        return {
          'result': {'kind': 'no_reset'},
          'snapshot': claudeUsage(atLimit: true)['snapshot'],
        };
      };
      await open(t);
      await tapKey(t, five);
      await tapKey(t, 'claude-limit-reset-confirm-action');
      await settle(t, 12);
      // The confirm stays open and never invites a blind retry.
      expect(
        find.text(
          "The Computer didn't answer in time, so it's not known whether a reset was used. Check /usage in Claude Code before trying again.",
        ),
        findsOneWidget,
      );
      expect(find.text('Use your 5-hour reset?'), findsOneWidget);
      await tapKey(t, 'claude-limit-reset-confirm-action');
      await settle(t, 12);
      expect(keys, hasLength(2));
      expect(keys[0], keys[1]);
      expect(find.text('Use your 5-hour reset?'), findsNothing);
      // Settled: a new attempt mints a new key.
      await open(t);
      expect(
        find.text('No 5-hour reset to use. No reset was used.'),
        findsOneWidget,
      );
      await tapKey(t, five);
      api.answers[redeemPath] = (body) {
        keys.add(body['idempotencyKey'] as String);
        return {
          'result': {'kind': 'reset'},
          'snapshot': fresh,
        };
      };
      await tapKey(t, 'claude-limit-reset-confirm-action');
      await settle(t, 12);
      expect(keys, hasLength(3));
      expect(keys[2], isNot(keys[0]));
    });

    for (final c in <(String, Map<String, dynamic>, String)>[
      (
        'reauth_required',
        {'kind': 'reauth_required'},
        'Sign in to Claude Code again on this Computer. No reset was used.',
      ),
      (
        'not_attempted',
        {'kind': 'unsupported', 'reason': 'not_attempted'},
        'Nothing was used: the Computer was busy or ran out of time. Try again.',
      ),
      (
        'capability_unavailable',
        {'kind': 'unsupported', 'reason': 'capability_unavailable'},
        "Your 5-hour reset isn't available for this account on this Computer yet. No reset was used.",
      ),
    ]) {
      testWidgets('redeem answer ${c.$1} keeps the confirm open with why', (
        t,
      ) async {
        await mount(t, usage: claudeUsage(atLimit: true));
        api.answers[redeemPath] = (body) => {'result': c.$2};
        await open(t);
        await tapKey(t, five);
        await tapKey(t, 'claude-limit-reset-confirm-action');
        await settle(t, 12);
        expect(find.text(c.$3), findsOneWidget);
        expect(find.text('Use your 5-hour reset?'), findsOneWidget);
      });
    }

    testWidgets('unknown with the 5-hour reset spent: said on the card, and '
        'the card keeps only Use 5-hour reset (the older program)', (t) async {
      await mount(t, usage: claudeUsage(atLimit: true));
      api.answers[redeemPath] = (body) => {
        'result': {'kind': 'unknown', 'fiveHourSpent': true},
        'snapshot': claudeUsage(atLimit: true)['snapshot'],
      };
      await open(t);
      await tapKey(t, five);
      await tapKey(t, 'claude-limit-reset-confirm-action');
      await settle(t, 12);
      await open(t);
      expect(
        find.text(
          "Your 5-hour reset was used instead of the 5-hour reset: this account has only Claude's older once-a-week 5-hour reset.",
        ),
        findsOneWidget,
      );
      expect(key(view_), findsNothing);
    });

    testWidgets('a refusal (owner only) says so and nothing is said on the '
        'card', (t) async {
      await mount(t, usage: claudeUsage(atLimit: true));
      api.answers[redeemPath] = (body) => throw RaftApiException.response(
        'no',
        status: 403,
        body: {'error': 'no', 'code': 'claude_limit_reset_owner_only'},
      );
      await open(t);
      await tapKey(t, five);
      await tapKey(t, 'claude-limit-reset-confirm-action');
      await settle(t, 12);
      expect(
        find.text(
          'Only the person who connected this Computer can use its Claude resets.',
        ),
        findsOneWidget,
      );
      expect(find.text('Use your 5-hour reset?'), findsOneWidget);
    });
  });
}
