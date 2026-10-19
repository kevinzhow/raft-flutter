import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/media_browser_previews.dart';
import 'package:raft_ui/raft_ui.dart';

import 'task_typography_test.dart' show loadTaskFonts;

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      'proportional time keeps trailing actions aligned $family/$dark',
      (tester) async {
        // Ahem's wide, square glyphs fill the loose allocation and hide this bug.
        await loadTaskFonts(tester);
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        for (final width in [240.0, 288.0, 320.0, 390.0, 768.0, 1280.0]) {
          for (final touch in [true, false]) {
            for (final extras in [false, true]) {
              for (final long in [false, true]) {
                await tester.pumpWidget(
                  MaterialApp(
                    theme: raftTheme(family, dark: dark),
                    home: Scaffold(
                      body: Center(
                        child: SizedBox(
                          width: width,
                          child: RaftVideoControlBar(
                            filename: 'clip.mp4',
                            playing: false,
                            position: const Duration(seconds: 1),
                            duration: long
                                ? const Duration(
                                    hours: 12,
                                    minutes: 34,
                                    seconds: 56,
                                  )
                                : const Duration(seconds: 2),
                            volume: 100,
                            touch: touch,
                            hovered: true,
                            playLabel: 'Play',
                            onTogglePlay: () {},
                            onMute: () {},
                            onVolume: (_) {},
                            onFullscreen: extras ? () {} : null,
                            onOpen: extras ? () {} : null,
                            onDownload: extras ? () {} : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
                await tester.pump();
                final bar = tester.getRect(find.byType(RaftVideoControlBar));
                final actions =
                    ['mute', 'fullscreen', 'open', 'download-action']
                        .map((name) => find.byKey(Key('inline-video-$name')))
                        .where((finder) => finder.evaluate().isNotEmpty)
                        .toList();
                if (actions.isNotEmpty) {
                  final last = tester.getRect(actions.last);
                  expect(
                    bar.right - last.right,
                    closeTo(3, .01),
                    reason: '$width touch=$touch extras=$extras long=$long',
                  );
                  expect(last.size, const Size(48, 48));
                  final time = tester.getRect(
                    find.byKey(const Key('inline-video-time')),
                  );
                  expect(
                    time.right,
                    lessThanOrEqualTo(tester.getRect(actions.first).left + .01),
                  );
                }
                expect(tester.takeException(), isNull);
              }
            }
          }
        }
      },
    );

    for (final (name, preview, size) in <(String, Widget Function(), Size)>[
      ('compact', videoBrowserCompactPhonePreview, const Size(320, 640)),
      ('phone', videoBrowserPhonePreview, const Size(390, 844)),
      ('landscape', videoBrowserLandscapePreview, const Size(844, 390)),
      ('tablet', videoBrowserTabletPreview, const Size(768, 1024)),
      ('desktop', videoBrowserDesktopPreview, const Size(1280, 800)),
      ('inline', videoInlineControlsPreview, const Size(320, 240)),
    ]) {
      testWidgets('real controls preview $name $family/$dark', (tester) async {
        await loadTaskFonts(tester);
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: Scaffold(body: preview()),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(RaftVideoControlBar), findsOneWidget);
        final mute = find.byKey(const Key('inline-video-mute'));
        await tester.tap(mute);
        await tester.pump();
        expect(find.bySemanticsLabel(RegExp('Unmute video')), findsOneWidget);
        final seek = find.byKey(const Key('inline-video-seek'));
        final rail = tester.getRect(seek);
        final strip = find.byKey(const ValueKey('lightbox-thumbnails'));
        if (strip.evaluate().isNotEmpty) {
          expect(rail.bottom, lessThanOrEqualTo(tester.getRect(strip).top));
        }
        await tester.tapAt(
          Offset(rail.left + rail.width * .75, rail.center.dy),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('mouse volume rail meets the mute target after resize', (
    tester,
  ) async {
    await loadTaskFonts(tester);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    for (final width in [390.0, 768.0, 1280.0]) {
      tester.view.physicalSize = Size(width, 700);
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Scaffold(
            body: RaftVideoViewer(
              filename: 'clip.mp4',
              video: const ColoredBox(color: Colors.black),
              touch: false,
              position: const Duration(seconds: 1),
              duration: const Duration(seconds: 2),
              onVolume: (_) {},
              onDownload: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      final mute = tester.getRect(find.byKey(const Key('inline-video-mute')));
      await mouse.moveTo(mute.center);
      await tester.pump();
      final volume = tester.getRect(
        find.byKey(const Key('inline-video-volume')),
      );
      expect(volume.right, closeTo(mute.left, .01));
      expect(tester.takeException(), isNull);
    }
  });
}
