import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

// A tap on the middle of a paused video card must toggle playback at every card
// size. The control bar is 112 px tall and anchored to the bottom; on a phone
// the card is only ~170 px tall (width 300, 16:9), so the bar's region reaches
// past the middle of the picture. Its hover region used to be hit-opaque and
// swallowed the tap (no recognizer in it), so the centre play button did
// nothing. A card of the maximum 448 px width (252 px tall) never showed it.
void main() {
  Future<int> tapMiddle(
    WidgetTester tester, {
    required double width,
    bool touch = true,
    bool playing = false,
  }) async {
    var toggles = 0;
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              height: (width * 9 / 16).roundToDouble(),
              child: RaftVideoOverlay(
                filename: 'clip.mp4',
                touch: touch,
                ready: true,
                playing: playing,
                position: const Duration(seconds: 3),
                duration: const Duration(seconds: 20),
                onTogglePlay: () => toggles++,
                onSeek: (_) {},
                onVolume: (_) {},
                child: const ColoredBox(color: Color(0xFF3D5A79)),
              ),
            ),
          ),
        ),
      ),
    );
    // The bar is up (paused) and the centre play button is drawn.
    if (!playing) {
      expect(find.byKey(const Key('inline-video-bar')), findsOneWidget);
      if (touch)
        expect(find.byKey(const Key('inline-video-play')), findsOneWidget);
    }
    await tester.tapAt(
      tester.getCenter(find.byKey(const Key('inline-video-surface'))),
    );
    await tester.pump();
    return toggles;
  }

  for (final width in [220.0, 299.0, 360.0, 411.0, 448.0]) {
    testWidgets(
      'paused, touch: a tap in the middle of a ${width.toInt()} px card plays',
      (tester) async {
        expect(await tapMiddle(tester, width: width), 1);
      },
    );
  }

  testWidgets(
    'paused, mouse: a click in the middle of a phone-sized card plays',
    (tester) async {
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      expect(await tapMiddle(tester, width: 299, touch: false), 1);
    },
  );

  testWidgets('the bar\'s own buttons still take their taps, not the picture', (
    tester,
  ) async {
    var overlay = 0, toggles = 0;
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              height: 203,
              child: RaftVideoOverlay(
                filename: 'clip.mp4',
                touch: true,
                ready: true,
                playing: false,
                position: const Duration(seconds: 3),
                duration: const Duration(seconds: 20),
                onTogglePlay: () => toggles++,
                onSeek: (_) {},
                onVolume: (_) {},
                onOpen: () => overlay++,
                child: const ColoredBox(color: Color(0xFF3D5A79)),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('inline-video-open')));
    await tester.pump();
    expect(overlay, 1);
    expect(toggles, 0);
    await tester.tap(find.byKey(const Key('inline-video-toggle')));
    await tester.pump();
    expect(toggles, 1);
  });

  testWidgets('buffering shows a light spinner (not the play button)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              height: 169,
              child: RaftVideoOverlay(
                filename: 'clip.mp4',
                touch: true,
                ready: true,
                buffering: true,
                position: const Duration(seconds: 3),
                duration: const Duration(seconds: 20),
                child: const ColoredBox(color: Color(0xFF000000)),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('inline-video-buffering')), findsOneWidget);
    expect(find.byKey(const Key('inline-video-play')), findsNothing);
    // On the black stage the spinner is white, whatever the theme's ink is.
    final painter =
        tester
                .widget<CustomPaint>(
                  find
                      .descendant(
                        of: find.byKey(const Key('inline-video-buffering')),
                        matching: find.byType(CustomPaint),
                      )
                      .first,
                )
                .painter
            as dynamic;
    expect(painter.color, const Color(0xFFFFFFFF));
  });
}
