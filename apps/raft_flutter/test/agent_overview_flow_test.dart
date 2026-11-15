// Web v1.24 components/agent/AgentActivityOverview.tsx: the overview reads in
// time order (oldest at the top, the running turn, then the Now card at the
// bottom), follows the bottom, keeps the reader's place when earlier turns
// load, hints "New turn" when a turn finishes below, restarts from the newest
// page after a gap, and shows a revisit from what it held.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/agent_activity_summaries.dart';

import 'support/agent_overview_fixture.dart';

List<Map<String, dynamic>> _page(String prefix, int count, {int from = 0}) => [
  // Newest first, as the API pages them.
  for (var i = count - 1; i >= 0; i--)
    turnJson('$prefix$i', minutes: from + i * 10, reply: 'm-$prefix$i'),
];

void main() {
  group('page parsing', () {
    test('lastText and usageLimit are read; current has no outcome', () {
      final page = TurnSummaryPage.parse({
        'summaries': [
          turnJson(
            't1',
            lastText: 'I looked at the diff first.',
            usageLimit: {'resetsAt': 1234},
          ),
        ],
        'next': 'c',
        'current': {
          'id': 'run',
          'startedAt': 5,
          'endedAt': 9,
          'actions': <Object?>[],
        },
      });
      expect(page.summaries.single.lastText, 'I looked at the diff first.');
      expect(page.summaries.single.usageLimit, isTrue);
      expect(page.summaries.single.usageResetsAt, 1234);
      expect(page.next, 'c');
      expect(page.current?.running, isTrue);
      expect(page.current?.outcome, 'running');
    });

    test('mergeTurnPages keeps each turn once, newest first', () {
      TurnSummary t(String id, int ended) => TurnSummary.tryParse({
        'id': id,
        'startedAt': ended - 1,
        'endedAt': ended,
        'outcome': 'completed',
      })!;
      final merged = mergeTurnPages([
        [t('b', 20), t('a', 10)],
        [t('a', 10), t('z', 5)],
      ]);
      expect(merged.map((e) => e.id), ['b', 'a', 'z']);
    });
  });

  group('order', () {
    testWidgets('oldest at the top, the Now card at the bottom, opened there', (
      tester,
    ) async {
      final pages = [
        [
          turnJson('t3', minutes: 40, reply: 'm3'),
          turnJson('t2', minutes: 20, reply: 'm2'),
          turnJson('t1', minutes: 0, reply: 'm1'),
        ],
      ];
      final h = await overviewWorkspace(
        tester,
        queryRoutes: summaryRoutes(() => pages),
      );
      await pumpOverview(tester, h);
      final y1 = turnTop(tester, 't1');
      final y2 = turnTop(tester, 't2');
      final y3 = turnTop(tester, 't3');
      expect(y1, lessThan(y2));
      expect(y2, lessThan(y3));
      final now = tester.getTopLeft(
        find.byKey(const ValueKey('agent-now-card')),
      );
      expect(y3, lessThan(now.dy));
    });

    testWidgets('a long overview opens on the newest, not the oldest', (
      tester,
    ) async {
      final pages = [_page('p1-', 14)];
      final h = await overviewWorkspace(
        tester,
        queryRoutes: summaryRoutes(() => pages),
      );
      await pumpOverview(tester, h);
      // The Now card is on screen at the bottom of the 700 px view.
      final now = find.byKey(const ValueKey('agent-now-card'));
      expect(now, findsOneWidget);
      expect(tester.getBottomLeft(now).dy, lessThanOrEqualTo(700));
      expect(tester.getTopLeft(now).dy, greaterThan(300));
    });

    testWidgets(
      'the running turn follows the finished ones, then the Now card',
      (tester) async {
        final pages = [
          [turnJson('t1', reply: 'm1')],
        ];
        final h = await overviewWorkspace(
          tester,
          queryRoutes: summaryRoutes(
            () => pages,
            current: () => {
              'id': 'run',
              'startedAt': turnsT0 + 30 * 60000,
              'endedAt': turnsT0 + 33 * 60000,
              'actions': [
                {'kind': 'run_command', 'count': 2},
              ],
              'toolCalls': 2,
              'problems': <Object?>[],
              'problemCount': 0,
              'messagesSent': 0,
            },
          ),
        );
        await pumpOverview(
          tester,
          h,
          activity: 'working',
          activityText: 'Running a command',
        );
        expect(
          find.byKey(const ValueKey('activity-overview-running')),
          findsOneWidget,
        );
        expect(find.text('In progress'), findsOneWidget);
        expect(find.textContaining('running for 3m 0s'), findsOneWidget);
        final y1 = turnTop(tester, 't1');
        final yRun = turnTop(tester, 'running:run');
        final now = tester
            .getTopLeft(find.byKey(const ValueKey('agent-now-card')))
            .dy;
        expect(y1, lessThan(yRun));
        expect(yRun, lessThan(now));
      },
    );

    testWidgets(
      'an empty wake the running turn took over is listed once, as running',
      (tester) async {
        final pages = [
          [turnJson('wake', minutes: 30), turnJson('t1', reply: 'm1')],
        ];
        final h = await overviewWorkspace(
          tester,
          queryRoutes: summaryRoutes(
            () => pages,
            current: () => {
              'id': 'wake',
              'startedAt': turnsT0 + 30 * 60000,
              'endedAt': turnsT0 + 31 * 60000,
              'actions': <Object?>[],
            },
          ),
        );
        await pumpOverview(tester, h, activity: 'working');
        expect(find.byKey(const ValueKey('turn-wake')), findsNothing);
        expect(find.byKey(const ValueKey('turn-running:wake')), findsOneWidget);
        expect(find.byKey(const ValueKey('turn-t1')), findsOneWidget);
      },
    );
  });

  group('earlier turns', () {
    testWidgets(
      '"Show earlier turns" is at the top and the reader keeps their place',
      (tester) async {
        final pages = [_page('p1-', 12, from: 200), _page('p0-', 12)];
        final h = await overviewWorkspace(
          tester,
          queryRoutes: summaryRoutes(() => pages),
        );
        await pumpOverview(tester, h);
        await scrollOverviewToTop(tester);
        final more = find.byKey(const ValueKey('activity-overview-load-more'));
        expect(more, findsOneWidget);
        // The oldest turn held is the one the reader is looking at.
        final before = turnTop(tester, 'p1-0');
        await tester.tap(more);
        await tester.pumpAndSettle();
        expect(more, findsNothing);
        expect(turnTop(tester, 'p1-0'), closeTo(before, 1));
        // The earlier page is above, in time order.
        await scrollOverviewToTop(tester);
        expect(turnTop(tester, 'p0-0'), lessThan(turnTop(tester, 'p0-1')));
        expect(turnTop(tester, 'p0-11'), lessThan(turnTop(tester, 'p1-0')));
        expect(
          h.w.queries
              .where((q) => q.$1 == '/agents/a/activity-summaries')
              .map((q) => q.$2?['before']),
          [null, '1'],
        );
      },
    );

    testWidgets('after a gap the overview starts again from the newest page', (
      tester,
    ) async {
      var pages = [_page('p1-', 12, from: 200), _page('p0-', 12)];
      final h = await overviewWorkspace(
        tester,
        queryRoutes: summaryRoutes(() => pages),
      );
      await pumpOverview(tester, h);
      await scrollOverviewToTop(tester);
      await tester.tap(
        find.byKey(const ValueKey('activity-overview-load-more')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('turn-p0-5'), skipOffstage: false),
        findsOneWidget,
      );
      // A reconnect: more turns finished than one page while away, so the
      // newest page shares nothing with what is held.
      pages = [_page('p2-', 12, from: 400), _page('p1-', 12, from: 200)];
      pushActivityFrame(h);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('turn-p0-5'), skipOffstage: false),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('turn-p2-11'), skipOffstage: false),
        findsOneWidget,
      );
      // The newest is in view again, like a first load.
      final now = find.byKey(const ValueKey('agent-now-card'));
      expect(tester.getBottomLeft(now).dy, lessThanOrEqualTo(700));
      // And the earlier pages can be asked for again.
      expect(
        find.byKey(
          const ValueKey('activity-overview-load-more'),
          skipOffstage: false,
        ),
        findsOneWidget,
      );
    });
  });

  group('new turn', () {
    testWidgets(
      'a reader above the bottom keeps their place and gets "New turn", which jumps down',
      (tester) async {
        var pages = [_page('p1-', 14)];
        final h = await overviewWorkspace(
          tester,
          queryRoutes: summaryRoutes(() => pages),
        );
        await pumpOverview(tester, h);
        await tester.drag(
          find.byKey(const ValueKey('activity-overview-scroll')),
          const Offset(0, 500),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('activity-overview-new-turn')),
          findsNothing,
        );
        final reading = turnTop(tester, 'p1-12');
        pages = [
          [
            turnJson('p1-new', minutes: 500, reply: 'm-new'),
            ..._page('p1-', 14),
          ],
        ];
        pushActivityFrame(h);
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
        final pill = find.byKey(const ValueKey('activity-overview-new-turn'));
        expect(pill, findsOneWidget);
        expect(find.text('New turn ↓'), findsOneWidget);
        expect(turnTop(tester, 'p1-12'), closeTo(reading, 1));
        await tester.tap(pill);
        await tester.pumpAndSettle();
        expect(pill, findsNothing);
        final now = find.byKey(const ValueKey('agent-now-card'));
        expect(tester.getBottomLeft(now).dy, lessThanOrEqualTo(700));
      },
    );

    testWidgets(
      'a reader at the bottom follows the new turn and is never hinted',
      (tester) async {
        var pages = [_page('p1-', 14)];
        final h = await overviewWorkspace(
          tester,
          queryRoutes: summaryRoutes(() => pages),
        );
        await pumpOverview(tester, h);
        pages = [
          [
            turnJson('p1-new', minutes: 500, reply: 'm-new'),
            ..._page('p1-', 14),
          ],
        ];
        pushActivityFrame(h);
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('activity-overview-new-turn')),
          findsNothing,
        );
        // The new turn is in view, above the Now card, which is still at the bottom.
        expect(turnTop(tester, 'p1-new'), lessThan(700));
        expect(turnTop(tester, 'p1-new'), greaterThan(0));
        expect(
          tester.getBottomLeft(find.byKey(const ValueKey('agent-now-card'))).dy,
          lessThanOrEqualTo(700),
        );
      },
    );

    testWidgets('a short overview never shows the hint', (tester) async {
      var pages = [
        [turnJson('t1', reply: 'm1')],
      ];
      final h = await overviewWorkspace(
        tester,
        queryRoutes: summaryRoutes(() => pages),
      );
      await pumpOverview(tester, h);
      pages = [
        [turnJson('t2', minutes: 20, reply: 'm2'), turnJson('t1', reply: 'm1')],
      ];
      pushActivityFrame(h);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('turn-t2')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('activity-overview-new-turn')),
        findsNothing,
      );
    });
  });

  group('revisit and first frame', () {
    testWidgets(
      'a revisit shows what was held at the first frame, with no loading state',
      (tester) async {
        final pages = [
          [
            turnJson('t2', minutes: 20, reply: 'm2'),
            turnJson('t1', reply: 'm1'),
          ],
        ];
        final h = await overviewWorkspace(
          tester,
          queryRoutes: summaryRoutes(() => pages),
        );
        await pumpOverview(tester, h);
        expect(find.byKey(const ValueKey('turn-t1')), findsOneWidget);
        // Leave, then come back while the read is slow.
        await tester.pumpWidget(const SizedBox.shrink());
        h.w.queryRoutes['/agents/a/activity-summaries'] = (_) async {
          await Future<void>.delayed(const Duration(seconds: 5));
          return {'summaries': pages.first};
        };
        await pumpOverview(tester, h, settle: false);
        // First frame: the turns are there, the Now card is not alone.
        expect(find.byKey(const ValueKey('turn-t1')), findsOneWidget);
        expect(find.byKey(const ValueKey('turn-t2')), findsOneWidget);
        expect(find.text('Couldn\'t load the overview.'), findsNothing);
        await tester.pump(const Duration(seconds: 6));
      },
    );

    testWidgets('a turn arriving leaves the rows already shown as they were', (
      tester,
    ) async {
      var pages = [
        [turnJson('t2', minutes: 20, reply: 'm2'), turnJson('t1', reply: 'm1')],
      ];
      final h = await overviewWorkspace(
        tester,
        queryRoutes: summaryRoutes(() => pages),
      );
      await pumpOverview(tester, h);
      final t1 = find.byKey(const ValueKey('turn-t1'));
      final element = tester.element(t1);
      final texts = [
        for (final w in tester.widgetList<Text>(
          find.descendant(of: t1, matching: find.byType(Text)),
        ))
          w.data ?? w.textSpan?.toPlainText(),
      ];
      pages = [
        [
          turnJson('t3', minutes: 40, reply: 'm3'),
          turnJson('t2', minutes: 20, reply: 'm2'),
          turnJson('t1', reply: 'm1'),
        ],
      ];
      pushActivityFrame(h);
      await tester.pump(const Duration(milliseconds: 300));
      // The reload is in flight and then settled: the same element, the same words.
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.element(t1), same(element));
      }
      await tester.pumpAndSettle();
      expect(tester.element(t1), same(element));
      expect([
        for (final w in tester.widgetList<Text>(
          find.descendant(of: t1, matching: find.byType(Text)),
        ))
          w.data ?? w.textSpan?.toPlainText(),
      ], texts);
      expect(find.byKey(const ValueKey('turn-t3')), findsOneWidget);
    });
  });

  group('turn content', () {
    testWidgets('the agent\'s own last text is two lines until tapped', (
      tester,
    ) async {
      final long = List.generate(
        12,
        (i) => 'Line $i of what the agent said about its own work.',
      ).join('\n');
      final pages = [
        [turnJson('t1', lastText: long, reply: 'm1')],
      ];
      final h = await overviewWorkspace(
        tester,
        queryRoutes: summaryRoutes(() => pages),
      );
      await pumpOverview(tester, h);
      final text = find.byKey(const ValueKey('activity-overview-output-text'));
      expect(text, findsOneWidget);
      final collapsed = tester.getSize(text).height;
      await tester.tap(text);
      await tester.pumpAndSettle();
      expect(tester.getSize(text).height, greaterThan(collapsed * 3));
      await tester.tap(text);
      await tester.pumpAndSettle();
      expect(tester.getSize(text).height, closeTo(collapsed, 1));
    });

    testWidgets('a short last text is plain, with nothing to expand', (
      tester,
    ) async {
      final pages = [
        [turnJson('t1', lastText: 'Done and dusted.', reply: 'm1')],
      ];
      final h = await overviewWorkspace(
        tester,
        queryRoutes: summaryRoutes(() => pages),
      );
      await pumpOverview(tester, h);
      expect(find.text('Done and dusted.'), findsOneWidget);
    });

    testWidgets('the turn lists every message it sent, three first', (
      tester,
    ) async {
      final ids = ['s1', 's2', 's3', 's4'];
      final pages = [
        [turnJson('t1', sent: 4, sentMessageIds: ids, reply: 's4')],
      ];
      final h = await overviewWorkspace(
        tester,
        queryRoutes: {
          ...summaryRoutes(() => pages),
          for (final id in ids)
            '/messages/context/$id': (_) => {
              'targetMessageId': id,
              'messages': [
                {
                  'id': id,
                  'content': 'Sent $id',
                  'channelId': 'c1',
                  'createdAt': '2026-10-24T02:44:00.000Z',
                },
              ],
            },
        },
      );
      await pumpOverview(tester, h);
      expect(find.text('Sent s1'), findsOneWidget);
      expect(find.text('Sent s3'), findsOneWidget);
      expect(find.text('Sent s4'), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey('activity-overview-sent-more')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sent s4'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('activity-overview-sent-more')),
        findsNothing,
      );
    });
  });
}
