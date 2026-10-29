import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/media_failure.dart';
import 'package:raft_flutter/platform/media_probe.dart';
import 'package:raft_flutter/platform/video_frame_probe.dart';
import 'package:raft_flutter/platform/video_frame_probe_mpv.dart';

/// A libmpv stand-in: what the probe does with a player, without one.
class FakeSession implements MpvFrameSession {
  FakeSession({this.onOpen, this.size, this.rotation = 0, this.position = 0, this.grabs = 1});

  /// Runs on [open]; may fail the session or never return.
  final Future<void> Function(FakeSession session)? onOpen;

  /// The stored picture size once the "decoder" has one (null: never).
  final (int, int)? size;
  final int rotation, position;

  /// How many [grab] calls fail before one gives a picture.
  int grabs;

  @override
  bool failed = false;
  @override
  bool noVideo = false;
  @override
  String evidence = '';
  int opened = 0, disposed = 0, grabCalls = 0;
  MpvFrameRequest? request;

  @override
  Future<void> open(MpvFrameRequest request) async {
    opened++;
    this.request = request;
    await onOpen?.call(this);
  }

  @override
  Future<MpvFrameSnapshot> snapshot({bool settled = false}) async => MpvFrameSnapshot(
    width: size?.$1 ?? 0,
    height: size?.$2 ?? 0,
    rotation: rotation,
    duration: size == null ? Duration.zero : const Duration(seconds: 12),
    streamPosition: position,
  );

  @override
  Future<Uint8List?> grab() async {
    grabCalls++;
    if (grabs-- > 1) return null;
    return Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]);
  }

  @override
  Future<void> dispose() async => disposed++;
}

final _url = Uri.parse('https://files.example/video.mp4?sig=secret');

void main() {
  final sessions = <FakeSession>[];
  Future<MediaFailure?> Function(Uri, Map<String, String>, String?)? probeBackup;
  var diagnosed = 0;

  MpvVideoFrameProbe probeOf(FakeSession Function() make) => MpvVideoFrameProbe(
    pollInterval: const Duration(milliseconds: 5),
    sessionFactory: () {
      final session = make();
      sessions.add(session);
      return session;
    },
  );

  setUp(() {
    sessions.clear();
    diagnosed = 0;
    probeBackup = MediaDiagnosis.probe;
    // The tiny ranged request of the diagnosis, answered by the test.
    MediaDiagnosis.probe = (url, headers, proxy) async {
      diagnosed++;
      return MediaDiagnosis.probeStatus(403);
    };
  });
  tearDown(() => MediaDiagnosis.probe = probeBackup!);

  group('size, rotation and scaling', () {
    test('rotation folds to the nearest right angle', () {
      expect(MpvVideoFrameProbe.normalizeRotation(0), 0);
      expect(MpvVideoFrameProbe.normalizeRotation(90), 90);
      expect(MpvVideoFrameProbe.normalizeRotation(-90), 270);
      expect(MpvVideoFrameProbe.normalizeRotation(450), 90);
      expect(MpvVideoFrameProbe.normalizeRotation(180), 180);
      expect(MpvVideoFrameProbe.normalizeRotation(359), 0);
      expect(MpvVideoFrameProbe.normalizeRotation(44), 0);
    });

    test('90 and 270 swap the sides, 0 and 180 keep them', () {
      expect(MpvVideoFrameProbe.displaySize(1280, 720, 0), (1280, 720));
      expect(MpvVideoFrameProbe.displaySize(1280, 720, 90), (720, 1280));
      expect(MpvVideoFrameProbe.displaySize(1280, 720, 180), (1280, 720));
      expect(MpvVideoFrameProbe.displaySize(1280, 720, 270), (720, 1280));
      expect(MpvVideoFrameProbe.displaySize(1280, 720, -90), (720, 1280));
    });

    test('the scale filter limits the longest edge and never enlarges', () {
      final filter = MpvVideoFrameProbe.scaleFilter(640);
      expect(filter, startsWith('lavfi=[scale='));
      // landscape: width limited, height follows; portrait the other way.
      expect(filter, contains("w='if(gt(iw,ih),min(iw,640),-2)'"));
      expect(filter, contains("h='if(gt(iw,ih),-2,min(ih,640))'"));
      expect(MpvVideoFrameProbe.scaleFilter(200), contains('min(iw,200)'));
      // A silly limit is raised, so the filter stays valid.
      expect(MpvVideoFrameProbe.scaleFilter(0), contains('min(iw,16)'));
    });

    test('only an expired signature has its own failure class', () {
      expect(
        MpvVideoFrameProbe.failureOf(const MediaFailure(MediaFailureKind.expired)).kind,
        VideoFrameFailure.expired,
      );
      for (final kind in MediaFailureKind.values.where((k) => k != MediaFailureKind.expired)) {
        expect(MpvVideoFrameProbe.failureOf(MediaFailure(kind)).kind, VideoFrameFailure.failed, reason: '$kind');
      }
    });
  });

  group('probe', () {
    test('returns the displayed size, the rotation and the picture', () async {
      final probe = probeOf(() => FakeSession(size: (1280, 720), rotation: 90, grabs: 3));
      final info = await probe.probe(id: 'a', url: _url, maxEdge: 480, maxBytes: 1000);
      expect((info.width, info.height), (720, 1280));
      expect(info.rotation, 90);
      expect(info.duration, const Duration(seconds: 12));
      expect(info.jpeg, isNotNull);
      expect(sessions.single.grabCalls, 3, reason: 'retried until mpv had its first frame');
      expect(sessions.single.request!.maxEdge, 480);
      expect(sessions.single.request!.maxBytes, 1000);
      expect(sessions.single.disposed, 1);
      expect(probe.activeCount, 0);
    });

    test('a URL that is not http(s) never starts a player', () async {
      final probe = probeOf(FakeSession.new);
      await expectLater(
        probe.probe(id: 'a', url: Uri.parse('file:///etc/passwd')),
        throwsA(isA<VideoFrameException>().having((e) => e.kind, 'kind', VideoFrameFailure.failed)),
      );
      expect(sessions, isEmpty);
    });

    test('a refused signature is "expired" and the ranged request decides it', () async {
      final probe = probeOf(() => FakeSession(onOpen: (s) async {
        s.failed = true;
        s.evidence = 'Failed to open [url].';
      }));
      await expectLater(
        probe.probe(id: 'a', url: _url),
        throwsA(isA<VideoFrameException>().having((e) => e.kind, 'kind', VideoFrameFailure.expired)),
      );
      expect(diagnosed, 1);
      expect(sessions.single.disposed, 1);
      expect(probe.activeCount, 0);
    });

    test('a failure that names its cause needs no request', () async {
      final probe = probeOf(() => FakeSession(onOpen: (s) async {
        s.failed = true;
        s.evidence = 'ffmpeg: HTTP error 403 Forbidden';
      }));
      await expectLater(
        probe.probe(id: 'a', url: _url),
        throwsA(isA<VideoFrameException>().having((e) => e.kind, 'kind', VideoFrameFailure.expired)),
      );
      expect(diagnosed, 0);
    });

    test('a host that serves the bytes but a file that does not decode is "failed"', () async {
      MediaDiagnosis.probe = (url, headers, proxy) async => MediaDiagnosis.probeStatus(206);
      final probe = probeOf(() => FakeSession(onOpen: (s) async {
        s.failed = true;
        s.evidence = 'Failed to recognize file format.';
      }));
      await expectLater(
        probe.probe(id: 'a', url: _url),
        throwsA(isA<VideoFrameException>().having((e) => e.kind, 'kind', VideoFrameFailure.failed)),
      );
    });

    test('an audio-only file is "failed" without asking the host', () async {
      final probe = probeOf(() => FakeSession(onOpen: (s) async {
        s.failed = true;
        s.noVideo = true;
      }));
      await expectLater(
        probe.probe(id: 'a', url: _url),
        throwsA(isA<VideoFrameException>().having((e) => e.kind, 'kind', VideoFrameFailure.failed)),
      );
      expect(diagnosed, 0);
      expect(sessions.single.disposed, 1);
    });

    test('the time budget ends a probe that never sees a picture', () async {
      final probe = probeOf(FakeSession.new);
      final clock = Stopwatch()..start();
      await expectLater(
        probe.probe(id: 'a', url: _url, timeout: const Duration(milliseconds: 150)),
        throwsA(isA<VideoFrameException>().having((e) => e.kind, 'kind', VideoFrameFailure.failed)),
      );
      expect(clock.elapsedMilliseconds, lessThan(1500));
      expect(sessions.single.disposed, 1);
      expect(probe.activeCount, 0);
    });

    test('a libmpv call that never returns cannot hold the probe past the budget', () async {
      final probe = probeOf(() => FakeSession(onOpen: (s) => Completer<void>().future));
      await expectLater(
        probe.probe(id: 'a', url: _url, timeout: const Duration(milliseconds: 150)),
        throwsA(isA<VideoFrameException>().having((e) => e.kind, 'kind', VideoFrameFailure.failed)),
      );
      expect(sessions.single.disposed, 1);
    });

    test('the byte budget ends a probe whose demuxer read too far', () async {
      final probe = probeOf(() => FakeSession(size: (1280, 720), position: 5000));
      await expectLater(
        probe.probe(id: 'a', url: _url, maxBytes: 1000),
        throwsA(isA<VideoFrameException>().having((e) => e.kind, 'kind', VideoFrameFailure.failed)),
      );
      expect(sessions.single.grabCalls, 0, reason: 'no picture is taken past the budget');
      expect(sessions.single.disposed, 1);
    });

    test('a player that fails to dispose does not turn a picture into a failure', () async {
      final probe = probeOf(() => _ThrowingDispose(size: (720, 1280)));
      final info = await probe.probe(id: 'a', url: _url);
      expect(info.jpeg, isNotNull);
      expect(probe.activeCount, 0);
    });
  });

  group('cancel', () {
    test('stops the matching probe, disposes its player and ends before it returns', () async {
      final probe = probeOf(FakeSession.new);
      final other = probe.probe(id: 'other', url: _url, timeout: const Duration(milliseconds: 400));
      final outcome = probe.probe(id: 'mine', url: _url).then<Object?>((v) => v, onError: (Object e) => e);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(probe.activeCount, 2);
      await probe.cancel('mine');
      expect(probe.activeCount, 1);
      final result = await outcome;
      expect(result, isA<VideoFrameException>().having((e) => e.kind, 'kind', VideoFrameFailure.cancelled));
      expect(sessions[1].disposed, 1);
      expect(sessions[0].disposed, 0, reason: 'the other probe is untouched');
      await expectLater(other, throwsA(isA<VideoFrameException>()));
      expect(sessions[0].disposed, 1);
    });

    test('works while libmpv is stuck opening', () async {
      final probe = probeOf(() => FakeSession(onOpen: (s) => Completer<void>().future));
      final outcome = probe.probe(id: 'a', url: _url).then<Object?>((v) => v, onError: (Object e) => e);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await probe.cancel('a');
      expect(await outcome, isA<VideoFrameException>().having((e) => e.kind, 'kind', VideoFrameFailure.cancelled));
      expect(sessions.single.disposed, 1);
      expect(probe.activeCount, 0);
    });

    test('is a no-op for an unknown or finished id', () async {
      final probe = probeOf(() => FakeSession(size: (10, 10)));
      await probe.cancel('nobody');
      await probe.probe(id: 'a', url: _url);
      await probe.cancel('a');
      expect(sessions.single.disposed, 1);
    });

    test('a second probe under the same id replaces the first', () async {
      final probe = probeOf(FakeSession.new);
      final first = probe.probe(id: 'a', url: _url, timeout: const Duration(seconds: 5)).then<Object?>((v) => v, onError: (Object e) => e);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final second = probe.probe(id: 'a', url: _url, timeout: const Duration(milliseconds: 100)).then<Object?>((v) => v, onError: (Object e) => e);
      expect(await first, isA<VideoFrameException>().having((e) => e.kind, 'kind', VideoFrameFailure.cancelled));
      expect(sessions[0].disposed, 1);
      await second;
      expect(sessions[1].disposed, 1);
      expect(probe.activeCount, 0);
    });
  });

  group('LibmpvPlayerPool', () {
    LibmpvPlayerPool<FakePlayer> poolOf(List<FakePlayer> made, {int maxIdle = 2, Duration idleFor = const Duration(seconds: 30), FakePlayer Function()? make}) =>
        LibmpvPlayerPool<FakePlayer>(
          () {
            final player = (make ?? FakePlayer.new)();
            made.add(player);
            return player;
          },
          maxIdle: maxIdle,
          idleFor: idleFor,
          settle: const Duration(milliseconds: 100),
        );

    test('a player is stopped and reused by the next probe', () async {
      final made = <FakePlayer>[];
      final pool = poolOf(made);
      for (var i = 0; i < 5; i++) {
        final player = pool.acquire();
        await pool.release(player);
      }
      expect(made, hasLength(1));
      expect(made.single.resets, 5);
      expect(made.single.disposes, 0);
      expect(pool.idleCount, 1);
      expect(pool.alive, 1);
      await pool.drain();
      expect(made.single.disposes, 1);
      expect(pool.alive, 0);
    });

    test('two probes at once use two players; only maxIdle are kept', () async {
      final made = <FakePlayer>[];
      final pool = poolOf(made, maxIdle: 1);
      final a = pool.acquire(), b = pool.acquire();
      expect(made, hasLength(2));
      await pool.release(a);
      await pool.release(b);
      expect(pool.idleCount, 1);
      expect(made.where((p) => p.disposes == 1), hasLength(1));
      await pool.drain();
    });

    test('a player that cannot be reset is ended, not reused', () async {
      final made = <FakePlayer>[];
      final pool = poolOf(made, make: () => FakePlayer(resetFails: true));
      await pool.release(pool.acquire());
      expect(made.single.disposes, 1);
      expect(pool.alive, 0);
      pool.acquire();
      expect(made, hasLength(2));
    });

    test('a player whose reset never returns is ended after the settle time', () async {
      final made = <FakePlayer>[];
      final pool = poolOf(made, make: () => FakePlayer(resetHangs: true));
      await pool.release(pool.acquire());
      expect(made.single.disposes, 1);
      expect(pool.alive, 0);
    });

    test('a player flagged unfit (a start-up that never ended) is ended', () async {
      final made = <FakePlayer>[];
      final pool = poolOf(made);
      await pool.release(pool.acquire(), reusable: false);
      expect(made.single.resets, 0);
      expect(made.single.disposes, 1);
    });

    test('idle players are ended after the idle time, and a new probe keeps them', () async {
      final made = <FakePlayer>[];
      final pool = poolOf(made, idleFor: const Duration(milliseconds: 80));
      await pool.release(pool.acquire());
      final again = pool.acquire();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(made.single.disposes, 0, reason: 'leased players are never reaped');
      await pool.release(again);
      expect(pool.idleCount, 1);
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(made.single.disposes, 1);
      expect(pool.alive, 0);
    });
  });
}

class FakePlayer implements PooledPlayer {
  FakePlayer({this.resetFails = false, this.resetHangs = false});
  final bool resetFails, resetHangs;
  int resets = 0, disposes = 0;

  @override
  Future<void> reset() async {
    resets++;
    if (resetFails) throw StateError('reset');
    if (resetHangs) await Completer<void>().future;
  }

  @override
  Future<void> dispose() async => disposes++;
}

class _ThrowingDispose extends FakeSession {
  _ThrowingDispose({super.size});
  @override
  Future<void> dispose() async => throw StateError('already gone');
}
