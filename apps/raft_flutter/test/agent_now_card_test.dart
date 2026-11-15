// Web v1.24 AgentNowCard.tsx: the headline ("Working · for 2m 14s" with a
// one-second tick only while it is on screen; "Idle · last turn ended …"), the
// step line, the focus line and Ottie's pose.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/agent_activity_summaries.dart';
import 'package:raft_flutter/features/agent_now_card.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/agent_overview_fixture.dart';

TurnSummary _running(int startedMinutes) => TurnSummary.tryParse({
  'id': 'run',
  'startedAt': turnsT0 + startedMinutes * 60000,
  'endedAt': turnsT0 + startedMinutes * 60000 + 1000,
  'actions': [
    {'kind': 'run_command', 'count': 2},
  ],
  'messagesSent': 0,
  'trigger': {'target': 'proj-runtime:ab12', 'sender': 'tenny'},
}, running: true)!;

TurnSummary _done(String id, int minutes, {String? reply}) =>
    TurnSummary.tryParse(
      turnJson(
        id,
        minutes: minutes,
        reply: reply,
        trigger: {
          'display': {
            'kind': 'channel',
            'channelName': 'deploy',
            'senderName': 'remy',
          },
        },
        actions: [
          {'kind': 'run_command', 'count': 3},
        ],
      ),
    )!;

/// "Idle · last turn ended 02:04" (the clock face depends on the locale).
Finder _idleToday() => find.byWidgetPredicate(
  (w) =>
      w is Text &&
      w.data != null &&
      RegExp(r'^Idle · last turn ended \d{1,2}:\d{2}( [AP]M)?$')
          .hasMatch(w.data!),
);

Future<void> _pump(
  WidgetTester tester,
  OverviewHarness h, {
  required String activity,
  String activityText = 'Running tests',
  List<TurnSummary> turns = const [],
  TurnSummary? running,
  DateTime Function()? clock,
  bool visible = true,
  Widget? status,
}) => tester.pumpWidget(
  MaterialApp(
    theme: raftTheme(),
    home: Scaffold(
      body: TickerMode(
        enabled: visible,
        child: AgentNowCard(
          controller: h.w,
          activity: activity,
          activityText: activityText,
          turns: turns,
          running: running,
          clock: clock ?? fixtureNow,
          status: status,
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets(
    'working with a running turn counts on from its start, a second at a time',
    (tester) async {
      final h = await overviewWorkspace(tester);
      var nowMs = turnsT0 + 2 * 60000 + 14000;
      DateTime clock() =>
          DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true);
      await _pump(
        tester,
        h,
        activity: 'working',
        running: _running(0),
        clock: clock,
      );
      expect(find.text('Working · for 2m 14s'), findsOneWidget);
      // The step it is on, then the turn it answers.
      expect(find.text('Running tests'), findsOneWidget);
      expect(
        find.text(
          'replying to @tenny in a thread in proj-runtime · ran 2 commands',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('agent-now-focus')), findsOneWidget);
      nowMs += 3000;
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Working · for 2m 17s'), findsOneWidget);
      nowMs += 1000;
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Working · for 2m 18s'), findsOneWidget);
    },
  );

  testWidgets(
    'the tick stops while the card is not visible and again when the app is hidden',
    (tester) async {
      final h = await overviewWorkspace(tester);
      var nowMs = turnsT0 + 60000;
      DateTime clock() =>
          DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true);
      await _pump(
        tester,
        h,
        activity: 'working',
        running: _running(0),
        clock: clock,
        visible: false,
      );
      expect(find.text('Working · for 1m 0s'), findsOneWidget);
      nowMs += 5000;
      await tester.pump(const Duration(seconds: 3));
      // A hidden (tab kept alive) card does not wake every second.
      expect(find.text('Working · for 1m 0s'), findsOneWidget);
      // Shown again: it counts.
      await _pump(
        tester,
        h,
        activity: 'working',
        running: _running(0),
        clock: clock,
      );
      expect(find.text('Working · for 1m 5s'), findsOneWidget);
      nowMs += 1000;
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Working · for 1m 6s'), findsOneWidget);
      // The window is minimised: no tick.
      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      nowMs += 5000;
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Working · for 1m 6s'), findsOneWidget);
      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
    },
  );

  testWidgets('an idle agent says when its last turn ended and what it was', (
    tester,
  ) async {
    final h = await overviewWorkspace(tester);
    await _pump(
      tester,
      h,
      activity: 'online',
      turns: [_done('t1', 0, reply: 'm1')],
    );
    expect(_idleToday(), findsOneWidget);
    expect(
      find.text('Last turn: @remy · #deploy · ran 3 commands'),
      findsOneWidget,
    );
    // No ticker: it is not counting anything.
    expect(find.byKey(const ValueKey('agent-now-step')), findsNothing);
  });

  testWidgets('a turn from another day is dated, not a bare clock time', (
    tester,
  ) async {
    final h = await overviewWorkspace(tester);
    final tomorrow = fixtureNow().add(const Duration(days: 2));
    await _pump(
      tester,
      h,
      activity: 'online',
      turns: [_done('t1', 0)],
      clock: () => tomorrow,
    );
    expect(_idleToday(), findsNothing);
    expect(
      find.textContaining('Idle · last turn ended Oct 24'),
      findsOneWidget,
    );
  });

  testWidgets(
    'any other state reads as the header does, and Ottie follows it',
    (tester) async {
      final h = await overviewWorkspace(tester);
      await _pump(
        tester,
        h,
        activity: 'error',
        activityText: 'Usage limit reached',
      );
      expect(find.text('Usage limit reached'), findsOneWidget);
      expect(find.byKey(const ValueKey('agent-now-focus')), findsNothing);
      expect(
        find.byKey(const ValueKey('raft-otter-indicator')),
        findsOneWidget,
      );
      await _pump(tester, h, activity: 'offline', activityText: 'Offline');
      expect(find.text('Offline'), findsOneWidget);
    },
  );

  testWidgets(
    'with a status chip the chip is the first line, with no headline or tick',
    (tester) async {
      final h = await overviewWorkspace(tester);
      await _pump(
        tester,
        h,
        activity: 'working',
        running: _running(0),
        status: const Text('the chip'),
      );
      expect(find.text('the chip'), findsOneWidget);
      expect(find.byKey(const ValueKey('agent-now-headline')), findsNothing);
      expect(find.byKey(const ValueKey('agent-now-step')), findsNothing);
      // The focus line still says what the running turn answers.
      expect(find.byKey(const ValueKey('agent-now-focus')), findsOneWidget);
    },
  );
}
