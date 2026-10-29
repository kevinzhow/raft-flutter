import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:raft_flutter/features/message_preparation.dart';

void main() {
  testWidgets('an active ticker cannot spin idle retries or block input', (
    tester,
  ) async {
    final scheduler = tester.binding;
    final previousStrategy = scheduler.schedulingStrategy;
    var idlePolls = 0, completed = 0, taps = 0;
    // Bound the old zero-delay retry loop so this regression fails promptly
    // instead of hanging the test runner. A real idle task must remain paused
    // for the whole animation, regardless of how often admission is polled.
    scheduler.schedulingStrategy = ({required priority, required scheduler}) {
      if (priority == Priority.idle.value) return ++idlePolls >= 3;
      return defaultSchedulingStrategy(
        priority: priority,
        scheduler: scheduler,
      );
    };
    final ticker = Ticker((_) {})..start();
    final owner = MessagePreparation(isIdle: () => true);
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: TextButton(onPressed: () => taps++, child: const Text('Tap')),
        ),
      );
      owner.replace([() => completed++]);
      await tester.pump(const Duration(milliseconds: 750));
      expect(completed, 0, reason: 'Preparation waits for animation to finish');
      await tester.tap(find.text('Tap'));
      await tester.pump();
      expect(taps, 1, reason: 'Input remains responsive while waiting');
      ticker.stop();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 250));
      expect(
        completed,
        1,
        reason: 'Retained preparation resumes after animation',
      );
    } finally {
      owner.dispose();
      ticker.dispose();
      scheduler.schedulingStrategy = previousStrategy;
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('preparation waits through route entry and predictive Back', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        theme: ThemeData(platform: TargetPlatform.android),
        home: const SizedBox(),
      ),
    );
    final route = MaterialPageRoute<void>(
      allowSnapshotting: false,
      builder: (_) => const ColoredBox(color: Colors.white),
    );
    navigator.currentState!.push(route);
    await tester.pump();
    var completed = 0;
    final owner = MessagePreparation(
      isIdle: () => messagePreparationRouteIsIdle(route),
      scheduleIdle: (job) => job(),
    );
    owner.replace([() => completed++]);
    await tester.pump(const Duration(milliseconds: 250));
    expect(completed, 0);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 250));
    expect(completed, 1);

    Future<void> gesture(String method, [double? progress]) async {
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'flutter/backgesture',
        const StandardMethodCodec().encodeMethodCall(
          MethodCall(
            method,
            progress == null
                ? null
                : <String, dynamic>{
                    'touchOffset': <double>[100, 300],
                    'progress': progress,
                    'swipeEdge': 0,
                  },
          ),
        ),
        (_) {},
      );
      await tester.pump();
    }

    await gesture('startBackGesture', 0);
    await gesture('updateBackGestureProgress', .4);
    expect(route.navigator!.userGestureInProgress, isTrue);
    owner.replace([() => completed++]);
    await tester.pump(const Duration(milliseconds: 250));
    expect(completed, 1, reason: 'A held platform gesture is not idle');
    await gesture('cancelBackGesture');
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 250));
    expect(completed, 2, reason: 'Canceled Back resumes retained preparation');
    owner.dispose();
    await tester.pumpWidget(const SizedBox());
  });

  Future<void> advance(WidgetTester tester, Duration duration) async {
    await tester.pump(duration);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  }

  testWidgets(
    'preparation waits for quiet input and runs one message at a time',
    (tester) async {
      var idle = false;
      final completed = <int>[];
      final owner = MessagePreparation(isIdle: () => idle);
      owner.replace([for (var i = 0; i < 3; i++) () => completed.add(i)]);
      await advance(tester, const Duration(milliseconds: 250));
      expect(completed, isEmpty);
      idle = true;
      await advance(tester, const Duration(milliseconds: 250));
      expect(completed, [0]);
      idle = false;
      await advance(tester, const Duration(milliseconds: 16));
      expect(completed, [0]);
      idle = true;
      await advance(tester, const Duration(milliseconds: 250));
      expect(completed, [0, 1]);
      owner.dispose();
    },
  );

  testWidgets('authority replacement and disposal retire even scheduled work', (
    tester,
  ) async {
    final completed = <String>[];
    final pending = <VoidCallback>[];
    final owner = MessagePreparation(
      isIdle: () => true,
      scheduleIdle: pending.add,
    );
    owner.replace([() => completed.add('old authority')]);
    await tester.pump(const Duration(milliseconds: 250));
    expect(pending, hasLength(1));
    owner.replace([() => completed.add('new authority')]);
    pending.removeAt(0)();
    expect(completed, isEmpty);
    await tester.pump(const Duration(milliseconds: 250));
    pending.removeAt(0)();
    expect(completed, ['new authority']);
    owner.replace([() => completed.add('disposed')]);
    await tester.pump(const Duration(milliseconds: 250));
    owner.dispose();
    pending.removeAt(0)();
    expect(completed, ['new authority']);
  });

  testWidgets('preparation bounds the retained batch to 64 messages', (
    tester,
  ) async {
    var completed = 0;
    final owner = MessagePreparation(isIdle: () => true);
    owner.replace([for (var i = 0; i < 1000; i++) () => completed++]);
    await advance(tester, const Duration(milliseconds: 250));
    for (var i = 0; i < 70; i++) {
      await advance(tester, const Duration(milliseconds: 16));
    }
    expect(completed, 64);
    owner.dispose();
  });
}
