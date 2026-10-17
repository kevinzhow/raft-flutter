import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

import 'attachment_player.dart';
import 'attachment_player_log.dart';
import 'media_failure.dart';
import 'media_probe.dart';
import 'video_frame_probe.dart';

/// Windows and Linux: the first picture of a video through a one-off, muted,
/// paused libmpv player (media_kit), the engine that plays video there.
///
/// How the picture is made: the player has no video output (`vo=null`, so no
/// window, no GL, no Xvfb needed), decodes the first frame while paused, and
/// mpv's `screenshot-to-file` writes it as a JPEG (mpv encodes, at
/// `screenshot-jpeg-quality`). The longest edge is limited by an mpv video
/// filter, so a 1080p frame is scaled before it is encoded. The screenshot
/// applies the container rotation on Linux; Windows carries it in EXIF
/// orientation. Nothing is decoded or encoded in Dart.
///
/// Only the byte ranges libmpv needs are read: the demuxer buffer is tiny
/// (`demuxer-max-bytes`, no read-ahead, no cache), so a moov-first file costs
/// the header plus the first key frame, and a moov-last file one more ranged
/// read at the end. [probe] gives up past `maxBytes` (the stream position the
/// demuxer reached) or `timeout`.
///
/// One player lives per probe and it is always disposed: after a frame, a
/// failure, a timeout and a [cancel].
class MpvVideoFrameProbe implements VideoFrameProbe {
  MpvVideoFrameProbe({
    MpvFrameSession Function()? sessionFactory,
    this.pollInterval = const Duration(milliseconds: 50),
  }) : _sessionFactory = sessionFactory ?? LibmpvFrameSession.new;

  final MpvFrameSession Function() _sessionFactory;

  /// How often the probe looks at its player.
  final Duration pollInterval;

  final _active = <String, _Probe>{};

  /// Probes still running (a leak check for tests and the integration run).
  @visibleForTesting
  int get activeCount => _active.length;

  @override
  Future<VideoFrameInfo> probe({
    required String id,
    required Uri url,
    Map<String, String> headers = const {},
    int maxEdge = 640,
    Duration timeout = const Duration(seconds: 20),
    int maxBytes = 16 * 1024 * 1024,
  }) async {
    // A second probe under the same id replaces the first.
    final previous = _active[id];
    final active = _active[id] = _Probe();
    if (previous != null) previous.cancel();
    try {
      await previous?.done;
      return await _run(active, url, headers, maxEdge, timeout, maxBytes);
    } finally {
      if (identical(_active[id], active)) _active.remove(id);
      active.finish();
    }
  }

  @override
  Future<void> cancel(String id) async {
    final active = _active[id];
    if (active == null) return;
    active.cancel();
    await active.done;
  }

  Future<VideoFrameInfo> _run(
    _Probe active,
    Uri url,
    Map<String, String> headers,
    int maxEdge,
    Duration timeout,
    int maxBytes,
  ) async {
    if (active.cancelled) {
      throw const VideoFrameException(VideoFrameFailure.cancelled);
    }
    if (url.scheme != 'http' && url.scheme != 'https') {
      throw const VideoFrameException(
        VideoFrameFailure.failed,
        'not a network URL',
      );
    }
    final clock = Stopwatch()..start();
    MpvFrameSession? session;

    /// Races [work] with the cancel request and the time budget, so a stuck
    /// libmpv call cannot hold the probe past either.
    Future<T> guarded<T>(Future<T> work) {
      final left = timeout - clock.elapsed;
      if (left <= Duration.zero) {
        work.ignore();
        throw const VideoFrameException(VideoFrameFailure.failed, 'timeout');
      }
      final gate = Completer<T>();
      final timer = Timer(left, () {
        if (!gate.isCompleted) {
          gate.completeError(
            const VideoFrameException(VideoFrameFailure.failed, 'timeout'),
          );
        }
      });
      final unlisten = active.onCancel(() {
        if (!gate.isCompleted) {
          gate.completeError(
            const VideoFrameException(VideoFrameFailure.cancelled),
          );
        }
      });
      work.then(
        (value) {
          if (!gate.isCompleted) gate.complete(value);
        },
        onError: (Object error, StackTrace stack) {
          if (!gate.isCompleted) gate.completeError(error, stack);
        },
      );
      return gate.future.whenComplete(() {
        timer.cancel();
        unlisten();
      });
    }

    try {
      session = _sessionFactory();
      await guarded(
        session.open(
          MpvFrameRequest(
            url: url,
            headers: headers,
            maxEdge: maxEdge,
            maxBytes: maxBytes,
          ),
        ),
      );
      while (true) {
        if (active.cancelled) {
          throw const VideoFrameException(VideoFrameFailure.cancelled);
        }
        if (clock.elapsed >= timeout) {
          throw const VideoFrameException(VideoFrameFailure.failed, 'timeout');
        }
        if (session.failed) {
          throw await _classify(active, session, url, headers);
        }
        final snap = await guarded(session.snapshot());
        if (snap.streamPosition > maxBytes) {
          throw VideoFrameException(
            VideoFrameFailure.failed,
            'byte budget spent (${snap.streamPosition} > $maxBytes)',
          );
        }
        if (snap.hasSize) {
          final jpeg = await guarded(session.grab());
          if (jpeg != null) {
            // The rotation (a property of the decoded frame) and the duration
            // are final only now: read them after the picture.
            final done = await guarded(session.snapshot(settled: true));
            final size = displaySize(done.width, done.height, done.rotation);
            return VideoFrameInfo(
              width: size.$1,
              height: size.$2,
              rotation: normalizeRotation(done.rotation),
              duration: done.duration,
              jpeg: jpeg,
            );
          }
        }
        await guarded(Future<void>.delayed(pollInterval));
      }
    } on VideoFrameException catch (error) {
      // ignore: raft_lints/avoid_caught_exception_text -- The message is one of this file's fixed words ('timeout', 'byte budget spent ...'); it goes to stderr only, never to the UI.
      _log('raft.media: frame probe ${error.kind.name} ${error.message ?? ''}');
      rethrow;
    } on Object catch (error) {
      // A libmpv or file-system error: the frame is not available here.
      // Only the type of a libmpv or file-system error is logged (its text can carry a path or URL).
      _log('raft.media: frame probe failed ${error.runtimeType}');
      throw const VideoFrameException(VideoFrameFailure.failed, 'player error');
    } finally {
      final owned = session;
      if (owned != null) {
        try {
          await owned.dispose();
        } on Object catch (error) {
          _log('raft.media: frame probe dispose ${error.runtimeType}');
        }
      }
    }
  }

  /// The failure libmpv reported: the log text first; when it names no cause,
  /// one tiny ranged request through the same proxy decision
  /// ([MediaDiagnosis]). Only an expired signature has its own class.
  Future<VideoFrameException> _classify(
    _Probe active,
    MpvFrameSession session,
    Uri url,
    Map<String, String> headers,
  ) async {
    // The log is asynchronous: the cause line can land just after the failure.
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (active.cancelled) {
      return const VideoFrameException(VideoFrameFailure.cancelled);
    }
    if (session.noVideo) {
      return const VideoFrameException(
        VideoFrameFailure.failed,
        'no video stream',
      );
    }
    final MediaFailure found;
    try {
      found = await MediaDiagnosis.diagnose(
        text: session.evidence,
        url: url,
        headers: headers,
        playerFollowsApp: true,
      );
    } on Object {
      return const VideoFrameException(VideoFrameFailure.failed, 'unknown');
    }
    if (active.cancelled) {
      return const VideoFrameException(VideoFrameFailure.cancelled);
    }
    return failureOf(found);
  }

  /// Only 401, 403 and 410 (an expired signature) have a class of their own.
  @visibleForTesting
  static VideoFrameException failureOf(MediaFailure found) =>
      VideoFrameException(
        found.kind == MediaFailureKind.expired
            ? VideoFrameFailure.expired
            : VideoFrameFailure.failed,
        found.kind.name,
      );

  /// The displayed size of a picture stored as [width] x [height] with the
  /// container asking for [rotation] degrees: 90 and 270 swap the sides.
  @visibleForTesting
  static (int, int) displaySize(int width, int height, int rotation) =>
      normalizeRotation(rotation) % 180 == 0
      ? (width, height)
      : (height, width);

  /// [degrees] folded into 0, 90, 180 or 270 (the nearest right angle).
  @visibleForTesting
  static int normalizeRotation(int degrees) {
    final folded = ((degrees % 360) + 360) % 360;
    return (((folded + 45) ~/ 90) * 90) % 360;
  }

  /// The mpv `vf` that limits the longest edge of the stored picture to
  /// [maxEdge] and never enlarges it. The container rotation does not change
  /// which edge is longest, and the screenshot applies it afterwards.
  @visibleForTesting
  static String scaleFilter(int maxEdge) {
    final edge = maxEdge < 16 ? 16 : maxEdge;
    return "lavfi=[scale=w='if(gt(iw,ih),min(iw,$edge),-2)':"
        "h='if(gt(iw,ih),-2,min(ih,$edge))':flags=bicubic]";
  }

  static void _log(String line) {
    try {
      stderr.writeln(line);
    } on Object {
      // stderr may be closed (detached GUI session); logging is best effort.
    }
  }
}

/// Bookkeeping of one running probe: cancel request and completion.
class _Probe {
  bool cancelled = false;
  final _cancelListeners = <void Function()>[];
  final _done = Completer<void>();

  Future<void> get done => _done.future;

  void cancel() {
    if (cancelled) return;
    cancelled = true;
    for (final listener in List.of(_cancelListeners)) {
      listener();
    }
    _cancelListeners.clear();
  }

  /// Calls [listener] when the probe is cancelled (at once when it already
  /// is); the result removes it again.
  void Function() onCancel(void Function() listener) {
    if (cancelled) {
      listener();
      return () {};
    }
    _cancelListeners.add(listener);
    return () => _cancelListeners.remove(listener);
  }

  void finish() {
    _cancelListeners.clear();
    if (!_done.isCompleted) _done.complete();
  }
}

/// What a session is asked to open.
@immutable
class MpvFrameRequest {
  const MpvFrameRequest({
    required this.url,
    required this.headers,
    required this.maxEdge,
    required this.maxBytes,
  });
  final Uri url;
  final Map<String, String> headers;
  final int maxEdge, maxBytes;
}

/// What the probe sees of a session at one moment. [width] and [height] are
/// the stored picture size (before [rotation]).
@immutable
class MpvFrameSnapshot {
  const MpvFrameSnapshot({
    this.width = 0,
    this.height = 0,
    this.rotation = 0,
    this.duration = Duration.zero,
    this.streamPosition = 0,
  });
  final int width, height, rotation;
  final Duration duration;

  /// How far into the file the demuxer has read (a stand-in for the bytes
  /// read, which libmpv does not report).
  final int streamPosition;
  bool get hasSize => width > 0 && height > 0;
}

/// One libmpv player used once. The seam of [MpvVideoFrameProbe]: tests pass
/// a fake; [LibmpvFrameSession] is the real one.
abstract interface class MpvFrameSession {
  /// libmpv said the input cannot be played (see [isPlaybackFailure]).
  bool get failed;

  /// The input has no picture to show (an audio-only file).
  bool get noVideo;

  /// The libmpv text since [open] that a failure is classified from.
  String get evidence;
  Future<void> open(MpvFrameRequest request);

  ///
  /// [settled]: the picture is out, so read the final values from libmpv
  /// itself (the state stream can lag behind it).
  Future<MpvFrameSnapshot> snapshot({bool settled = false});

  /// The JPEG of the current picture, or null when there is none yet.
  Future<Uint8List?> grab();

  /// Stops the player and frees everything it holds. Idempotent.
  Future<void> dispose();
}

/// A libmpv instance kept between probes (see [LibmpvPlayerPool]).
abstract interface class PooledPlayer {
  /// Stops what it plays, closes its connection and forgets the last probe.
  Future<void> reset();

  /// Ends the instance for good.
  Future<void> dispose();
}

/// The libmpv players of the frame probe, kept between probes.
///
/// Creating and disposing a media_kit `Player` per probe was measured on
/// Linux: every instance runs its own Lua script VMs and ends 5 s after
/// `dispose`, resident memory grew about 40 MB per probe and, once the dying
/// instances overlapped, the next `Player` never finished initialising (the
/// probe hung). Reusing a player is flat (60 probes: +28 MB, stable threads).
/// So a probe leases a player, the pool stops it after the probe and keeps up
/// to [maxIdle] of them for [idleFor], then disposes them. A player that
/// fails to reset is disposed instead of reused.
class LibmpvPlayerPool<T extends PooledPlayer> {
  LibmpvPlayerPool(
    this._create, {
    this.maxIdle = 2,
    this.idleFor = const Duration(seconds: 20),
    this.settle = const Duration(seconds: 3),
  });

  /// The pool of the app.
  static final LibmpvPlayerPool<LibmpvPlayer> shared = LibmpvPlayerPool(
    LibmpvPlayer.new,
  );

  final T Function() _create;
  final int maxIdle;
  final Duration idleFor, settle;
  final _idle = <T>[];
  Timer? _timer;

  /// Players alive: idle ones plus those leased.
  int get alive => _idle.length + _leased;
  int get idleCount => _idle.length;
  int _leased = 0;

  /// How many players were ever created and ended (tests, diagnostics).
  int created = 0, ended = 0;

  /// An idle player, or a new one.
  T acquire() {
    _timer?.cancel();
    _timer = null;
    final T player;
    if (_idle.isNotEmpty) {
      player = _idle.removeLast();
    } else {
      player = _create();
      created++;
    }
    _leased++;
    return player;
  }

  /// Gives [player] back. Reused when [reusable] and it resets cleanly.
  Future<void> release(T player, {bool reusable = true}) async {
    var keep = reusable && _idle.length < maxIdle;
    if (keep) {
      try {
        await player.reset().timeout(settle);
      } on Object {
        keep = false;
      }
    }
    _leased--;
    keep = keep && _idle.length < maxIdle;
    if (keep) {
      _idle.add(player);
      _arm();
    } else {
      await _end(player);
    }
  }

  void _arm() {
    _timer?.cancel();
    _timer = Timer(idleFor, () {
      _timer = null;
      unawaited(_endIdle());
    });
  }

  Future<void> _endIdle() async {
    final players = List.of(_idle);
    _idle.clear();
    for (final player in players) {
      await _end(player);
    }
  }

  Future<void> _end(T player) async {
    ended++;
    try {
      // A player stuck in its start-up never answers; do not wait for it.
      await player.dispose().timeout(settle);
    } on Object {
      // best effort
    }
  }

  /// Ends the idle players now (app shutdown, sign-out, tests). Players of
  /// running probes come back to the pool when their probe ends.
  Future<void> drain() async {
    _timer?.cancel();
    _timer = null;
    await _endIdle();
  }
}

/// A media_kit player configured for taking one picture of a video.
class LibmpvPlayer implements PooledPlayer {
  LibmpvPlayer() {
    MediaKit.ensureInitialized();
    player = Player(
      configuration: const PlayerConfiguration(
        // The video's own http(s) URL is streamed (mpv does its own
        // networking, through the proxy decision); nothing else.
        protocolWhitelist: ['file', 'http', 'https', 'tcp', 'tls', 'crypto'],
        libass: false,
        // No video output: no window, no GL context. mpv still decodes the
        // first frame and can write it with `screenshot-to-file`.
        vo: 'null',
        muted: true,
        bufferSize: 2 * 1024 * 1024,
        logLevel: MPVLogLevel.warn,
      ),
    );
    _subscriptions.add(player.stream.error.listen((text) => sink?.error(text)));
    _subscriptions.add(player.stream.log.listen((event) => sink?.log(event)));
  }

  late final Player player;
  final _subscriptions = <StreamSubscription<dynamic>>[];

  /// The probe using the player now.
  LibmpvFrameSession? sink;
  bool _disposed = false;

  NativePlayer get native => player.platform! as NativePlayer;

  @override
  Future<void> reset() async {
    sink = null;
    if (_disposed) throw StateError('disposed');
    await native.command(['stop']);
    // The log is asynchronous: let the last lines of the probe land before
    // the next one starts listening.
    await Future<void>.delayed(const Duration(milliseconds: 80));
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    sink = null;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    await player.dispose();
  }
}

/// The media_kit/libmpv [MpvFrameSession]: one lease of a [LibmpvPlayer].
class LibmpvFrameSession implements MpvFrameSession {
  LibmpvFrameSession([LibmpvPlayerPool<LibmpvPlayer>? pool])
    : _pool = pool ?? LibmpvPlayerPool.shared;

  final LibmpvPlayerPool<LibmpvPlayer> _pool;
  LibmpvPlayer? _player;
  Future<void>? _opening;
  final _recent = <String>[];
  Directory? _dir;
  bool _disposed = false;
  int _maxEdge = 640;
  (int, int)? _frameSize;

  @override
  bool failed = false;
  @override
  bool noVideo = false;
  @override
  String get evidence => _recent.join('\n');

  /// Only the lines about opening the input; decoder and output lines are
  /// about the machine and would colour the class.
  static bool _evidence(String prefix) =>
      prefix == 'ffmpeg' ||
      prefix == 'stream' ||
      prefix == 'file' ||
      prefix == 'demux' ||
      prefix == 'cplayer' ||
      prefix.startsWith('lavf');

  void _remember(String text) {
    if (_recent.length >= 24) _recent.removeAt(0);
    _recent.add(text);
  }

  /// libmpv's error stream (also fires for harmless errors; text only).
  void error(String text) => _remember(text);

  /// One libmpv log line of this probe's player.
  void log(PlayerLog event) {
    if (_evidence(event.prefix)) _remember(event.text);
    if (event.text.toLowerCase().contains(
      'no video or audio streams selected',
    )) {
      noVideo = true;
      failed = true;
    } else if (isPlaybackFailure(event.level, event.prefix, event.text)) {
      failed = true;
    }
  }

  @override
  Future<void> open(MpvFrameRequest request) => _opening = _open(request);

  Future<void> _open(MpvFrameRequest request) async {
    final player = _player = _pool.acquire();
    final native = player.native;
    final url = request.url;
    _maxEdge = request.maxEdge < 16 ? 16 : request.maxEdge;
    // Small and read-ahead free: the first picture needs the container header
    // and the first key frame, not the file. The demuxer limit is soft (it
    // always reads what the first packet needs).
    final buffer = request.maxBytes < 2 * 1024 * 1024
        ? request.maxBytes
        : 2 * 1024 * 1024;
    final properties = <(String, String)>[
      ('cache-on-disk', 'no'),
      ('access-references', 'no'),
      ('load-scripts', 'no'),
      ('ytdl', 'no'),
      ('sub-auto', 'no'),
      ('audio-file-auto', 'no'),
      ('autoload-files', 'no'),
      ('cache', 'no'),
      ('demuxer-max-bytes', '$buffer'),
      ('demuxer-max-back-bytes', '0'),
      ('demuxer-readahead-secs', '0'),
      ('network-timeout', '8'),
      // No audio in, no audio out; no subtitles.
      ('aid', 'no'),
      ('sid', 'no'),
      ('ao', 'null'),
      ('audio-display', 'no'),
      // A one-off software decode of one picture; no GPU decoder start-up.
      ('hwdec', 'no'),
      ('vd-lavc-threads', '1'),
      ('framedrop', 'vo'),
      ('hr-seek', 'yes'),
      ('screenshot-format', 'jpg'),
      ('screenshot-jpeg-quality', '80'),
      // The shipped Windows libmpv lacks scale and transpose filters. Clear
      // the pooled player's size and suppress automatic pixel rotation;
      // grab() bounds the picture and records its rotation in JPEG metadata.
      (
        'vf',
        Platform.isWindows
            ? 'format=rotate=0'
            : MpvVideoFrameProbe.scaleFilter(request.maxEdge),
      ),
      // ignore: invalid_use_of_visible_for_testing_member -- the one proxy decision of every libmpv player in the app
      ('http-proxy', NativeAttachmentPlayer.httpProxyFor(url)),
      // ignore: invalid_use_of_visible_for_testing_member -- same decision, FFmpeg side
      ('stream-lavf-o', NativeAttachmentPlayer.lavfOptionsFor(url)),
      (
        'http-header-fields',
        request.headers.entries.map((e) => '${e.key}: ${e.value}').join(','),
      ),
      ('start', 'none'),
      ('pause', 'yes'),
      // media_kit starts without a video track (nothing displays); this
      // probe is the video.
      ('vid', 'auto'),
    ];
    for (final (name, value) in properties) {
      if (_disposed) return;
      await native.setProperty(name, value);
    }
    if (_disposed) return;
    final dir = await Directory.systemTemp.createTemp('raft_frame_');
    if (_disposed) {
      await _deleteDir(dir);
      return;
    }
    _dir = dir;
    // From here on this probe owns the player's log.
    failed = false;
    noVideo = false;
    _recent.clear();
    player.sink = this;
    await native.command(['loadfile', url.toString(), 'replace']);
  }

  @override
  Future<MpvFrameSnapshot> snapshot({bool settled = false}) async {
    // The picture's own properties, read from libmpv: a pooled player keeps
    // the state of its last probe in `player.state`.
    final width = int.tryParse(await _read('video-params/w')) ?? 0;
    if (width <= 0) {
      return MpvFrameSnapshot(
        streamPosition: int.tryParse(await _read('stream-pos')) ?? 0,
      );
    }
    final seconds = double.tryParse(await _read('duration')) ?? 0;
    return MpvFrameSnapshot(
      width: width,
      height: int.tryParse(await _read('video-params/h')) ?? 0,
      rotation: int.tryParse(await _read('video-params/rotate')) ?? 0,
      // ds-allow: the length of the video, not a motion duration
      duration: Duration(milliseconds: (seconds * 1000).round()),
      streamPosition: settled
          ? 0
          : int.tryParse(await _read('stream-pos')) ?? 0,
    );
  }

  Future<String> _read(String name) async {
    final player = _player;
    if (_disposed || player == null) return '';
    try {
      return await player.native.getProperty(
        name,
        waitForInitialization: false,
      );
    } on Object {
      return '';
    }
  }

  @override
  Future<Uint8List?> grab() async {
    final dir = _dir, player = _player;
    if (_disposed || dir == null || player == null) return null;
    final file = File('${dir.path}${Platform.pathSeparator}frame.jpg');
    try {
      if (Platform.isWindows && !await _sizeFrame(player.native)) return null;
      if (file.existsSync()) file.deleteSync();
      // Fails (and is retried by the probe) until mpv has shown its first frame.
      await player.native.command(['screenshot-to-file', file.path, 'video']);
      if (!file.existsSync()) return null;
      final bytes = await file.readAsBytes();
      // JPEG start-of-image marker.
      if (bytes.length < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8) return null;
      if (!Platform.isWindows) return bytes;
      final rotation = int.tryParse(await _read('video-params/rotate')) ?? 0;
      return _orientJpeg(bytes, rotation);
    } on Object {
      return null;
    }
  }

  /// Uses libswscale through mpv itself, without an optional FFmpeg filter.
  /// Do not encode until the output has changed size: a paused, reused
  /// player can still expose its previous frame while reconfiguring.
  Future<bool> _sizeFrame(NativePlayer native) async {
    var width = int.tryParse(await _read('video-params/w')) ?? 0;
    var height = int.tryParse(await _read('video-params/h')) ?? 0;
    if (width <= 0 || height <= 0) return false;
    final longest = width > height ? width : height;
    if (longest > _maxEdge) {
      if (width >= height) {
        height = (height * _maxEdge / width / 2).round() * 2;
        width = _maxEdge;
      } else {
        width = (width * _maxEdge / height / 2).round() * 2;
        height = _maxEdge;
      }
      if (width < 2) width = 2;
      if (height < 2) height = 2;
    }
    if (_frameSize != (width, height)) {
      await native.setProperty(
        'vf',
        'format=w=$width:h=$height:convert=yes:rotate=0',
      );
      _frameSize = (width, height);
    }
    return int.tryParse(await _read('video-out-params/w')) == width &&
        int.tryParse(await _read('video-out-params/h')) == height;
  }

  /// The Windows library also lacks the transpose filter used by vo=null.
  /// EXIF orientation lets the image codec display the bounded JPEG upright,
  /// without decoding, rotating or re-encoding its pixels in Dart.
  static Uint8List _orientJpeg(Uint8List bytes, int rotation) {
    final orientation = switch (MpvVideoFrameProbe.normalizeRotation(
      rotation,
    )) {
      90 => 6,
      180 => 3,
      270 => 8,
      _ => 1,
    };
    if (orientation == 1) return bytes;
    // APP1 Exif, big-endian TIFF, one SHORT Orientation entry and no next IFD.
    // dart format off
    final exif = [
      0xff, 0xd8, 0xff, 0xe1, 0, 34,
      0x45, 0x78, 0x69, 0x66, 0, 0,
      0x4d, 0x4d, 0, 42, 0, 0, 0, 8,
      0, 1, 1, 0x12, 0, 3, 0, 0, 0, 1, 0, orientation, 0, 0,
      0, 0, 0, 0,
    ];
    // dart format on
    return Uint8List.fromList([...exif, ...bytes.sublist(2)]);
  }

  static Future<void> _deleteDir(Directory dir) async {
    try {
      await dir.delete(recursive: true);
    } on Object {
      // best effort: it is the system temp directory
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final player = _player;
    // A start-up still running must end before the player can go to the next
    // probe; one that never does makes the player unfit for reuse.
    var clean = true;
    final opening = _opening;
    if (opening != null) {
      try {
        await opening.timeout(const Duration(seconds: 2));
      } on Object {
        clean = false;
      }
    }
    final dir = _dir;
    if (dir != null) await _deleteDir(dir);
    if (player != null) {
      if (identical(player.sink, this)) player.sink = null;
      await _pool.release(player, reusable: clean);
    }
  }
}
