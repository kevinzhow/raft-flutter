import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/attachment_player.dart';
import 'package:raft_flutter/platform/attachment_player_factory.dart';
import 'package:raft_flutter/platform/media_failure.dart';
import 'package:raft_flutter/platform/media_probe.dart';
import 'package:raft_flutter/platform/video_cache.dart';
import 'package:raft_flutter/platform/video_player_attachment_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

class _Platform extends VideoPlayerPlatform {
  final calls = <String>[];
  final streams = <int, StreamController<VideoEvent>>{};
  final volumes = <double>[];
  final seeks = <Duration>[];
  final sources = <DataSource>[];
  final loops = <bool>[];
  final viewTypes = <VideoViewType>[];
  bool failOpen = false;

  /// The next [failures] creations fail (a host that refuses the request).
  int failures = 0;
  Size size = const Size(1280, 720);
  Duration duration = const Duration(seconds: 10);

  @override
  Future<void> init() async {}
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    calls.add('create');
    sources.add(options.dataSource);
    viewTypes.add(options.viewType);
    final stream = StreamController<VideoEvent>();
    streams[0] = stream;
    if (failOpen || failures-- > 0) {
      stream.addError(PlatformException(code: 'VideoError', message: 'bad'));
    } else {
      stream.add(
        VideoEvent(
          eventType: VideoEventType.initialized,
          size: size,
          duration: duration,
        ),
      );
    }
    return 0;
  }

  @override
  Future<void> dispose(int playerId) async => calls.add('dispose');
  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => streams[playerId]!.stream;
  @override
  Future<void> play(int playerId) async => calls.add('play');
  @override
  Future<void> pause(int playerId) async => calls.add('pause');
  @override
  Future<void> setLooping(int playerId, bool looping) async {
    calls.add('loop');
    loops.add(looping);
  }
  @override
  Future<void> setVolume(int playerId, double volume) async {
    calls.add('volume');
    volumes.add(volume);
  }

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
  @override
  Future<void> setPreventsDisplaySleepDuringVideoPlayback(
    int playerId,
    bool prevents,
  ) async {}
  @override
  Future<void> seekTo(int playerId, Duration position) async {
    calls.add('seek');
    seeks.add(position);
  }

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;
  @override
  Widget buildView(int playerId) => const SizedBox(key: Key('texture'));
}

void main() {
  late _Platform fake;
  late VideoPlayerPlatform previous;
  late Future<MediaFailure?> Function(Uri, Map<String, String>, String?) realProbe;
  setUp(() {
    previous = VideoPlayerPlatform.instance;
    fake = _Platform();
    VideoPlayerPlatform.instance = fake;
    // ExoPlayer's "Source error" names no cause: the player asks the host.
    // These tests are about the player, so the host answers 403 (an expired
    // signature); the classes themselves are tested in media_failure_test.
    realProbe = MediaDiagnosis.probe;
    MediaDiagnosis.probe = (url, headers, proxy) async =>
        const MediaFailure(MediaFailureKind.expired, cause: 'HTTP 403');
  });
  tearDown(() {
    VideoPlayerPlatform.instance = previous;
    MediaDiagnosis.probe = realProbe;
  });

  group('backend selection', () {
    test('system player on Android, iOS and macOS; media_kit elsewhere', () {
      for (final p in [
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
      ]) {
        expect(attachmentBackendFor(p), AttachmentBackend.system, reason: '$p');
      }
      for (final p in [TargetPlatform.windows, TargetPlatform.linux]) {
        expect(attachmentBackendFor(p), AttachmentBackend.mediaKit);
      }
    });

    test('the factory builds the right class and never touches media_kit '
        'on system platforms', () {
      var mediaKit = 0;
      final stub = _Stub();
      for (final p in [
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
      ]) {
        final player = createAttachmentPlayer(
          platform: p,
          debugMediaKit: () {
            mediaKit++;
            return stub;
          },
        );
        expect(player, isA<VideoPlayerAttachmentPlayer>());
        unawaited(player.dispose());
      }
      expect(mediaKit, 0);
      for (final p in [TargetPlatform.windows, TargetPlatform.linux]) {
        expect(
          createAttachmentPlayer(platform: p, debugMediaKit: () => stub),
          same(stub),
        );
      }
    });
  });

  test('only the viewer asks for the native view (HDR), on every system '
      'platform; cards keep the texture', () async {
    for (final p in [
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.macOS,
    ]) {
      final card = createAttachmentPlayer(platform: p);
      final viewer = createAttachmentPlayer(platform: p, hdr: true);
      await card.open(AttachmentSource.file(File('/tmp/raft-test/c.mp4')));
      await viewer.open(AttachmentSource.file(File('/tmp/raft-test/c.mp4')));
      await card.dispose();
      await viewer.dispose();
    }
    expect(fake.viewTypes, [
      for (var i = 0; i < 3; i++) ...[
        VideoViewType.textureView,
        VideoViewType.platformView,
      ],
    ]);
  });

  group('the video cache', () {
    late Directory root;
    final account = VideoCacheAccount('https://raft.example', 'alice');
    final url = Uri.parse('https://bucket.storage.invalid/a1.mp4?sig=1');
    setUp(() async {
      root = await Directory.systemTemp.createTemp('vp-cache');
      VideoCache.debugRoot = root;
      VideoCache.debugEnabled = true;
    });
    tearDown(() async {
      await VideoCache.debugReset();
      VideoCache.debugRoot = null;
      VideoCache.debugEnabled = null;
      await root.delete(recursive: true);
    });

    AttachmentSource streamed({VideoCacheAccount? who}) =>
        AttachmentSource.network(url, cacheKey: 'a1', cacheAccount: who);

    test('a video of a known account plays from the loopback cache', () async {
      final player = VideoPlayerAttachmentPlayer();
      await player.open(streamed(who: account));
      await player.dispose();
      final opened = Uri.parse(fake.sources.single.uri!);
      expect(opened.host, '127.0.0.1');
      expect(opened.toString(), isNot(contains('sig=')));
    });

    test('a source that does not know its account streams as before', () async {
      final player = VideoPlayerAttachmentPlayer();
      await player.open(streamed());
      await player.dispose();
      expect(fake.sources.single.uri, url.toString());
    });

    test('audio is never cached', () async {
      final player = VideoPlayerAttachmentPlayer(hasPicture: false);
      await player.open(streamed(who: account));
      await player.dispose();
      expect(fake.sources.single.uri, url.toString());
      expect(VideoCache.debugStarted, 0);
    });

    test('the kill switch streams the real URL', () async {
      VideoCache.debugEnabled = false;
      final player = VideoPlayerAttachmentPlayer();
      await player.open(streamed(who: account));
      await player.dispose();
      expect(fake.sources.single.uri, url.toString());
    });

    test('a re-signed source stays in the cache', () async {
      final player = VideoPlayerAttachmentPlayer();
      await player.open(
        AttachmentSource.network(
          url,
          cacheKey: 'a1',
          cacheAccount: account,
          refresh: () async => Uri.parse('https://bucket.storage.invalid/a1.mp4?sig=2'),
        ),
      );
      final first = fake.sources.single.uri;
      await player.dispose();
      expect(Uri.parse(first!).host, '127.0.0.1');
    });
  });

  group('VideoPlayerAttachmentPlayer', () {
    group('looping', () {
      // The plugin switches looping off itself when it creates a controller;
      // what counts is how often the player switched it on.
      int switchedOn() => fake.loops.where((on) => on).length;

      Future<void> openClip(
        Duration length, {
        bool video = true,
      }) async {
        fake.duration = length;
        final player = VideoPlayerAttachmentPlayer(hasPicture: video);
        await player.open(AttachmentSource.file(File('/tmp/raft-test/c.mp4')));
        await Future<void>.delayed(Duration.zero);
        await player.dispose();
      }

      test('the limit is 60 seconds', () {
        expect(kLoopingVideoMaxDuration, const Duration(seconds: 60));
        expect(loopsAtEnd(Duration.zero), isFalse);
        expect(loopsAtEnd(const Duration(milliseconds: 1)), isTrue);
        expect(loopsAtEnd(const Duration(seconds: 60)), isTrue);
        expect(loopsAtEnd(const Duration(seconds: 60, milliseconds: 1)), isFalse);
        expect(loopsAtEnd(const Duration(minutes: 5)), isFalse);
      });

      test('a short clip loops', () async {
        await openClip(const Duration(seconds: 10));
        expect(switchedOn(), 1);
      });

      test('a clip of exactly 60 seconds loops', () async {
        await openClip(const Duration(seconds: 60));
        expect(switchedOn(), 1);
      });

      test('a longer clip stops at the end as before', () async {
        await openClip(const Duration(seconds: 61));
        await openClip(const Duration(minutes: 20));
        expect(switchedOn(), 0);
      });

      test('an unknown length does not loop', () async {
        await openClip(Duration.zero);
        expect(switchedOn(), 0);
      });

      test('audio never loops', () async {
        await openClip(const Duration(seconds: 10), video: false);
        expect(switchedOn(), 0);
      });

      test('the factory passes video through, so audio players do not loop', () async {
        fake.duration = const Duration(seconds: 10);
        final audio = createAttachmentPlayer(
          video: false,
          platform: TargetPlatform.android,
        );
        await audio.open(AttachmentSource.file(File('/tmp/raft-test/a.wav')));
        await audio.dispose();
        expect(switchedOn(), 0);
        final video = createAttachmentPlayer(platform: TargetPlatform.android);
        await video.open(AttachmentSource.file(File('/tmp/raft-test/v.mp4')));
        await video.dispose();
        expect(switchedOn(), 1);
      });

      test('a re-signed clip keeps looping', () async {
        fake.duration = const Duration(seconds: 10);
        final player = VideoPlayerAttachmentPlayer();
        await player.open(AttachmentSource.file(File('/tmp/raft-test/c.mp4')));
        await player.open(AttachmentSource.file(File('/tmp/raft-test/c.mp4')));
        await Future<void>.delayed(Duration.zero);
        await player.dispose();
        expect(switchedOn(), 2);
      });
    });

    test('opens paused and maps state', () async {
      final player = VideoPlayerAttachmentPlayer();
      final seen = <AttachmentPlayback>[];
      player.changes.listen(seen.add);
      await player.open(AttachmentSource.file(File('/tmp/raft-test/clip one.mp4')));
      await Future<void>.delayed(Duration.zero);
      expect(fake.sources.single.sourceType, DataSourceType.file);
      expect(fake.sources.single.uri, startsWith('file:///'));
      expect(fake.calls, isNot(contains('play')));
      final first = seen.last;
      expect(first.playing, false);
      expect(first.error, false);
      expect(first.duration, const Duration(seconds: 10));
      expect(first.videoSize, const Size(1280, 720));
      expect(first.volume, 100);
      expect(first.hasFrame, false);

      await player.toggle();
      await Future<void>.delayed(Duration.zero);
      expect(fake.calls, contains('play'));
      expect(seen.last.playing, true);
      await player.toggle();
      await Future<void>.delayed(Duration.zero);
      expect(seen.last.playing, false);

      await player.volume(0);
      await player.volume(50);
      await player.volume(250);
      expect(fake.volumes, containsAllInOrder([0.0, 0.5, 1.0]));
      await Future<void>.delayed(Duration.zero);
      expect(seen.last.volume, 100);

      await player.seek(const Duration(seconds: 4));
      await player.seek(const Duration(seconds: 99));
      await player.seek(const Duration(seconds: -3));
      expect(fake.seeks, [
        const Duration(seconds: 4),
        const Duration(seconds: 10),
        Duration.zero,
      ]);
      await player.dispose();
    });

    test('an audio file has no picture size and plays', () async {
      fake.size = Size.zero;
      final player = VideoPlayerAttachmentPlayer();
      final seen = <AttachmentPlayback>[];
      player.changes.listen(seen.add);
      await player.open(AttachmentSource.file(File('/tmp/raft-test/a.wav')));
      await player.toggle();
      await Future<void>.delayed(Duration.zero);
      expect(seen.last.videoSize, isNull);
      expect(seen.last.playing, true);
      expect(seen.last.error, false);
      await player.dispose();
    });

    test('no frame is reported before the picture was built', () async {
      final player = VideoPlayerAttachmentPlayer(transparentVideo: true);
      final seen = <AttachmentPlayback>[];
      player.changes.listen(seen.add);
      await player.open(AttachmentSource.file(File('/tmp/raft-test/c.mp4')));
      await Future<void>.delayed(Duration.zero);
      expect(seen.last.hasFrame, false);
    });

    testWidgets('video() is empty until sized, then contains the picture', (
      tester,
    ) async {
      final player = VideoPlayerAttachmentPlayer(transparentVideo: true);
      final seen = <AttachmentPlayback>[];
      player.changes.listen(seen.add);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(width: 400, height: 400, child: player.video()),
          ),
        ),
      );
      expect(find.byKey(const Key('texture')), findsNothing);
      await tester.runAsync(() => player.open(AttachmentSource.file(File('/tmp/raft-test/c.mp4'))));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('texture')), findsOneWidget);
      expect(tester.getSize(find.byType(AspectRatio)), const Size(400, 225));
      expect(seen.last.hasFrame, true);
      final colored = tester.widget<ColoredBox>(find.byType(ColoredBox).first);
      expect(colored.color, const Color(0x00000000));
      await tester.runAsync(player.dispose);
    });

    test('a failed open publishes the failure and throws', () async {
      fake.failOpen = true;
      final player = VideoPlayerAttachmentPlayer();
      final seen = <AttachmentPlayback>[];
      player.changes.listen(seen.add);
      await expectLater(
        player.open(AttachmentSource.file(File('/tmp/raft-test/bad.mp4'))),
        throwsA(anything),
      );
      await Future<void>.delayed(Duration.zero);
      expect(seen.any((e) => e.error), true);
      await player.dispose();
    });

    test('a playback error is a failure; buffering is not', () async {
      final player = VideoPlayerAttachmentPlayer();
      final seen = <AttachmentPlayback>[];
      player.changes.listen(seen.add);
      await player.open(AttachmentSource.file(File('/tmp/raft-test/c.mp4')));
      fake.streams[0]!.add(
        VideoEvent(eventType: VideoEventType.bufferingStart),
      );
      fake.streams[0]!.add(VideoEvent(eventType: VideoEventType.bufferingEnd));
      await Future<void>.delayed(Duration.zero);
      expect(seen.any((e) => e.error), false);
      fake.streams[0]!.addError(
        PlatformException(code: 'VideoError', message: 'decoder'),
      );
      await Future<void>.delayed(Duration.zero);
      expect(seen.last.error, true);
      // The failure is sticky and the known length is kept.
      expect(seen.last.duration, const Duration(seconds: 10));
      await player.dispose();
    });

    test('toggle after the end restarts from the beginning', () async {
      final player = VideoPlayerAttachmentPlayer();
      await player.open(AttachmentSource.file(File('/tmp/raft-test/c.mp4')));
      fake.streams[0]!.add(VideoEvent(eventType: VideoEventType.completed));
      await Future<void>.delayed(Duration.zero);
      fake.calls.clear();
      await player.toggle();
      expect(fake.calls, containsAllInOrder(['seek', 'play']));
      expect(fake.seeks.last, Duration.zero);
      await player.dispose();
    });

    test(
      'dispose releases the native player once and closes the stream',
      () async {
        final player = VideoPlayerAttachmentPlayer();
        var done = false;
        player.changes.listen((_) {}, onDone: () => done = true);
        await player.open(AttachmentSource.file(File('/tmp/raft-test/c.mp4')));
        await player.dispose();
        await player.dispose();
        await Future<void>.delayed(Duration.zero);
        expect(fake.calls.where((c) => c == 'dispose'), hasLength(1));
        expect(done, true);
        // Late calls are ignored, not forwarded to a released player.
        fake.calls.clear();
        await player.toggle();
        await player.pause();
        await player.seek(Duration.zero);
        await player.volume(10);
        expect(fake.calls, isEmpty);
      },
    );

    test('leaving the app pauses and returning does not resume', () async {
      final player = VideoPlayerAttachmentPlayer();
      await player.open(AttachmentSource.file(File('/tmp/raft-test/c.mp4')));
      await player.toggle();
      fake.calls.clear();
      player.didChangeAppLifecycleState(AppLifecycleState.paused);
      await Future<void>.delayed(Duration.zero);
      expect(fake.calls, ['pause']);
      player.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      expect(fake.calls, ['pause']);
      await player.dispose();
    });

    test(
      'a hidden window (macOS) pauses and showing it does not resume',
      () async {
        final player = VideoPlayerAttachmentPlayer();
        await player.open(AttachmentSource.file(File('/tmp/raft-test/d.mp4')));
        await player.toggle();
        fake.calls.clear();
        player.didChangeAppLifecycleState(AppLifecycleState.inactive);
        await Future<void>.delayed(Duration.zero);
        expect(fake.calls, isEmpty);
        player.didChangeAppLifecycleState(AppLifecycleState.hidden);
        await Future<void>.delayed(Duration.zero);
        expect(fake.calls, ['pause']);
        player.didChangeAppLifecycleState(AppLifecycleState.inactive);
        player.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await Future<void>.delayed(Duration.zero);
        expect(fake.calls, ['pause']);
        await player.dispose();
      },
    );
  });

  group('streaming a network URL', () {
    final url = Uri.parse('https://storage.invalid/a.mp4?sig=1');

    test('opens the URL itself: no file, no header, never a download', () async {
      final player = VideoPlayerAttachmentPlayer();
      await player.open(AttachmentSource.network(url));
      expect(fake.sources.single.sourceType, DataSourceType.network);
      expect(fake.sources.single.uri, url.toString());
      expect(fake.sources.single.httpHeaders, isEmpty);
      await player.dispose();
    });

    test('a start position is seeked to once the stream is open', () async {
      final player = VideoPlayerAttachmentPlayer();
      await player.open(
        AttachmentSource.network(url, start: const Duration(seconds: 7)),
      );
      expect(fake.seeks, [const Duration(seconds: 7)]);
      await player.dispose();
    });

    test('an open that fails is retried once with a freshly signed URL', () async {
      final player = VideoPlayerAttachmentPlayer();
      fake.failures = 1;
      var signed = 0;
      await player.open(
        AttachmentSource.network(
          url,
          refresh: () async {
            signed++;
            return Uri.parse('https://storage.invalid/a.mp4?sig=2');
          },
        ),
      );
      expect(signed, 1);
      expect(fake.sources.map((s) => s.uri), [
        url.toString(),
        'https://storage.invalid/a.mp4?sig=2',
      ]);
      expect(player.playback.error, isFalse);
      await player.dispose();
    });

    // Regression (CodexMac's review repro): the first open of a resumed
    // stream failed on an expired URL and the re-sign reopened at zero.
    test('re-sign during open preserves requested resume position', () async {
      final player = VideoPlayerAttachmentPlayer();
      fake.failures = 1;
      await player.open(
        AttachmentSource.network(
          url,
          start: const Duration(seconds: 7),
          refresh: () async => Uri.parse('https://storage.invalid/a.mp4?sig=2'),
        ),
      );
      final seeks = fake.seeks.toList();
      await player.dispose();
      expect(
        seeks,
        contains(const Duration(seconds: 7)),
        reason: 'Expired URL at resume must not restart from zero.',
      );
    });

    test('a second failure is final: one re-sign per source', () async {
      final player = VideoPlayerAttachmentPlayer();
      fake.failures = 2;
      var signed = 0;
      await expectLater(
        player.open(
          AttachmentSource.network(
            url,
            refresh: () async {
              signed++;
              return url;
            },
          ),
        ),
        throwsA(anything),
      );
      expect(signed, 1);
      expect(player.playback.error, isTrue);
      await player.dispose();
    });

    test('a file source has no re-sign and fails at once', () async {
      final player = VideoPlayerAttachmentPlayer();
      fake.failures = 1;
      await expectLater(
        player.open(AttachmentSource.file(File('/tmp/raft-test/c.mp4'))),
        throwsA(anything),
      );
      expect(fake.sources, hasLength(1));
      await player.dispose();
    });

    test('live players are counted until disposed', () async {
      final before = VideoPlayerAttachmentPlayer.debugLive;
      final player = VideoPlayerAttachmentPlayer();
      await player.open(AttachmentSource.network(url));
      expect(VideoPlayerAttachmentPlayer.debugLive, before + 1);
      await player.dispose();
      expect(VideoPlayerAttachmentPlayer.debugLive, before);
    });

    test('buffering is published and the last state is readable', () async {
      final player = VideoPlayerAttachmentPlayer();
      await player.open(AttachmentSource.network(url));
      expect(player.playback.duration, const Duration(seconds: 10));
      fake.streams[0]!.add(VideoEvent(eventType: VideoEventType.bufferingStart));
      await Future<void>.delayed(Duration.zero);
      expect(player.playback.buffering, isTrue);
      fake.streams[0]!.add(VideoEvent(eventType: VideoEventType.bufferingEnd));
      await Future<void>.delayed(Duration.zero);
      expect(player.playback.buffering, isFalse);
      await player.dispose();
    });
  });
}

class _Stub implements AttachmentPlayer {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
