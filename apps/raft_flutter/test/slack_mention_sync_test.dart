// Web v1.21.23: the Slack bridge health carries `agentMentionSync`, and the
// health card explains why some Raft members are missing from Slack's @ menu.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_flutter/features/im_bridges_view.dart';
import 'package:raft_flutter/features/slack_bridge_contract.dart';

import 'slack_bridge_contract_test.dart' show bridgeFixture, clone;
import 'support/integ_fixture.dart';

Map<String, dynamic> _withSync(
  Map<String, dynamic> base, {
  String state = 'degraded',
  String? slackError = 'missing_scope',
  int expected = 3,
  int actual = 1,
}) {
  final v = clone(base);
  v['snapshot']['rawHealth']['agentMentionSync'] = {
    'state': state,
    'slackError': slackError,
    'expected': expected,
    'actual': actual,
    'observedAt': '2026-10-21T00:00:00Z',
  };
  return v;
}

void main() {
  group('contract', () {
    test(
      'a v1.21.23 health with agentMentionSync parses (null or an object)',
      () {
        final base = bridgeFixture();
        expect(SlackBridgeProjection.parse(base).mentionSyncHint, isNull);
        final withNull = clone(base)
          ..['snapshot']['rawHealth']['agentMentionSync'] = null;
        expect(SlackBridgeProjection.parse(withNull).mentionSyncHint, isNull);
        expect(
          SlackBridgeProjection.parse(_withSync(base)).mentionSyncHint,
          isNotNull,
        );
      },
    );

    test('a malformed agentMentionSync fails closed', () {
      final base = bridgeFixture();
      for (final bad in <Map<String, dynamic>>[
        {
          'state': 'broken',
          'slackError': null,
          'expected': 1,
          'actual': 0,
          'observedAt': '2026-10-21T00:00:00Z',
        },
        {
          'state': 'degraded',
          'slackError': 'x',
          'expected': -1,
          'actual': 0,
          'observedAt': '2026-10-21T00:00:00Z',
        },
        {
          'state': 'degraded',
          'slackError': 'x',
          'expected': 1,
          'actual': 0,
          'observedAt': 'yesterday',
        },
        {
          'state': 'degraded',
          'slackError': 'x',
          'expected': 1,
          'actual': 0,
          'observedAt': '2026-10-21T00:00:00Z',
          'extra': 1,
        },
        {
          'state': 'degraded',
          'expected': 1,
          'actual': 0,
          'observedAt': '2026-10-21T00:00:00Z',
        },
      ]) {
        final v = clone(base)
          ..['snapshot']['rawHealth']['agentMentionSync'] = bad;
        expect(
          () => SlackBridgeProjection.parse(v),
          throwsFormatException,
          reason: '$bad',
        );
      }
    });

    test('the hint follows Web: actionable errors only, by error code', () {
      final base = bridgeFixture();
      String? source(
        String? error, {
        String state = 'degraded',
        int expected = 3,
        int actual = 1,
      }) => SlackBridgeProjection.parse(
        _withSync(
          base,
          state: state,
          slackError: error,
          expected: expected,
          actual: actual,
        ),
      ).mentionSyncHint?.source;
      expect(
        source('restricted_action'),
        contains('let members create user groups'),
      );
      expect(
        source('permission_denied'),
        contains('let members create user groups'),
      );
      expect(source('missing_scope'), contains('Update Slack authorization'));
      expect(source('name_taken'), contains('{count} members'));
      expect(
        source('name_taken', expected: 2, actual: 1),
        contains('{count} member '),
      );
      expect(source('ratelimited'), contains('({code})'));
      // Silent: a free Slack plan, a transient failure, or a healthy sync.
      expect(source('paid_only'), isNull);
      expect(source('paid_teams_only'), isNull);
      expect(source(null), isNull);
      expect(source('missing_scope', state: 'synced'), isNull);
    });

    test('the missing count is at least one', () {
      final p = SlackBridgeProjection.parse(
        _withSync(
          bridgeFixture(),
          slackError: 'name_taken',
          expected: 2,
          actual: 5,
        ),
      );
      expect(p.mentionSyncHint!.count, 1);
      expect(p.mentionSyncHint!.code, 'name_taken');
    });
  });

  group('health card', () {
    Future<void> pump(WidgetTester t, Map<String, dynamic> body) async {
      final (w, a) = (await t.runAsync(() => integFixture('owner')))!;
      addTearDown(w.dispose);
      a.routes['POST /feature-flags/evaluate'] = (_) => {
        'evaluations': [
          {'key': 'slack_bridge_v0', 'enabled': true},
        ],
      };
      a.routes['GET /slack-bridge/provisioning'] = (_) => body;
      t.view.physicalSize = const Size(1000, 3000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Scaffold(body: IMBridgesView(controller: w)),
        ),
      );
      await t.pumpAndSettle();
    }

    Map<String, dynamic> health(Map<String, dynamic> v) =>
        v..['snapshot']['stage'] = 'health';

    testWidgets('a missing scope is explained under the health summary', (
      t,
    ) async {
      await pump(t, health(_withSync(bridgeFixture())));
      expect(
        find.byKey(const ValueKey('slack-mention-sync-hint')),
        findsOneWidget,
      );
      expect(
        find.text("Some members can't be picked from Slack's @ menu yet"),
        findsOneWidget,
      );
      expect(find.textContaining('Update Slack authorization'), findsWidgets);
    });

    testWidgets('names that are taken report how many members are missing', (
      t,
    ) async {
      await pump(
        t,
        health(
          _withSync(
            bridgeFixture(),
            slackError: 'name_taken',
            expected: 5,
            actual: 2,
          ),
        ),
      );
      expect(find.textContaining('3 members'), findsOneWidget);
    });

    for (final (name, body) in [
      (
        'a free Slack plan',
        health(_withSync(bridgeFixture(), slackError: 'paid_only')),
      ),
      (
        'a synced list',
        health(_withSync(bridgeFixture(), state: 'synced', slackError: null)),
      ),
      ('an old server without the field', health(bridgeFixture())),
    ]) {
      testWidgets('$name shows no hint', (t) async {
        await pump(t, body);
        expect(
          find.byKey(const ValueKey('slack-bridge-wizard')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('slack-mention-sync-hint')),
          findsNothing,
        );
      });
    }
  });
}
