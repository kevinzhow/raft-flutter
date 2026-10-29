// Video cards without a server thumbnail: the first frame is read from the
// video (platform probe, ranged reads), stored privately next to the shape,
// and a phone's card is the poster at the video's own shape with no player.
// The probes here are fakes; the real ones are proven on the devices
// (docs/media-playback.md, "Video cards").
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/attachment_image_repository.dart';
import 'package:raft_flutter/data/cache_clear.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/attachment_view.dart';
import 'package:raft_flutter/features/inline_attachment_media.dart';
import 'package:raft_flutter/features/media_browser.dart';
import 'package:raft_flutter/platform/attachment_player.dart';
import 'package:raft_flutter/platform/video_frame_probe.dart';
import 'package:raft_flutter/platform/video_frame_scheduler.dart';
import 'package:raft_ui/raft_ui.dart';

import 'attachment_thumbnail_restart_test.dart'
    show CountingClient, CountingFiles, png, thumbnailUrl, workspace;

/// A probe that answers with [size] and a decodable picture, records every
/// call, and can be held until released.
/// A player that records what it is asked.
class _Player implements AttachmentPlayer {
  final events = StreamController<AttachmentPlayback>.broadcast();
  final calls = <String>[];
  bool playing = false, disposed = false;
  AttachmentPlayback get state => AttachmentPlayback(
    playing: playing,
    duration: const Duration(seconds: 83),
    hasFrame: true,
    videoSize: const Size(720, 1280),
  );
  @override
  Stream<AttachmentPlayback> get changes => events.stream;
  @override
  AttachmentPlayback get playback => state;
  @override
  bool get usesPlatformView => false;
  @override
  Widget video() => const ColoredBox(
    key: Key('fake-video-surface'),
    color: Color(0xFF445566),
  );
  @override
  Future<void> open(AttachmentSource source) async => calls.add('open');
  @override
  Future<void> toggle() async {
    calls.add('toggle');
    playing = !playing;
    events.add(state);
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    playing = false;
    events.add(state);
  }

  @override
  Future<void> seek(Duration value) async => calls.add('seek');
  @override
  Future<void> volume(double value) async {}
  @override
  Future<void> dispose() async {
    disposed = true;
    await events.close();
  }
}

class FakeProbe implements VideoFrameProbe {
  FakeProbe(this.picture, {this.size = const Size(720, 1280), this.length});
  final Uint8List picture;
  Size size;
  Duration? length;
  Object? failWith;
  Completer<void>? hold;
  final calls = <Uri>[];
  final cancelled = <String>[];
  int active = 0, peak = 0;
  final _running = <String, Completer<void>>{};

  @override
  Future<VideoFrameInfo> probe({
    required String id,
    required Uri url,
    Map<String, String> headers = const {},
    int maxEdge = 640,
    Duration timeout = const Duration(seconds: 20),
    int maxBytes = 16 * 1024 * 1024,
  }) async {
    calls.add(url);
    active++;
    if (active > peak) peak = active;
    final cancel = _running[id] = Completer<void>();
    try {
      final gate = hold;
      if (gate != null) {
        await Future.any([gate.future, cancel.future]);
        if (cancel.isCompleted) {
          throw const VideoFrameException(VideoFrameFailure.cancelled);
        }
      }
      final error = failWith;
      if (error != null) throw error;
      return VideoFrameInfo(
        width: size.width.round(),
        height: size.height.round(),
        duration: length ?? const Duration(seconds: 83),
        jpeg: picture,
      );
    } finally {
      active--;
      _running.remove(id);
    }
  }

  @override
  Future<void> cancel(String id) async {
    cancelled.add(id);
    _running[id]?.complete();
  }
}

/// Counts players: a phone card must never create one.
class _Players {
  int made = 0;
  AttachmentPlayer call() {
    made++;
    throw StateError('a phone video card must not create a player');
  }
}

const noThumbnail = <String, dynamic>{
  'id': 'clip',
  'channelId': 'channel',
  'filename': 'clip.mp4',
  'mimeType': 'video/mp4',
  'sizeBytes': 60 * 1024 * 1024,
};

void main() {
  late Directory directory;
  late Uint8List picture;
  late FakeProbe probe;
  final finished = <WorkspaceController>{};
  final mounted = <(CountingClient, WorkspaceController)>[];

  Future<Directory> root() async => directory;

  setUp(() {
    mounted.clear();
    finished.clear();
    directory = Directory.systemTemp.createTempSync('raft-video-frames');
  });
  tearDown(() => directory.deleteSync(recursive: true));

  /// Unmounts the card and lets go of the workspace (once).
  Future<void> finish(
    WidgetTester tester,
    CountingClient client,
    WorkspaceController w,
  ) async {
    if (!finished.add(w)) return;
    await tester.pumpWidget(const SizedBox());
    w.dispose();
    await client.dispose();
  }

  /// Ends the test: unmounts and lets go of every workspace [mount] made.
  Future<void> done(WidgetTester tester) async {
    for (final (client, w) in mounted) {
      await finish(tester, client, w);
    }
  }

  Future<void> pumpUntil(
    WidgetTester tester,
    bool Function() done, {
    String reason = 'condition',
  }) async {
    for (var i = 0; i < 300 && !done(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(done(), isTrue, reason: reason);
  }

  /// Waits until [store] holds [count] private entries (the poster and the
  /// shape: the repository persists without being awaited).
  Future<void> storedEntries(
    WidgetTester tester,
    AttachmentDiskCache store,
    int count,
  ) async {
    var n = 0;
    for (var i = 0; i < 300 && n < count; i++) {
      n = (await tester.runAsync(
        () => store.entryCount(namespace: AttachmentCacheNamespace.attachments),
      ))!;
      if (n >= count) break;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(n, greaterThanOrEqualTo(count));
  }

  Widget card(
    WorkspaceController w,
    Map<String, dynamic> metadata, {
    FakeProbe? frames,
    VideoFrameScheduler? scheduler,
    CountingFiles? files,
    VoidCallback? onOpen,
    String id = 'card',
    bool heroActive = false,
  }) => InlineVideoAttachment(
    key: ValueKey(id),
    controller: w,
    files: files ?? CountingFiles(picture),
    metadata: metadata,
    channelId: 'channel',
    authorized: () => true,
    pending: false,
    frameProbe: frames ?? probe,
    frameScheduler: scheduler,
    onOpenPreview: onOpen ?? () {},
    heroActive: heroActive,
  );

  Widget host(Widget child, {Size? size}) => MaterialApp(
    theme: raftTheme(),
    home: Scaffold(
      body: Align(alignment: Alignment.topLeft, child: child),
    ),
  );

  Future<(CountingClient, WorkspaceController)> mount(
    WidgetTester tester,
    Map<String, dynamic> metadata, {
    Size window = const Size(390, 844),
    AttachmentDiskCache? store,
    FakeProbe? frames,
    CountingFiles? files,
  }) async {
    tester.view.physicalSize = window;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (client, w) = workspace(store ?? AttachmentDiskCache(root), metadata);
    mounted.add((client, w));
    addTearDown(() => done(tester));
    await tester.pumpWidget(
      host(card(w, metadata, frames: frames, files: files)),
    );
    return (client, w);
  }

  Size boxOf(WidgetTester tester) =>
      tester.getSize(find.byKey(const Key('inline-video')));

  Finder posterImage() => find.descendant(
    of: find.byKey(const Key('inline-video')),
    matching: find.byType(Image),
  );

  group('phone card', () {
    testWidgets(
      'has no player: poster at the real shape, play button, length',
      (tester) async {
        picture = (await tester.runAsync(() => png(180, 320)))!;
        probe = FakeProbe(picture, size: const Size(720, 1280));
        final players = _Players();
        InlineMediaTestHooks.playerFactory = players.call;
        addTearDown(() => InlineMediaTestHooks.playerFactory = null);
        final (_, w) = await mount(tester, {
          ...noThumbnail,
          'width': 720,
          'height': 1280,
        });
        // Before the frame: the neutral placeholder at the declared shape, with
        // the play button already there (never black, never a spinner).
        expect(find.byType(RaftInlineVideo), findsNothing);
        expect(
          find.byKey(const Key('inline-video-placeholder')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('inline-video-play')), findsOneWidget);
        final first = boxOf(tester);
        expect(first.width / first.height, closeTo(720 / 1280, .01));
        await tester.pump(const Duration(milliseconds: 300));
        await pumpUntil(tester, () => posterImage().evaluate().isNotEmpty);
        expect(probe.calls, hasLength(1));
        expect(boxOf(tester), first, reason: 'declared size: no layout change');
        expect(find.text('1:23'), findsOneWidget, reason: 'the length');
        expect(players.made, 0);
        expect(w.attachmentMedia.playerSessions.created, 0);
        await done(tester);
      },
    );

    for (final (name, width, height) in [
      ('landscape', 1920, 1080),
      ('portrait', 1080, 1920),
      ('square', 500, 500),
    ]) {
      testWidgets('$name: the box has the video shape', (tester) async {
        picture = (await tester.runAsync(() => png(64, 64)))!;
        probe = FakeProbe(picture, size: Size(width * 1.0, height * 1.0));
        await mount(tester, {...noThumbnail, 'width': width, 'height': height});
        final box = boxOf(tester);
        expect(box.width, 278, reason: 'the card width on a 390 dp screen');
        expect(box.width / box.height, closeTo(width / height, .01));
        await done(tester);
      });
    }

    testWidgets('a very tall video is capped at 60 % of the screen', (
      tester,
    ) async {
      picture = (await tester.runAsync(() => png(64, 64)))!;
      probe = FakeProbe(picture, size: const Size(450, 1600));
      await mount(tester, {...noThumbnail, 'width': 450, 'height': 1600});
      final box = boxOf(tester);
      expect(box.height, closeTo(844 * .6, 1));
      expect(box.width, 278);
      await pumpUntil(tester, () => posterImage().evaluate().isNotEmpty);
      expect(
        tester.widget<Image>(posterImage()).fit,
        BoxFit.cover,
        reason: 'cropped to fill, not squeezed',
      );
      await tester.pumpWidget(const SizedBox());
      await done(tester);
    });

    testWidgets('no size in the message: 16:9 until the file says, then once', (
      tester,
    ) async {
      picture = (await tester.runAsync(() => png(64, 64)))!;
      probe = FakeProbe(picture, size: const Size(720, 1280));
      await mount(tester, noThumbnail);
      final sizes = <Size>[boxOf(tester)];
      expect(sizes.single.width / sizes.single.height, closeTo(16 / 9, .02));
      await tester.pump(const Duration(milliseconds: 300));
      for (var i = 0; i < 100 && posterImage().evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump(const Duration(milliseconds: 50));
        if (boxOf(tester) != sizes.last) sizes.add(boxOf(tester));
      }
      if (boxOf(tester) != sizes.last) sizes.add(boxOf(tester));
      expect(sizes, hasLength(2), reason: 'adjusts exactly once');
      expect(sizes.last.width / sizes.last.height, closeTo(720 / 1280, .01));
      await done(tester);
    });

    testWidgets('a tap anywhere on the card asks to open the viewer', (
      tester,
    ) async {
      picture = (await tester.runAsync(() => png(64, 64)))!;
      probe = FakeProbe(picture);
      var opened = 0;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final (client, w) = workspace(AttachmentDiskCache(root), noThumbnail);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        w.dispose();
        await client.dispose();
      });
      await tester.pumpWidget(
        host(card(w, noThumbnail, onOpen: () => opened++)),
      );
      final rect = tester.getRect(find.byKey(const Key('inline-video')));
      for (final spot in [
        rect.center,
        rect.topLeft + const Offset(8, 8),
        rect.bottomRight - const Offset(8, 8),
      ]) {
        await tester.tapAt(spot);
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(opened, 3);
    });

    testWidgets('the card wears the viewer Hero only while the viewer is up', (
      tester,
    ) async {
      picture = (await tester.runAsync(() => png(64, 64)))!;
      probe = FakeProbe(picture);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final (client, w) = workspace(AttachmentDiskCache(root), noThumbnail);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        w.dispose();
        await client.dispose();
      });
      Future<void> show(bool active) =>
          tester.pumpWidget(host(card(w, noThumbnail, heroActive: active)));
      await show(false);
      await pumpUntil(tester, () => posterImage().evaluate().isNotEmpty);
      RaftMediaHero hero() => tester.widget<RaftMediaHero>(
        find.descendant(
          of: find.byKey(const Key('inline-video')),
          matching: find.byType(RaftMediaHero),
        ),
      );
      expect(hero().enabled, isFalse);
      expect(hero().tag, 'media-clip');
      expect(hero().image, isNotNull, reason: 'the flight carries the poster');
      await show(true);
      expect(hero().enabled, isTrue);
    });
  });

  group('desktop card', () {
    testWidgets('shows the extracted first frame without an inline player', (
      tester,
    ) async {
      picture = (await tester.runAsync(() => png(320, 180)))!;
      probe = FakeProbe(picture, size: const Size(1280, 720));
      await mount(tester, noThumbnail, window: const Size(900, 700));
      expect(find.byType(RaftInlineVideo), findsNothing);
      expect(find.byType(RaftVideoPosterCard), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
      await pumpUntil(tester, () => find.byType(Image).evaluate().isNotEmpty);
      expect(probe.calls, hasLength(1));
      final box = boxOf(tester);
      expect(
        box.width / box.height,
        closeTo(16 / 9, .02),
        reason: 'landscape poster keeps its shape',
      );
      await done(tester);
    });
  });

  group('where the frame comes from', () {
    testWidgets('a server thumbnail is the poster and nothing is read', (
      tester,
    ) async {
      picture = (await tester.runAsync(() => png(320, 180)))!;
      probe = FakeProbe(picture);
      final files = CountingFiles(picture);
      await mount(tester, {
        ...noThumbnail,
        'thumbnailUrl': thumbnailUrl,
      }, files: files);
      await tester.pump(const Duration(milliseconds: 400));
      await pumpUntil(tester, () => posterImage().evaluate().isNotEmpty);
      await tester.pump(const Duration(milliseconds: 500));
      expect(files.urls, [thumbnailUrl]);
      expect(
        probe.calls,
        isEmpty,
        reason: 'extraction only without a thumbnail',
      );
      await done(tester);
    });

    testWidgets('a thumbnail added later wins over the stored frame', (
      tester,
    ) async {
      picture = (await tester.runAsync(() => png(320, 180)))!;
      probe = FakeProbe(picture, size: const Size(1280, 720));
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = AttachmentDiskCache(root);
      final (firstClient, first) = workspace(store, noThumbnail);
      await tester.pumpWidget(host(card(first, noThumbnail)));
      await tester.pump(const Duration(milliseconds: 300));
      await pumpUntil(tester, () => posterImage().evaluate().isNotEmpty);
      await storedEntries(tester, store, 2);
      await tester.pumpWidget(const SizedBox());
      first.dispose();
      await firstClient.dispose();

      // Later the message carries a thumbnail: it is what the card shows.
      final withThumbnail = {...noThumbnail, 'thumbnailUrl': thumbnailUrl};
      final (client, w) = workspace(AttachmentDiskCache(root), withThumbnail);
      final files = CountingFiles(picture);
      await tester.pumpWidget(host(card(w, withThumbnail, files: files)));
      await tester.pump(const Duration(milliseconds: 400));
      await pumpUntil(tester, () => posterImage().evaluate().isNotEmpty);
      expect(files.urls, [
        thumbnailUrl,
      ], reason: 'the server thumbnail is used');
      expect(probe.calls, hasLength(1), reason: 'no second frame read');
      await tester.pumpWidget(const SizedBox());
      w.dispose();
      await client.dispose();
    });
  });

  group('the shape is remembered', () {
    testWidgets(
      'a second view in the session has its final box in the first frame',
      (tester) async {
        picture = (await tester.runAsync(() => png(64, 64)))!;
        probe = FakeProbe(picture, size: const Size(720, 1280));
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final (client, w) = workspace(AttachmentDiskCache(root), noThumbnail);
        addTearDown(() async {
          w.dispose();
          await client.dispose();
        });
        await tester.pumpWidget(host(card(w, noThumbnail)));
        await tester.pump(const Duration(milliseconds: 300));
        await pumpUntil(tester, () => posterImage().evaluate().isNotEmpty);
        final settled = boxOf(tester);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(host(card(w, noThumbnail, id: 'again')));
        expect(boxOf(tester), settled, reason: 'no 16:9 flash, no layout jump');
        expect(find.text('1:23'), findsOneWidget);
        await pumpUntil(tester, () => posterImage().evaluate().isNotEmpty);
        expect(probe.calls, hasLength(1), reason: 'not read again');
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'after a restart the stored shape and frame are used, nothing read',
      (tester) async {
        picture = (await tester.runAsync(() => png(64, 64)))!;
        probe = FakeProbe(picture, size: const Size(720, 1280));
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final store = AttachmentDiskCache(root);
        final (firstClient, first) = workspace(store, noThumbnail);
        await tester.pumpWidget(host(card(first, noThumbnail)));
        await tester.pump(const Duration(milliseconds: 300));
        await pumpUntil(tester, () => posterImage().evaluate().isNotEmpty);
        await storedEntries(tester, store, 2);
        await tester.pumpWidget(const SizedBox());
        first.dispose();
        await firstClient.dispose();

        final restarted = FakeProbe(picture, size: const Size(1, 1));
        final (client, w) = workspace(AttachmentDiskCache(root), noThumbnail);
        await tester.pumpWidget(host(card(w, noThumbnail, frames: restarted)));
        await pumpUntil(tester, () => posterImage().evaluate().isNotEmpty);
        await pumpUntil(tester, () {
          final box = boxOf(tester);
          return (box.width / box.height - 720 / 1280).abs() < .01;
        }, reason: 'the stored shape');
        expect(find.text('1:23'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 600));
        expect(restarted.calls, isEmpty, reason: 'the stored frame serves it');
        expect(client.resolutions, 0, reason: 'nothing signed either');
        await tester.pumpWidget(const SizedBox());
        w.dispose();
        await client.dispose();
      },
    );
  });

  group('failures', () {
    testWidgets(
      'a failed read says so, offers Retry and is not retried by itself',
      (tester) async {
        picture = (await tester.runAsync(() => png(64, 64)))!;
        probe = FakeProbe(picture)
          ..failWith = const VideoFrameException(VideoFrameFailure.failed);
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final (client, w) = workspace(AttachmentDiskCache(root), noThumbnail);
        addTearDown(() async {
          w.dispose();
          await client.dispose();
        });
        await tester.pumpWidget(host(card(w, noThumbnail)));
        await tester.pump(const Duration(milliseconds: 300));
        await pumpUntil(tester, () => probe.calls.isNotEmpty);
        for (var i = 0; i < 20; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump(const Duration(milliseconds: 300));
        }
        // Web v1.21.23: the card says the preview failed and offers Retry.
        expect(find.byKey(const Key('inline-video-failure')), findsOneWidget);
        expect(find.text("Couldn't load this video preview."), findsOneWidget);
        expect(find.byKey(const Key('inline-video-play')), findsNothing);
        expect(posterImage(), findsNothing);
        // Built again (the list drops and rebuilds rows): still one read.
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(host(card(w, noThumbnail, id: 'b')));
        await tester.pump(const Duration(seconds: 2));
        expect(probe.calls, hasLength(1), reason: 'no retry loop');
        expect(find.byKey(const Key('inline-video-failure')), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets('an expired signature is signed again once', (tester) async {
      picture = (await tester.runAsync(() => png(64, 64)))!;
      probe = FakeProbe(picture)
        ..failWith = const VideoFrameException(VideoFrameFailure.expired);
      final (client, _) = await mount(tester, noThumbnail);
      await tester.pump(const Duration(milliseconds: 300));
      await pumpUntil(tester, () => probe.calls.length >= 2);
      await tester.pump(const Duration(seconds: 1));
      expect(
        probe.calls,
        hasLength(2),
        reason: 'first signature, then a new one',
      );
      expect(client.resolutions, 2);
    });
  });

  group('concurrency and cancellation', () {
    test(
      'the scheduler runs two at a time, newest first, and drops the unwanted',
      () async {
        final scheduler = VideoFrameScheduler();
        final gates = <Completer<void>>[];
        final order = <int>[];
        var wanted = true;
        VideoFrameJob<int> job(int n, {bool Function()? want}) =>
            scheduler.submit<int>((_) async {
              order.add(n);
              final gate = Completer<void>();
              gates.add(gate);
              await gate.future;
              return n;
            }, wanted: want);
        final jobs = [
          for (var n = 0; n < 5; n++)
            job(n, want: n == 3 ? () => wanted : null),
        ];
        await Future<void>.delayed(Duration.zero);
        expect(scheduler.running, 2);
        expect(order, [0, 1], reason: 'free slots go to the first at hand');
        wanted = false;
        jobs[4].cancel();
        expect(
          await jobs[4].result.then<Object>(
            (_) => 'ran',
            onError: (Object e) => e,
          ),
          isA<VideoFrameException>(),
        );
        gates[0].complete();
        await Future<void>.delayed(Duration.zero);
        // Newest first: 4 was cancelled, 3 is unwanted now, so 2 starts.
        expect(order, [0, 1, 2]);
        expect(scheduler.peak, 2);
        gates[1].complete();
        gates[2].complete();
        expect(await jobs[2].result, 2);
        await Future<void>.delayed(Duration.zero);
        expect(order, [0, 1, 2], reason: 'the unwanted job never starts');
        expect(scheduler.running, 0);
        expect(scheduler.queued, 0);
      },
    );

    test('cancelling a running job tells the work to stop', () async {
      final scheduler = VideoFrameScheduler();
      var stopped = 0;
      final stuck = Completer<void>();
      final job = scheduler.submit<int>((j) async {
        j.onCancel(() {
          stopped++;
          stuck.complete();
        });
        await stuck.future;
        return 1;
      });
      await Future<void>.delayed(Duration.zero);
      job.cancel();
      expect(stopped, 1);
      await expectLater(job.result, throwsA(isA<VideoFrameException>()));
      await Future<void>.delayed(Duration.zero);
      expect(scheduler.running, 0);
    });

    testWidgets(
      'a column of cards reads two frames at a time; scrolling away cancels',
      (tester) async {
        picture = (await tester.runAsync(() => png(64, 64)))!;
        probe = FakeProbe(picture, size: const Size(1280, 720))
          ..hold = Completer<void>();
        tester.view.physicalSize = const Size(390, 420);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final clips = [
          for (var i = 0; i < 12; i++) {...noThumbnail, 'id': 'clip$i'},
        ];
        final (client, w) = workspace(AttachmentDiskCache(root), noThumbnail);
        final scroll = ScrollController();
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox());
          scroll.dispose();
          w.dispose();
          await client.dispose();
        });
        final scheduler = VideoFrameScheduler();
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(),
            home: Scaffold(
              body: ListView(
                controller: scroll,
                children: [
                  for (final clip in clips)
                    card(w, clip, id: '${clip['id']}', scheduler: scheduler),
                ],
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));
        await pumpUntil(tester, () => probe.calls.length >= 2);
        // More time: a third read must not start while two are held.
        for (var i = 0; i < 10; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(probe.peak, 2);
        expect(probe.calls.length, 2);
        expect(scheduler.peak, 2);
        // Scroll the first cards far away: their reads are cancelled.
        scroll.jumpTo(scroll.position.maxScrollExtent);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 400));
        expect(
          probe.cancelled,
          hasLength(2),
          reason: 'the two reads left behind',
        );
        expect(probe.peak, lessThanOrEqualTo(2));
        probe.hold!.complete();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 400));
        expect(probe.peak, lessThanOrEqualTo(2));
      },
    );
  });

  group('private cache', () {
    testWidgets(
      'the poster and the shape live in the private namespace; Clear cache and sign-out remove them',
      (tester) async {
        picture = (await tester.runAsync(() => png(64, 64)))!;
        probe = FakeProbe(picture, size: const Size(720, 1280));
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final store = AttachmentDiskCache(root);
        final (client, w) = workspace(store, noThumbnail);
        await tester.pumpWidget(host(card(w, noThumbnail)));
        await tester.pump(const Duration(milliseconds: 300));
        await pumpUntil(tester, () => posterImage().evaluate().isNotEmpty);
        await storedEntries(tester, store, 2);
        final privateBytes = await tester.runAsync(
          () =>
              store.sizeBytes(namespace: AttachmentCacheNamespace.attachments),
        );
        final publicBytes = await tester.runAsync(
          () => store.sizeBytes(namespace: AttachmentCacheNamespace.public),
        );
        expect(
          privateBytes,
          greaterThan(0),
          reason: 'counted in Settings > Storage',
        );
        expect(publicBytes, 0, reason: 'never in the public namespace');
        expect(
          await tester.runAsync(
            () => store.entryCount(
              namespace: AttachmentCacheNamespace.attachments,
            ),
          ),
          2,
          reason: 'the frame and the shape',
        );

        // The card is gone (a picture a widget holds stays through Clear cache).
        await tester.pumpWidget(const SizedBox());
        // Clear cache (Settings > Storage) goes through the disk hook.
        final clearing = CacheClear();
        clearing.installAppLayers(cache: store);
        final result = await tester.runAsync(clearing.run);
        expect(result!.ok, isTrue);
        expect(
          await tester.runAsync(
            () => store.entryCount(
              namespace: AttachmentCacheNamespace.attachments,
            ),
          ),
          0,
        );

        // The card reads the frame again after it was cleared.
        w.attachmentMedia.trimRebuildable();
        await tester.pumpWidget(host(card(w, noThumbnail, id: 'b')));
        await tester.pump(const Duration(milliseconds: 300));
        await pumpUntil(tester, () => probe.calls.length == 2);
        await pumpUntil(tester, () => posterImage().evaluate().isNotEmpty);
        await storedEntries(tester, store, 2);

        // Sign-out removes the account's entries, the frame included.
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(
          () => store.purgeAccount(client.origin, client.user!.id),
        );
        expect(
          await tester.runAsync(
            () => store.entryCount(
              namespace: AttachmentCacheNamespace.attachments,
            ),
          ),
          0,
        );
        w.dispose();
        await client.dispose();
      },
    );
  });

  group('tap opens the viewer', () {
    for (final width in [390.0, 1100.0]) {
      testWidgets(
        '$width: the viewer plays at once, and the card flies its poster',
        (tester) async {
          picture = (await tester.runAsync(() => png(180, 320)))!;
          probe = FakeProbe(picture, size: const Size(720, 1280));
          final players = <_Player>[];
          InlineMediaTestHooks.playerFactory = () {
            final player = _Player();
            players.add(player);
            return player;
          };
          addTearDown(() => InlineMediaTestHooks.playerFactory = null);
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final video = {...noThumbnail, 'width': 720, 'height': 1280};
          final (client, w) = workspace(AttachmentDiskCache(root), video);
          final files = CountingFiles(picture);
          await tester.pumpWidget(
            MaterialApp(
              theme: raftTheme(),
              home: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: AttachmentView(
                    controller: w,
                    files: files,
                    messageId: 'host',
                    metadata: video,
                    galleryItems: [video],
                    frameProbe: probe,
                  ),
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 300));
          await pumpUntil(tester, () => posterImage().evaluate().isNotEmpty);
          expect(
            players,
            isEmpty,
            reason: 'a timeline card never has a player',
          );
          expect(find.byType(RaftInlineVideo), findsNothing);

          await tester.tap(find.byKey(const Key('inline-video-poster-card')));
          await tester.pump();
          final shuttle = find.byKey(const ValueKey('media-hero-shuttle'));
          for (var i = 0; i < 200 && shuttle.evaluate().isEmpty; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 10)),
            );
            await tester.pump(const Duration(milliseconds: 16));
          }
          expect(find.byType(MediaBrowser), findsOneWidget);
          expect(
            shuttle,
            findsOneWidget,
            reason: 'the poster flies from the card',
          );
          for (var i = 0; i < 30; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 15)),
            );
            await tester.pump(const Duration(milliseconds: 60));
          }
          expect(shuttle, findsNothing);
          expect(
            players,
            hasLength(1),
            reason: 'the viewer made the only player',
          );
          expect(players.single.calls, [
            'open',
            'toggle',
          ], reason: 'plays at once');
          expect(players.single.playing, isTrue);
          final heroes = tester
              .widgetList<RaftMediaHero>(
                find.byType(RaftMediaHero, skipOffstage: false),
              )
              .where((hero) => hero.enabled);
          expect(heroes, hasLength(2), reason: 'the card and the stage');
          tester.widget<MediaBrowser>(find.byType(MediaBrowser)).onClose();
          for (var i = 0; i < 20; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 15)),
            );
            await tester.pump(const Duration(milliseconds: 60));
          }
          expect(find.byType(MediaBrowser), findsNothing);
          expect(players.single.disposed, isTrue);
          expect(w.attachmentMedia.playerSessions.length, 0);
          await tester.pumpWidget(const SizedBox());
          w.dispose();
          await client.dispose();
        },
      );
    }
  });
}
