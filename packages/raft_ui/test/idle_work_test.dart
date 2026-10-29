import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

/// Shared idle-work rules (see idle_work.dart): deferred work never spins
/// through zero-delay retries, perpetual animations stop when hidden, and
/// polls stop while the app cannot be seen.
void main() {
  testWidgets('RaftIdleTimer waits out a ticker without zero-delay retries', (
    tester,
  ) async {
    var idleAdmissions = 0;
    final previous = tester.binding.schedulingStrategy;
    tester.binding.schedulingStrategy = ({required priority, required scheduler}) {
      if (priority == Priority.idle.value) idleAdmissions++;
      return defaultSchedulingStrategy(priority: priority, scheduler: scheduler);
    };
    addTearDown(() => tester.binding.schedulingStrategy = previous);
    final zeroDelay = <Duration>[];
    final ticker = Ticker((_) {})..start();
    addTearDown(ticker.dispose);
    final timer = RaftIdleTimer();
    addTearDown(timer.cancel);
    var ran = 0;
    await runZonedGuarded(
      () async {
        timer.start(Duration.zero, () => ran++);
        // Ten seconds of animation: only a handful of 250 ms polls.
        for (var i = 0; i < 100; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      },
      (e, s) => throw e,
      zoneSpecification: ZoneSpecification(
        createTimer: (self, parent, zone, duration, f) {
          if (duration <= Duration.zero) zeroDelay.add(duration);
          return parent.createTimer(zone, duration, f);
        },
      ),
    );
    expect(ran, 0, reason: 'task waits while a ticker runs');
    expect(zeroDelay, isEmpty, reason: 'never a zero-delay timer');
    expect(idleAdmissions, 0, reason: 'never Priority.idle');
    expect(timer.blockedPolls, inInclusiveRange(4, 40));
    ticker.stop();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    expect(ran, 1, reason: 'runs once the animation has ended');
  });

  testWidgets('RaftIdleTimer clamps the delay and backs off a shut gate', (
    tester,
  ) async {
    var open = false, ran = 0;
    final timer = RaftIdleTimer(
      maxRetry: const Duration(seconds: 1),
      canRun: () => open,
    );
    addTearDown(timer.cancel);
    timer.start(Duration.zero, () => ran++);
    await tester.pump(const Duration(milliseconds: 1));
    expect(timer.blockedPolls, 1, reason: 'positive delay still fires');
    // 60 s with the gate shut: steady polls, then at most one a second.
    await tester.pump(const Duration(seconds: 60));
    expect(timer.blockedPolls, lessThan(70));
    expect(ran, 0);
    open = true;
    await tester.pump(const Duration(seconds: 2));
    expect(ran, 1);
    expect(timer.isActive, isFalse);
  });

  testWidgets('RaftForegroundPeriodic stops while hidden and resumes', (
    tester,
  ) async {
    var ticks = 0;
    final periodic = RaftForegroundPeriodic(
      const Duration(seconds: 10),
      () => ticks++,
    );
    await tester.pump(const Duration(seconds: 35));
    expect(ticks, 3);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(seconds: 20));
    expect(ticks, 5, reason: 'an unfocused but visible window keeps polling');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    expect(periodic.isRunning, isFalse);
    await tester.pump(const Duration(minutes: 10));
    expect(ticks, 5, reason: 'no wake-ups while hidden');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(minutes: 10));
    expect(ticks, 5);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(periodic.isRunning, isTrue);
    expect(ticks, 5, reason: 'resume does not fire; owners refresh on resume');
    await tester.pump(const Duration(seconds: 25));
    expect(ticks, 7);
    periodic.dispose();
  });

  group('perpetual animations stop when their subtree is not shown', () {
    Widget host(Widget child) => MaterialApp(
      theme: raftTheme(),
      home: Scaffold(body: Center(child: child)),
    );
    const animated = <String, Widget>{
      'RaftSpinner': RaftSpinner(),
      'RaftSkeleton': RaftSkeleton(),
      'RaftQuotedMessageSkeleton': RaftQuotedMessageSkeleton(),
      'RaftChatSidebarLoadingRows': RaftChatSidebarLoadingRows(rows: 2),
      'RaftTransferBar': SizedBox(width: 100, child: RaftTransferBar()),
    };
    for (final entry in animated.entries) {
      testWidgets('${entry.key}: ticks only while visible', (tester) async {
        var hidden = false;
        late StateSetter set;
        await tester.pumpWidget(
          host(
            StatefulBuilder(
              builder: (context, setState) {
                set = setState;
                return Visibility(
                  visible: !hidden,
                  maintainState: true,
                  child: entry.value,
                );
              },
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          tester.binding.transientCallbackCount,
          greaterThan(0),
          reason: '${entry.key} animates while visible',
        );
        set(() => hidden = true);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          tester.binding.transientCallbackCount,
          0,
          reason: '${entry.key} must not tick while hidden',
        );
        await tester.pump(const Duration(seconds: 5));
        expect(tester.binding.hasScheduledFrame, isFalse);
      });

      testWidgets('${entry.key}: TickerMode(enabled: false) mutes it', (
        tester,
      ) async {
        await tester.pumpWidget(
          host(TickerMode(enabled: false, child: entry.value)),
        );
        await tester.pump(const Duration(seconds: 5));
        expect(tester.binding.transientCallbackCount, 0);
        expect(tester.binding.hasScheduledFrame, isFalse);
      });

      testWidgets('${entry.key}: stops under reduced motion', (tester) async {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: host(entry.value),
          ),
        );
        await tester.pump(const Duration(seconds: 5));
        expect(tester.binding.transientCallbackCount, 0);
      });
    }

    testWidgets('hidden editor tabs and the folded sidebar do not tick', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          SizedBox(
            width: 600,
            height: 400,
            child: RaftEditorGroups(
              groups: const [
                RaftEditorGroup(
                  id: 'g',
                  selected: 'one',
                  tabs: [
                    RaftEditorTab(id: 'one', label: 'One', child: Text('One')),
                    RaftEditorTab(
                      id: 'two',
                      label: 'Two',
                      child: Center(child: RaftSpinner()),
                    ),
                  ],
                ),
              ],
              onSelect: (_, _) {},
              onClose: (_) {},
              onMove: (_, _) {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 3));
      expect(
        tester.binding.transientCallbackCount,
        0,
        reason: 'the spinner lives in the unselected tab',
      );
    });
  });
}
