import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  group('video viewer', () {
    late List<String> calls;
    Duration? seek;
    double? volume;

    Future<void> pump(
      WidgetTester tester, {
      Size? videoSize = const Size(720, 1280),
      bool playing = false,
      bool touch = false,
      Size screen = const Size(1000, 700),
    }) async {
      calls = [];
      seek = null;
      volume = null;
      tester.view.physicalSize = screen;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: RaftVideoViewer(
              filename: 'clip.mp4',
              videoSize: videoSize,
              video: const ColoredBox(
                key: Key('surface'),
                color: Color(0xFF3D5A79),
              ),
              playing: playing,
              position: const Duration(seconds: 30),
              duration: const Duration(seconds: 120),
              touch: touch,
              onTogglePlay: () => calls.add('toggle'),
              onSeek: (v) => seek = v,
              onVolume: (v) => volume = v,
              onDownload: () => calls.add('download'),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('stage is black; a portrait clip shrinks to fit, never grows', (
      tester,
    ) async {
      await pump(tester);
      final stage = tester.getRect(find.byKey(const Key('video-viewer')));
      final frame = tester.getRect(find.byKey(const Key('video-viewer-frame')));
      // 16 px around, aspect kept (720x1280 into 668 px of height).
      expect(frame.height, 668);
      // The frame wraps the content: border (1 px) outside.
      final rule = 1.0;
      expect(frame.width, closeTo((668 - 2 * rule) * 720 / 1280 + 2 * rule, 1));
      expect(frame.center.dx, closeTo(stage.center.dx, 1));
      expect(
        tester.widget<ColoredBox>(find.byKey(const Key('video-viewer'))).color,
        const Color(0xFF000000),
      );
      await pump(tester, videoSize: const Size(320, 180));
      final small = tester.getSize(find.byKey(const Key('video-viewer-frame')));
      final rule2 = 1.0;
      expect(small, Size(320 + 2 * rule2, 180 + 2 * rule2));
      // Paused: the browser-style bar is up, no Material slider anywhere.
      expect(find.byKey(const Key('inline-video-bar')), findsOneWidget);
      expect(find.byType(Slider), findsNothing);
    });

    testWidgets('play, seek, mute, volume rail, download, full screen', (
      tester,
    ) async {
      await pump(tester);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.byKey(const Key('surface'))));
      await tester.pump();
      await tester.tap(find.byKey(const Key('inline-video-toggle')));
      await tester.tap(find.byKey(const Key('inline-video-download-action')));
      expect(calls, ['toggle', 'download']);
      final rail = tester.getRect(find.byKey(const Key('inline-video-seek')));
      await tester.tapAt(Offset(rail.left + rail.width / 2, rail.center.dy));
      expect(seek!.inSeconds, inInclusiveRange(59, 61));
      await tester.tap(find.byKey(const Key('inline-video-mute')));
      expect(volume, 0);
      // The volume rail opens while the pointer is over the speaker.
      await mouse.moveTo(
        tester.getCenter(find.byKey(const Key('inline-video-mute'))),
      );
      await tester.pump();
      final vol = tester.getRect(find.byKey(const Key('inline-video-volume')));
      await tester.tapAt(Offset(vol.left + vol.width * .25, vol.center.dy));
      expect(volume, closeTo(25, 1));
      // Full screen: the picture takes the whole stage, unframed.
      await tester.tap(find.byKey(const Key('inline-video-fullscreen')));
      await tester.pump();
      final stage = tester.getSize(find.byKey(const Key('video-viewer')));
      expect(
        tester.getSize(find.byKey(const Key('video-viewer-frame'))),
        stage,
      );
      await tester.tap(find.byKey(const Key('inline-video-fullscreen')));
      await tester.pump();
      expect(
        tester.getSize(find.byKey(const Key('video-viewer-frame'))),
        isNot(stage),
      );
    });

    testWidgets(
      'a click on the picture toggles; playing hides the bar off hover',
      (tester) async {
        await pump(tester, playing: true);
        expect(find.byKey(const Key('inline-video-bar')), findsNothing);
        await tester.tap(find.byKey(const Key('inline-video-surface')));
        expect(calls, ['toggle']);
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        addTearDown(mouse.removePointer);
        await mouse.moveTo(tester.getCenter(find.byKey(const Key('surface'))));
        await tester.pump();
        expect(find.byKey(const Key('inline-video-bar')), findsOneWidget);
      },
    );

    testWidgets('phone width: bar keeps play, time, seek and drops extras', (
      tester,
    ) async {
      await pump(tester, touch: true, screen: const Size(320, 640));
      expect(find.byKey(const Key('inline-video-toggle')), findsOneWidget);
      expect(find.byKey(const Key('inline-video-seek')), findsOneWidget);
      expect(find.byKey(const Key('inline-video-play')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('audio viewer card: badge, name, rails; no Material slider', (
    tester,
  ) async {
    Duration? seek;
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: RaftAudioPreview(
            filename: 'standup.mp3',
            duration: const Duration(seconds: 125),
            onSeek: (v) => seek = v,
          ),
        ),
      ),
    );
    expect(find.text('standup.mp3'), findsOneWidget);
    expect(find.text('Audio file'), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
    final rail = tester.getRect(find.byKey(const Key('audio-seek')));
    await tester.tapAt(Offset(rail.left + rail.width / 2, rail.center.dy));
    expect(seek!.inSeconds, inInclusiveRange(61, 64));
    expect(
      tester.getSize(find.byKey(const Key('audio-preview'))).width,
      lessThanOrEqualTo(576),
    );
  });

  testWidgets('semantics: every control is labelled; rails are adjustable', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final calls = <String>[];
    Duration? seek;
    double? volume;
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: RaftVideoViewer(
            filename: 'clip.mp4',
            videoSize: const Size(1280, 720),
            video: const ColoredBox(color: Color(0xFF3D5A79)),
            position: const Duration(seconds: 2),
            duration: const Duration(seconds: 8),
            volume: 50,
            touch: false,
            onTogglePlay: () => calls.add('toggle'),
            onSeek: (v) => seek = v,
            onVolume: (v) => volume = v,
            onDownload: () => calls.add('download'),
          ),
        ),
      ),
    );
    await tester.pump();
    SemanticsNode node(String key) => tester.getSemantics(find.byKey(Key(key)));
    void act(Key key, SemanticsAction action) =>
        // ignore: invalid_use_of_protected_member
        SemanticsBinding.instance.performSemanticsAction(
          SemanticsActionEvent(
            type: action,
            viewId: tester.view.viewId,
            nodeId: tester.getSemantics(find.byKey(key)).id,
          ),
        );
    for (final entry in {
      'inline-video-toggle': 'Play Video clip.mp4',
      'inline-video-mute': 'Mute Video clip.mp4',
      'inline-video-fullscreen': 'Full Screen clip.mp4',
      'inline-video-download-action': 'Download clip.mp4',
    }.entries) {
      final data = node(entry.key).getSemanticsData();
      expect(data.label, entry.value, reason: entry.key);
      expect(data.flagsCollection.isButton, isTrue, reason: entry.key);
      expect(data.hasAction(SemanticsAction.tap), isTrue, reason: entry.key);
    }
    // The picture itself is the play button of the player region.
    expect(find.bySemanticsLabel('Video clip.mp4'), findsOneWidget);
    final seekData = node('inline-video-seek').getSemanticsData();
    expect(seekData.flagsCollection.isSlider, isTrue);
    expect(seekData.label, 'Seek video clip.mp4');
    expect(seekData.value, '0:02 of 0:08');
    expect(seekData.hasAction(SemanticsAction.increase), isTrue);
    expect(seekData.hasAction(SemanticsAction.decrease), isTrue);
    act(const Key('inline-video-seek'), SemanticsAction.increase);
    expect(seek, const Duration(seconds: 7));
    act(const Key('inline-video-seek'), SemanticsAction.decrease);
    expect(seek, const Duration(seconds: 0));
    // The volume rail is hidden for the eye but present for a screen reader.
    final volData = node('inline-video-volume').getSemanticsData();
    expect(volData.flagsCollection.isSlider, isTrue);
    expect(volData.label, 'Video volume clip.mp4');
    expect(volData.value, '50%');
    act(const Key('inline-video-volume'), SemanticsAction.increase);
    expect(volume, closeTo(60, .01));
    act(const Key('inline-video-toggle'), SemanticsAction.tap);
    act(const Key('inline-video-download-action'), SemanticsAction.tap);
    expect(calls, ['toggle', 'download']);
    handle.dispose();
  });

  for (final width in const [1280.0, 1440.0, 1920.0]) {
    testWidgets('header and stage share the window width at $width px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: RaftAttachmentPreviewShell(
              filename: 'clip.mp4',
              dark: true,
              onClose: () {},
              onDownload: () {},
              child: const RaftVideoViewer(
                filename: 'clip.mp4',
                videoSize: Size(720, 1280),
                video: ColoredBox(color: Color(0xFF3D5A79)),
                touch: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final header = tester.getRect(find.byType(RaftLightboxHeader));
      final stage = tester.getRect(find.byKey(const Key('video-viewer')));
      expect(header.left, 0);
      expect(stage.left, 0);
      expect(header.width, width);
      expect(stage.width, width);
      // The stage runs from under the header to the window bottom.
      expect(stage.bottom, 900);
      expect(stage.top, greaterThanOrEqualTo(header.bottom - 1));
    });
  }
}
