import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/agent_activity_summaries.dart';
import 'package:raft_flutter/features/agent_detail_view.dart';

import 'support/agent_panel_fixture.dart';

final _t0 = DateTime.utc(2026, 10, 24, 2, 38).millisecondsSinceEpoch;

Map<String, dynamic> _turn(
  String id, {
  String outcome = 'completed',
  int problemCount = 0,
  List<Map<String, dynamic>> problems = const [],
  List<Map<String, dynamic>> actions = const [],
  Object? trigger,
  String? reply,
  int sent = 1,
  int minutes = 0,
}) => {
  'id': id,
  'startedAt': _t0 + minutes * 60000,
  'endedAt': _t0 + minutes * 60000 + 6 * 60000,
  'outcome': outcome,
  'problemCount': problemCount,
  'problems': problems,
  'actions': actions,
  'toolCalls': 4,
  'messagesSent': sent,
  'trigger': ?trigger,
  'lastReplyMessageId': ?reply,
};

Map<String, Object? Function(Map<String, dynamic>? q)> _summaries(
  List<List<Map<String, dynamic>>> pages,
) => {
  '/agents/a/activity-summaries': (q) {
    final index = q?['before'] == null ? 0 : int.parse('${q!['before']}');
    return {
      'summaries': pages[index],
      if (index + 1 < pages.length) 'next': '${index + 1}',
    };
  },
};

Future<(AgentPanelWorkspace, AgentPanelClient)> _open(
  WidgetTester tester, {
  Set<String> flags = const {'activity_overview_web_v0'},
  Map<String, Object? Function(Map<String, dynamic>? q)> queryRoutes = const {},
  Map<String, Object? Function()> routes = const {},
  Map<String, dynamic> agent = agentPanelAgent,
}) => pumpAgentPanel(
  tester,
  agent: agent,
  flags: flags,
  tab: AgentDetailTab.activity,
  queryRoutes: queryRoutes,
  routes: routes,
  actions: AgentDetailActions(onOpenComputer: (_) {}),
);

void main() {
  group('turn wording', () {
    test('formatClockRange keeps one day period, one time for one minute', () {
      expect(formatClockRange('02:38', '02:44'), (
        start: '02:38',
        end: '02:44',
      ));
      expect(formatClockRange('02:38', '02:38'), (start: '02:38', end: null));
      expect(formatClockRange('2:38 AM', '2:44 AM'), (
        start: '2:38',
        end: '2:44 AM',
      ));
      expect(formatClockRange('上午2:38', '上午2:44'), (
        start: '上午2:38',
        end: '2:44',
      ));
    });

    test('actions join like Intl.ListFormat', () {
      expect(joinConjunction(['a'], chinese: false), 'a');
      expect(joinConjunction(['a', 'b'], chinese: false), 'a and b');
      expect(joinConjunction(['a', 'b', 'c'], chinese: false), 'a, b, and c');
      expect(joinConjunction(['a', 'b', 'c'], chinese: true), 'a、b和c');
    });

    test('only a tool call that itself failed counts as a problem', () {
      final turn = TurnSummary.tryParse(
        _turn(
          't',
          problemCount: 4,
          problems: [
            {'at': 1, 'kind': 'run_checks', 'reason': 'exit_nonzero'},
            {
              'at': 2,
              'kind': 'run_command',
              'reason': 'exit_nonzero',
              'exitCode': 2,
            },
            {'at': 3, 'kind': 'run_command', 'reason': 'send_held'},
            {'at': 4, 'kind': 'read_file', 'reason': 'call_failed'},
          ],
        ),
      )!;
      // Web countsAsProblem: exits and held sends are ordinary work.
      expect(turn.problems.map((p) => p.counts), [false, false, false, true]);
      // Web isListedProblem: failing checks stay as process information; a
      // plain exit code and a held send are not listed.
      expect(turn.problems.map((p) => p.listed), [true, false, false, true]);
      expect(turn.problemsShown, 1);
    });

    test('a row without times or an outcome is not a turn', () {
      expect(TurnSummary.tryParse({'startedAt': 1}), isNull);
      expect(TurnSummary.tryParse('x'), isNull);
    });
  });

  group('Activity tab', () {
    // Web 1.24 AgentActivityLog.tsx:647, 704 (`activity_overview_web_v0` is
    // retired): a server that still answers it off gets the Overview too.
    testWidgets('the retired flag answered off still opens on the Overview', (
      tester,
    ) async {
      await _open(
        tester,
        flags: const {},
        queryRoutes: _summaries([
          [_turn('t1')],
        ]),
      );
      expect(find.byKey(const ValueKey('activity-view')), findsOneWidget);
      expect(find.byKey(const ValueKey('activity-overview')), findsOneWidget);
    });

    testWidgets('it opens on the Overview, the raw log one toggle away', (
      tester,
    ) async {
      await _open(
        tester,
        queryRoutes: _summaries([
          [_turn('t1')],
        ]),
        routes: {
          '/agents/a/activity-log': () => [
            {
              'timestamp': _t0,
              'entry': {'kind': 'thinking', 'text': 'pondering'},
            },
          ],
        },
      );
      expect(find.byKey(const ValueKey('activity-view')), findsOneWidget);
      expect(find.byKey(const ValueKey('activity-overview')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('activity-view-raw')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('activity-overview')), findsNothing);
      expect(find.text('pondering'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('activity-view-overview')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('activity-overview')), findsOneWidget);
    });

    testWidgets(
      'each turn: time range, outcome, trigger, actions and the last reply',
      (tester) async {
        await _open(
          tester,
          queryRoutes: {
            ..._summaries([
              [
                _turn(
                  't1',
                  trigger: {'target': 'proj-runtime:ab12', 'sender': 'tenny'},
                  actions: [
                    {'kind': 'run_command', 'count': 3},
                    {'kind': 'read_file', 'count': 1},
                  ],
                  reply: 'm1',
                  sent: 2,
                ),
                _turn(
                  't2',
                  minutes: 20,
                  outcome: 'completed',
                  problemCount: 2,
                  problems: [
                    {
                      'at': _t0,
                      'kind': 'run_command',
                      'reason': 'exit_nonzero',
                      'exitCode': 2,
                    },
                    {'at': _t0, 'kind': 'x', 'reason': 'call_failed'},
                  ],
                  trigger: {'hidden': 'dm'},
                ),
                _turn('t3', minutes: 40, outcome: 'failed'),
                _turn('t4', minutes: 60, outcome: 'interrupted'),
                _turn('t5', minutes: 80, outcome: 'unknown'),
              ],
            ]),
            '/messages/context/m1': (_) => {
              'targetMessageId': 'm1',
              'messages': [
                {
                  'id': 'm1',
                  'content': 'Shipped it.',
                  'createdAt': '2026-10-24T02:44:00.000Z',
                },
              ],
            },
          },
        );
        expect(
          find.byKey(const ValueKey('activity-overview-turn')),
          findsNWidgets(5),
        );
        // Outcomes.
        // A plain finished turn has no badge ("Done" read as "the work is done").
        expect(find.text('Done'), findsNothing);
        expect(find.text('1 step went wrong'), findsOneWidget);
        expect(find.text('Ended with an error'), findsOneWidget);
        expect(find.text('Stopped'), findsOneWidget);
        expect(find.text('Ended, outcome unknown'), findsOneWidget);
        // Trigger and duration, actions, problems, reply.
        expect(
          find.textContaining(
            'replying to @tenny in a thread in proj-runtime · took 6m 0s',
          ),
          findsOneWidget,
        );
        expect(
          find.text('replying to a direct message · took 6m 0s'),
          findsOneWidget,
        );
        expect(find.text('ran 3 commands and read a file'), findsOneWidget);
        expect(find.text('No tool calls'), findsWidgets);
        // Only the failed tool call is listed, not a plain non-zero exit.
        expect(
          find.byKey(const ValueKey('activity-overview-problem-0')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('activity-overview-problem-1')),
          findsOneWidget,
        );
        expect(find.text('Shipped it.'), findsOneWidget);
        expect(
          find.textContaining('2 messages sent this turn'),
          findsOneWidget,
        );
        expect(find.text('No message sent'), findsWidgets);
      },
    );

    testWidgets('earlier turns load a page at a time', (tester) async {
      final (w, _) = await _open(
        tester,
        queryRoutes: _summaries([
          [_turn('t1')],
          [_turn('t0', minutes: -60)],
        ]),
      );
      expect(
        find.byKey(const ValueKey('activity-overview-turn')),
        findsOneWidget,
      );
      final more = find.byKey(const ValueKey('activity-overview-load-more'));
      await tester.ensureVisible(more);
      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('activity-overview-turn')),
        findsNWidgets(2),
      );
      expect(
        find.byKey(const ValueKey('activity-overview-load-more')),
        findsNothing,
      );
      expect(
        w.queries
            .where((q) => q.$1 == '/agents/a/activity-summaries')
            .map((q) => q.$2?['before']),
        [null, '1'],
      );
    });

    testWidgets(
      'a finished turn pushed over the socket refreshes the overview',
      (tester) async {
        var pages = [
          [_turn('t1')],
        ];
        final (_, client) = await _open(
          tester,
          queryRoutes: {
            '/agents/a/activity-summaries': (_) => {'summaries': pages.first},
          },
        );
        expect(
          find.byKey(const ValueKey('activity-overview-turn')),
          findsOneWidget,
        );
        pages = [
          [_turn('t2', minutes: 10), _turn('t1')],
        ];
        client.stream.add(
          const RaftEvent('agent:activity', {'agentId': 'other'}),
        );
        client.stream.add(
          const RaftEvent('agent:activity', {
            'agentId': 'a',
            'isHeartbeat': true,
          }),
        );
        await tester.pump(const Duration(seconds: 1));
        expect(
          find.byKey(const ValueKey('activity-overview-turn')),
          findsOneWidget,
        );
        client.stream.add(const RaftEvent('agent:activity', {'agentId': 'a'}));
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('activity-overview-turn')),
          findsNWidgets(2),
        );
      },
    );

    testWidgets(
      'no turns yet but raw activity: explains and offers the raw log',
      (tester) async {
        await _open(
          tester,
          queryRoutes: _summaries([[]]),
          routes: {
            '/agents/a/activity-log': () => [
              {
                'timestamp': _t0,
                'entry': {'kind': 'thinking', 'text': 'x'},
              },
            ],
          },
        );
        expect(find.text('No overview yet'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('activity-overview-open-computer')),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const ValueKey('activity-overview-show-raw')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('activity-overview-turn')),
          findsNothing,
        );
        expect(find.text('x'), findsOneWidget);
      },
    );

    testWidgets('an external agent has no computer to open', (tester) async {
      await _open(
        tester,
        agent: {
          ...agentPanelAgent,
          'runtime': 'external',
          'external': true,
          'machineId': null,
        },
        queryRoutes: _summaries([[]]),
        routes: {
          '/agents/a/activity-log': () => [
            {
              'timestamp': _t0,
              'entry': {'kind': 'thinking', 'text': 'x'},
            },
          ],
        },
      );
      expect(find.text('No overview yet'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('activity-overview-open-computer')),
        findsNothing,
      );
      expect(
        find.textContaining("hasn't reported a finished turn"),
        findsOneWidget,
      );
    });

    testWidgets('nothing at all is the plain empty state', (tester) async {
      await _open(tester, queryRoutes: _summaries([[]]));
      expect(find.text('No activity yet'), findsOneWidget);
    });

    testWidgets('a failed read says so and Retry reads again', (tester) async {
      var fail = true;
      await _open(
        tester,
        queryRoutes: {
          '/agents/a/activity-summaries': (_) {
            if (fail) throw const RaftApiException('boom', status: 500);
            return {
              'summaries': [_turn('t1')],
            };
          },
        },
      );
      expect(find.text("Couldn't load the overview."), findsOneWidget);
      fail = false;
      await tester.tap(find.byKey(const ValueKey('activity-overview-retry')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('activity-overview-turn')),
        findsOneWidget,
      );
      expect(find.text("Couldn't load the overview."), findsNothing);
    });

    testWidgets('no flag is read from the server', (tester) async {
      final (_, client) = await _open(tester, queryRoutes: _summaries([[]]));
      expect(
        client.writes.where(
          (w) =>
              w.$2 == '/feature-flags/evaluate' &&
              '${w.$3}'.contains('activity_overview_web_v0'),
        ),
        isEmpty,
      );
    });
  });

  testWidgets('a system row of a subagent carries the Subagent badge', (
    tester,
  ) async {
    await _open(
      tester,
      flags: const {},
      routes: {
        '/agents/a/activity-log': () => [
          {
            'timestamp': _t0,
            'entry': {
              'kind': 'system',
              'title': 'Task started',
              'text': 'looking around',
              'subagent': {'subagentType': 'Explore', 'phase': 'started'},
            },
          },
          {
            'timestamp': _t0 + 1000,
            'entry': {
              'kind': 'system',
              'title': 'Compaction',
              'text': 'no lineage here',
            },
          },
          {
            'timestamp': _t0 + 2000,
            'entry': {
              'kind': 'system',
              'title': 'Task progress',
              'text': 'long ' * 60,
              'subagent': {'subagentType': 'Plan', 'phase': 'progress'},
            },
          },
        ],
      },
    );
    await tester.tap(find.byKey(const ValueKey('activity-view-raw')));
    await tester.pumpAndSettle();
    expect(find.text('Subagent: Explore', findRichText: true), findsOneWidget);
    // The expandable (long) row keeps its badge too.
    expect(find.text('Subagent: Plan', findRichText: true), findsOneWidget);
    expect(
      find.textContaining('Subagent', findRichText: true),
      findsNWidgets(2),
    );
  });

  testWidgets('while the first read is out the Now card shows alone', (
    tester,
  ) async {
    await pumpAgentPanel(
      tester,
      flags: const {'activity_overview_web_v0'},
      tab: AgentDetailTab.activity,
      queryRoutes: {
        '/agents/a/activity-summaries': (_) async {
          await Future<void>.delayed(const Duration(seconds: 5));
          return {'summaries': <Object?>[]};
        },
      },
      settle: false,
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('agent-now-card')), findsOneWidget);
    expect(find.byKey(const ValueKey('activity-overview-turn')), findsNothing);
    expect(find.text('No activity yet'), findsNothing);
    await tester.pump(const Duration(seconds: 6));
  });
}
