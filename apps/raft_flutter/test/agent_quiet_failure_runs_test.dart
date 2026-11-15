// Web v1.24 ActivityQuietFailureRuns.tsx + activityQuietFailures.ts: a runtime
// that cannot start ends one turn per retry; two or more in a row fold into
// one entry, usage-limit runs apart from error runs.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/agent_activity_summaries.dart';
import 'package:raft_flutter/features/agent_quiet_failure_runs.dart';

import 'support/agent_overview_fixture.dart';

Map<String, dynamic> _quiet(
  String id,
  int minutes, {
  int? resetsAt,
  bool limit = false,
}) => turnJson(
  id,
  minutes: minutes,
  lengthMinutes: 1,
  outcome: 'failed',
  toolCalls: 0,
  sent: 0,
  usageLimit: limit ? {'resetsAt': ?resetsAt} : null,
);

TurnSummary _parse(Map<String, dynamic> json) => TurnSummary.tryParse(json)!;

void main() {
  group('grouping', () {
    test('two quiet failures in a row are one run; one alone is a turn', () {
      final items = groupQuietFailures([
        _parse(_quiet('a', 0)),
        _parse(turnJson('ok', minutes: 5, reply: 'm')),
        _parse(_quiet('b', 10)),
        _parse(_quiet('c', 11)),
        _parse(_quiet('d', 12)),
        _parse(turnJson('ok2', minutes: 20, reply: 'm')),
        _parse(_quiet('e', 30)),
      ]);
      expect(
        [
          for (final i in items)
            i.turn?.id ?? 'run:${i.turns!.map((t) => t.id).join()}',
        ],
        ['a', 'ok', 'run:bcd', 'ok2', 'e'],
      );
    });

    test('a failed turn that did something is not quiet', () {
      expect(isQuietFailure(_parse(_quiet('a', 0))), isTrue);
      expect(
        isQuietFailure(_parse(turnJson('x', outcome: 'failed', toolCalls: 1))),
        isFalse,
      );
      expect(
        isQuietFailure(
          _parse(
            turnJson('x', outcome: 'failed', toolCalls: 0, sent: 0, reply: 'm'),
          ),
        ),
        isFalse,
      );
      expect(
        isQuietFailure(
          _parse(
            turnJson(
              'x',
              outcome: 'failed',
              toolCalls: 0,
              sent: 0,
              problemCount: 1,
              problems: [
                {'at': 1, 'kind': 'x', 'reason': 'call_failed'},
              ],
            ),
          ),
        ),
        isFalse,
      );
      expect(
        isQuietFailure(_parse(turnJson('x', toolCalls: 0, sent: 0))),
        isFalse,
      );
    });

    test('usage-limit turns and plain error turns are not one run', () {
      final items = groupQuietFailures([
        _parse(_quiet('a', 0, limit: true)),
        _parse(_quiet('b', 1, limit: true)),
        _parse(_quiet('c', 2)),
        _parse(_quiet('d', 3)),
      ]);
      expect(items.map((i) => i.turns?.length), [2, 2]);
    });
  });

  group('overview', () {
    testWidgets('a usage-limit run is one entry, "Show each turn" opens it', (
      tester,
    ) async {
      final reset = turnsT0 + 300 * 60000;
      final pages = [
        [
          _quiet('q3', 22, limit: true, resetsAt: reset),
          _quiet('q2', 21, limit: true),
          _quiet('q1', 20, limit: true),
          turnJson('ok', reply: 'm'),
        ],
      ];
      final h = await overviewWorkspace(
        tester,
        queryRoutes: summaryRoutes(() => pages),
      );
      await pumpOverview(tester, h);
      expect(
        find.byKey(const ValueKey('activity-overview-retries')),
        findsOneWidget,
      );
      // The newest report of a reset wins; three attempts.
      expect(
        find.textContaining('Usage limit reached · resets '),
        findsOneWidget,
      );
      expect(find.textContaining('3 attempts'), findsOneWidget);
      expect(find.byKey(const ValueKey('turn-q1')), findsNothing);
      expect(find.text('Show each turn'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('activity-overview-retries-toggle')),
      );
      await tester.pumpAndSettle();
      for (final id in ['q1', 'q2', 'q3']) {
        expect(find.byKey(ValueKey('turn-$id')), findsOneWidget);
      }
      expect(find.text('Hide turns'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('activity-overview-retries-toggle')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('turn-q1')), findsNothing);
    });

    testWidgets('a usage limit with no reset time says only the attempts', (
      tester,
    ) async {
      final pages = [
        [_quiet('q2', 21, limit: true), _quiet('q1', 20, limit: true)],
      ];
      final h = await overviewWorkspace(
        tester,
        queryRoutes: summaryRoutes(() => pages),
      );
      await pumpOverview(tester, h);
      expect(find.text('Usage limit reached · 2 attempts'), findsOneWidget);
    });

    testWidgets(
      'error retries without a limit say how many, and a lone one stays a turn',
      (tester) async {
        final pages = [
          [
            _quiet('q3', 22),
            _quiet('q2', 21),
            turnJson('ok', minutes: 10, reply: 'm'),
            _quiet('lone', 0),
          ],
        ];
        final h = await overviewWorkspace(
          tester,
          queryRoutes: summaryRoutes(() => pages),
        );
        await pumpOverview(tester, h);
        expect(
          find.text(
            '2 turns in a row ended with an error, with no tools used and no message sent',
          ),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('turn-lone')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('activity-overview-retries')),
          findsOneWidget,
        );
      },
    );
  });
}
