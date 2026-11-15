// Web v1.24 ActivityOperatorEvents.tsx + operatorEventsTimeline.ts: what
// people did to the agent shows between the overview's turns, three or more in
// a row fold, Raft's own restarts are fainter, and a viewer who may not read
// them (403) or a server without the route sees the turns alone.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/agent_operator_events.dart';

import 'support/agent_overview_fixture.dart';

Map<String, dynamic> _event(
  String id,
  int minutes,
  String kind, {
  String? name = 'Kevin',
  bool system = false,
  Map<String, dynamic>? details,
}) => {
  'id': id,
  'at': turnsT0 + minutes * 60000,
  'kind': kind,
  'actor': system ? {'kind': 'system'} : {'kind': 'user', 'name': name},
  'details': ?details,
};

final _pages = [
  [
    turnJson('t2', minutes: 40, reply: 'm2'),
    turnJson('t1', minutes: 0, reply: 'm1'),
  ],
];

void main() {
  group('timeline', () {
    AgentOperatorEvent e(int at) =>
        AgentOperatorEvent(id: 'e$at', at: at, kind: 'stop', system: false);

    test(
      'a run of events sits before the first turn that started after it',
      () {
        final turns = [10, 20, 30];
        final result = interleaveOperatorEvents<int>(turns, [
          e(25),
          e(5),
          e(12),
          e(99),
        ], (t) => t);
        String name(OverviewSegment<int> s) => switch (s) {
          TurnsSegment<int>(:final turns) => 'turns$turns',
          EventsSegment<int>(:final events) =>
            'events${events.map((e) => e.at)}',
        };
        expect(result.segments.map(name), [
          'events(5)',
          'turns[10]',
          'events(12)',
          'turns[20]',
          'events(25)',
          'turns[30]',
        ]);
        expect(result.after.map((e) => e.at), [99]);
      },
    );

    test('a kind the overview cannot word is dropped, the rest kept', () {
      final events = AgentOperatorEvent.parsePage({
        'events': [
          _event('a', 1, 'start'),
          _event('b', 2, 'something_new'),
          'not an event',
        ],
        'truncated': false,
      });
      expect(events.map((e) => e.id), ['a']);
    });
  });

  group('overview', () {
    testWidgets('events interleave between turns, in words', (tester) async {
      final h = await overviewWorkspace(
        tester,
        queryRoutes: summaryRoutes(
          () => _pages,
          onOperatorEvents: (_) => {
            'events': [
              _event('e2', 60, 'restart'),
              _event('e1', 20, 'stop', name: null),
            ],
            'truncated': false,
          },
        ),
      );
      await pumpOverview(tester, h);
      // A person Raft no longer names reads "Someone".
      expect(find.text('Someone stopped the agent'), findsOneWidget);
      expect(find.text('Kevin restarted the agent'), findsOneWidget);
      final stop = tester.getTopLeft(find.text('Someone stopped the agent')).dy;
      expect(turnTop(tester, 't1'), lessThan(stop));
      expect(stop, lessThan(turnTop(tester, 't2')));
      // After the last turn, before the Now card.
      final restart = tester
          .getTopLeft(find.text('Kevin restarted the agent'))
          .dy;
      expect(turnTop(tester, 't2'), lessThan(restart));
      expect(
        restart,
        lessThan(
          tester.getTopLeft(find.byKey(const ValueKey('agent-now-card'))).dy,
        ),
      );
    });

    testWidgets('each kind has its words', (tester) async {
      final h = await overviewWorkspace(
        tester,
        queryRoutes: summaryRoutes(
          () => _pages,
          onOperatorEvents: (_) => {
            'events': [
              _event('a', 1, 'start'),
              _event(
                'b',
                2,
                'migration_started',
                details: {'fromComputer': 'Mac', 'toComputer': 'Box'},
              ),
            ],
          },
        ),
      );
      await pumpOverview(tester, h);
      expect(find.text('Kevin started the agent'), findsOneWidget);
      expect(
        find.text('Kevin started moving the agent from Mac to Box'),
        findsOneWidget,
      );
    });

    testWidgets('three or more in a row fold into one line that opens', (
      tester,
    ) async {
      final h = await overviewWorkspace(
        tester,
        queryRoutes: summaryRoutes(
          () => _pages,
          onOperatorEvents: (_) => {
            'events': [
              _event('a', 10, 'stop'),
              _event('b', 11, 'start'),
              _event('c', 12, 'restart'),
            ],
          },
        ),
      );
      await pumpOverview(tester, h);
      expect(
        find.byKey(const ValueKey('activity-overview-operator-events-folded')),
        findsOneWidget,
      );
      expect(
        find.text('3 actions · latest: Kevin restarted the agent'),
        findsOneWidget,
      );
      expect(find.text('Kevin stopped the agent'), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey('activity-overview-operator-events-toggle')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Kevin stopped the agent'), findsOneWidget);
      expect(find.text('Kevin started the agent'), findsOneWidget);
    });

    testWidgets('two in a row stay as lines, not a fold', (tester) async {
      final h = await overviewWorkspace(
        tester,
        queryRoutes: summaryRoutes(
          () => _pages,
          onOperatorEvents: (_) => {
            'events': [_event('a', 10, 'stop'), _event('b', 11, 'start')],
          },
        ),
      );
      await pumpOverview(tester, h);
      expect(
        find.byKey(const ValueKey('activity-overview-operator-events-folded')),
        findsNothing,
      );
      expect(find.text('Kevin stopped the agent'), findsOneWidget);
    });

    testWidgets('Raft\'s own restart is fainter and names no one', (
      tester,
    ) async {
      final h = await overviewWorkspace(
        tester,
        queryRoutes: summaryRoutes(
          () => _pages,
          onOperatorEvents: (_) => {
            'events': [
              _event('a', 10, 'system_restart', system: true),
              _event('b', 20, 'stop'),
            ],
          },
        ),
      );
      await pumpOverview(tester, h);
      final system = find.text('Raft restarted the agent after failed starts');
      expect(system, findsOneWidget);
      double opacityOf(Finder f) => tester
          .widgetList<Opacity>(
            find.ancestor(of: f, matching: find.byType(Opacity)),
          )
          .map((o) => o.opacity)
          .fold(1.0, (a, b) => a * b);
      expect(opacityOf(system), closeTo(.6, 0.001));
      expect(opacityOf(find.text('Kevin stopped the agent')), 1.0);
    });

    testWidgets('a refusal (403) leaves the turns alone, with no error', (
      tester,
    ) async {
      final h = await overviewWorkspace(
        tester,
        queryRoutes: summaryRoutes(
          () => _pages,
          onOperatorEvents: (_) =>
              throw const RaftApiException('forbidden', status: 403),
        ),
      );
      await pumpOverview(tester, h);
      expect(find.byKey(const ValueKey('turn-t1')), findsOneWidget);
      expect(find.text("Couldn't load the overview."), findsNothing);
      expect(
        h.w.queries.where((q) => q.$1 == '/agents/a/operator-events'),
        isNotEmpty,
      );
    });

    testWidgets(
      'events are asked for as far back as the turns held, all once no page is left',
      (tester) async {
        var pages = [
          [turnJson('t2', minutes: 40, reply: 'm2')],
          [turnJson('t1', minutes: 0, reply: 'm1')],
        ];
        final h = await overviewWorkspace(
          tester,
          queryRoutes: summaryRoutes(
            () => pages,
            onOperatorEvents: (_) => {'events': <Object?>[]},
          ),
        );
        await pumpOverview(tester, h);
        List<Object?> asks() => h.w.queries
            .where((q) => q.$1 == '/agents/a/operator-events')
            .map((q) => q.$2?['since'])
            .toList();
        // More pages remain: since the oldest turn held.
        expect(asks(), ['${turnsT0 + 40 * 60000}']);
        await tester.tap(
          find.byKey(const ValueKey('activity-overview-load-more')),
        );
        await tester.pumpAndSettle();
        // No page left: every event.
        expect(asks().last, isNull);
      },
    );
  });
}
