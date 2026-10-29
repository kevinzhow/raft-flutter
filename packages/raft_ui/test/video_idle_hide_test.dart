import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

// Desktop: a playing video hides its controls after the pointer rests for
// three seconds, and any movement brings them back.
void main() {
  const bar = Key('inline-video-bar');
  const idle = Duration(seconds: 3);

  Future<void> pump(
    WidgetTester tester, {
    bool playing = true,
    bool ready = true,
  }) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 640,
              height: 360,
              child: RaftVideoOverlay(
                key: const Key('overlay'),
                filename: 'clip.mp4',
                touch: false,
                ready: ready,
                playing: playing,
                position: const Duration(seconds: 30),
                duration: const Duration(seconds: 120),
                onTogglePlay: () {},
                onSeek: (_) {},
                onVolume: (_) {},
                child: const ColoredBox(
                  key: Key('surface'),
                  color: Color(0xFF3D5A79),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<TestGesture> mouseAt(WidgetTester tester, Offset at) async {
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(2, 2));
    addTearDown(mouse.removePointer);
    await mouse.moveTo(at);
    await tester.pump();
    return mouse;
  }

  Offset picture(WidgetTester tester) =>
      tester.getTopLeft(find.byKey(const Key('surface'))) +
      const Offset(40, 40);

  testWidgets('playing: a resting pointer hides the bar after 3 s, a move '
      'shows it and restarts the timer', (tester) async {
    await pump(tester);
    final mouse = await mouseAt(tester, picture(tester));
    expect(find.byKey(bar), findsOneWidget);
    await tester.pump(idle - const Duration(milliseconds: 100));
    expect(find.byKey(bar), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(bar), findsNothing);
    // Any movement over the picture brings it back ...
    await mouse.moveBy(const Offset(10, 0));
    await tester.pump();
    expect(find.byKey(bar), findsOneWidget);
    // ... and the 3 s count starts again from that move.
    await tester.pump(idle - const Duration(milliseconds: 100));
    expect(find.byKey(bar), findsOneWidget);
    await mouse.moveBy(const Offset(10, 0));
    await tester.pump(idle - const Duration(milliseconds: 100));
    expect(find.byKey(bar), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(bar), findsNothing);
  });

  testWidgets('leaving the picture still hides the bar at once', (
    tester,
  ) async {
    await pump(tester);
    final mouse = await mouseAt(tester, picture(tester));
    expect(find.byKey(bar), findsOneWidget);
    await mouse.moveTo(const Offset(790, 590));
    await tester.pump();
    expect(find.byKey(bar), findsNothing);
    // Coming back shows it again, with a fresh timer.
    await mouse.moveTo(picture(tester));
    await tester.pump();
    expect(find.byKey(bar), findsOneWidget);
    await tester.pump(idle);
    expect(find.byKey(bar), findsNothing);
  });

  testWidgets(
    'paused: the bar never auto-hides; playing again arms the timer',
    (tester) async {
      await pump(tester, playing: false);
      await mouseAt(tester, picture(tester));
      await tester.pump(idle * 3);
      expect(find.byKey(bar), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
      await pump(tester);
      await tester.pump(idle - const Duration(milliseconds: 100));
      expect(find.byKey(bar), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(bar), findsNothing);
      // Pausing brings it back and cancels the timer.
      await pump(tester, playing: false);
      expect(find.byKey(bar), findsOneWidget);
      await tester.pump(idle * 2);
      expect(find.byKey(bar), findsOneWidget);
    },
  );

  testWidgets('a video that is not ready arms no timer', (tester) async {
    await pump(tester, ready: false);
    await mouseAt(tester, picture(tester));
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pump(idle * 2);
    expect(find.byKey(bar), findsNothing);
  });

  testWidgets('the pointer on the bar keeps it; leaving the bar restarts the '
      'count', (tester) async {
    await pump(tester);
    final mouse = await mouseAt(tester, picture(tester));
    final toggle = tester.getCenter(
      find.byKey(const Key('inline-video-toggle')),
    );
    await mouse.moveTo(toggle);
    await tester.pump();
    await mouse.moveBy(const Offset(1, 0));
    await tester.pump(idle * 3);
    expect(find.byKey(bar), findsOneWidget);
    // Back onto the picture: the 3 s count starts there.
    await mouse.moveTo(picture(tester));
    await tester.pump(idle - const Duration(milliseconds: 100));
    expect(find.byKey(bar), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(bar), findsNothing);
  });

  testWidgets('dragging the seek rail or the volume keeps the bar', (
    tester,
  ) async {
    await pump(tester);
    final mouse = await mouseAt(tester, picture(tester));
    final rail = tester.getRect(find.byKey(const Key('inline-video-seek')));
    await mouse.moveTo(Offset(rail.left + 40, rail.center.dy));
    await tester.pump();
    await mouse.down(Offset(rail.left + 40, rail.center.dy));
    await mouse.moveBy(const Offset(30, 0));
    await tester.pump();
    // The pointer wanders off the bar while the button is still held.
    await mouse.moveTo(picture(tester));
    await tester.pump(idle * 2);
    expect(find.byKey(bar), findsOneWidget);
    await mouse.up();
    await tester.pump();
    await tester.pump(idle - const Duration(milliseconds: 100));
    expect(find.byKey(bar), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(bar), findsNothing);
  });

  testWidgets('touch is unchanged: no hover timer, the tap timer rules', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: RaftVideoOverlay(
            filename: 'clip.mp4',
            touch: true,
            playing: true,
            duration: const Duration(seconds: 120),
            child: const ColoredBox(color: Color(0xFF3D5A79)),
          ),
        ),
      ),
    );
    expect(find.byKey(bar), findsNothing);
    await tester.tap(find.byKey(const Key('inline-video-surface')));
    await tester.pump();
    expect(find.byKey(bar), findsOneWidget);
    await tester.pump(idle);
    expect(find.byKey(bar), findsNothing);
  });

  testWidgets('disposing the video cancels the rest timer', (tester) async {
    await pump(tester);
    await mouseAt(tester, picture(tester));
    expect(find.byKey(bar), findsOneWidget);
    // The armed timer would trip the end-of-test pending-timer check.
    await tester.pumpWidget(const SizedBox());
    expect(tester.binding.transientCallbackCount, 0);
  });
}
