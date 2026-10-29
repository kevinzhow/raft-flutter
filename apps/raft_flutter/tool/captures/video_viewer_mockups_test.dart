// Renders the media-viewer video player from the real raft_ui widgets for
// design review: the overlay control bar, light
// and dark themes, a portrait and a landscape clip, in four states. Skipped unless
// VIEWER_MOCKUPS_OUT names a directory; frames come from VIEWER_MOCKUPS_FRAMES
// (p0.png p1.png l0.png l1.png: the first frame and a mid-clip frame).
//
//   VIEWER_MOCKUPS_OUT=/tmp/m VIEWER_MOCKUPS_FRAMES=/tmp/frames \
//     tool/flutter test tool/captures/video_viewer_mockups_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

import '../../test/parity/parity_harness.dart' show loadParityFonts;

void main() {
  final out = Platform.environment['VIEWER_MOCKUPS_OUT'];
  final frames = Platform.environment['VIEWER_MOCKUPS_FRAMES'];
  if (out == null || frames == null) {
    test(
      'viewer mockups (set VIEWER_MOCKUPS_OUT and _FRAMES)',
      () {},
      skip: true,
    );
    return;
  }
  const themes = {'light': false, 'dark': true};
  const clips = {
    'portrait': ('p', Size(720, 1280), 'kevin.mp4'),
    'landscape': ('l', Size(1280, 720), 'walkthrough.mp4'),
  };
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadParityFonts);
  {
    for (final theme in themes.entries) {
      for (final clip in clips.entries) {
        testWidgets('${theme.key} ${clip.key}', (t) async {
          t.view.physicalSize = const Size(1280, 800);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.reset);
          final (prefix, size, name) = clip.value;
          final images = <String, ui.Image>{};
          await t.runAsync(() async {
            for (final n in ['0', '1']) {
              images[n] = await decodeImageFromList(
                File('$frames/$prefix$n.png').readAsBytesSync(),
              );
            }
          });
          Future<void> shot(
            String state, {
            required bool playing,
            required String frame,
            Duration position = Duration.zero,
            Future<void> Function(TestGesture mouse)? pointer,
          }) async {
            final key = GlobalKey();
            await t.pumpWidget(
              RepaintBoundary(
                key: key,
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: raftTheme(dark: theme.value),
                  home: Scaffold(
                    body: RaftAttachmentPreviewShell(
                      filename: name,
                      dark: true,
                      onClose: () {},
                      onDownload: () {},
                      commentsBuilder: (_, _) => const SizedBox.shrink(),
                      child: RaftVideoViewer(
                        filename: name,
                        videoSize: size,
                        touch: false,
                        video: ColoredBox(
                          color: Colors.black,
                          child: RawImage(
                            image: images[frame],
                            fit: BoxFit.contain,
                          ),
                        ),
                        playing: playing,
                        position: position,
                        duration: const Duration(seconds: 8, milliseconds: 700),
                        volume: 70,
                        onTogglePlay: () {},
                        onSeek: (_) {},
                        onVolume: (_) {},
                        onDownload: () {},
                      ),
                    ),
                  ),
                ),
              ),
            );
            await t.pump(const Duration(milliseconds: 100));
            final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
            await mouse.addPointer(location: const Offset(4, 790));
            await pointer?.call(mouse);
            await t.pump(const Duration(milliseconds: 250));
            await t.pump(const Duration(milliseconds: 250));
            Future<void> done() => mouse.removePointer();
            final boundary =
                key.currentContext!.findRenderObject() as RenderRepaintBoundary;
            await t.runAsync(() async {
              final image = await boundary.toImage();
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await Directory(out).create(recursive: true);
              await File('$out/${clip.key}-${theme.key}-$state.png')
                  .writeAsBytes(bytes!.buffer.asUint8List());
            });
            await done();
          }

          await shot('1-paused', playing: false, frame: '0');
          await shot(
            '2-playing',
            playing: true,
            frame: '1',
            position: const Duration(milliseconds: 3200),
            pointer: (m) => m.moveTo(
              t.getCenter(find.byKey(const Key('video-viewer-frame'))),
            ),
          );
          await shot(
            '3-seek-hover',
            playing: true,
            frame: '1',
            position: const Duration(milliseconds: 3200),
            pointer: (m) async {
              await m.moveTo(
                t.getCenter(find.byKey(const Key('video-viewer-frame'))),
              );
              await t.pump();
              final rail = t.getRect(
                find.byKey(const Key('inline-video-seek')),
              );
              await m.moveTo(
                Offset(rail.left + rail.width * .62, rail.center.dy),
              );
            },
          );
          await shot(
            '4-volume',
            playing: true,
            frame: '1',
            position: const Duration(milliseconds: 3200),
            pointer: (m) async {
              await m.moveTo(
                t.getCenter(find.byKey(const Key('video-viewer-frame'))),
              );
              await t.pump();
              await m.moveTo(
                t.getCenter(find.byKey(const Key('inline-video-mute'))),
              );
            },
          );
        });
      }
    }
  }
}
