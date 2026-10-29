import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:raft_client/system_proxy.dart';

import 'attachment_player_log.dart';
import 'media_failure.dart';
import 'media_probe.dart';
import 'video_cache.dart';

/// Videos at most this long repeat by themselves (the player's own repeat
/// mode, so a loop is gapless where the platform can do it); longer ones stop
/// at the end. The one place the limit lives.
const Duration kLoopingVideoMaxDuration = Duration(seconds: 60);

/// Whether a video of [length] loops. Unknown (zero) lengths do not: nothing
/// is known about the clip yet.
bool loopsAtEnd(Duration length) =>
    length > Duration.zero && length <= kLoopingVideoMaxDuration;

class AttachmentPlayback {
  const AttachmentPlayback({
    this.playing = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.volume = 100,
    this.error = false,
    this.hasFrame = false,
    this.buffering = false,
    this.videoSize,
    this.failure,
  });

  /// [hasFrame]: the video surface has drawn its first decoded frame (the
  /// poster), so a thumbnail beneath it can go.
  /// [buffering]: the player waits for data (the stream is behind the
  /// position, or a seek is being served).
  final bool playing, error, hasFrame, buffering;

  /// The video's own pixel size once mpv knows it.
  final Size? videoSize;

  /// Why playback failed, once [error] is set (null: not classified, which
  /// reads as [MediaFailureKind.unknown]).
  final MediaFailure? failure;
  final Duration position, duration;
  final double volume;
}

/// What a player opens: a private local file, or the attachment's own URL
/// (streamed: the player reads the byte ranges it needs, nothing is saved).
class AttachmentSource {
  const AttachmentSource.file(File this.file)
    : url = null,
      headers = const {},
      refresh = null,
      cacheKey = null,
      cacheAccount = null,
      start = Duration.zero;

  /// [url] is the signed attachment URL (it is the only credential: [headers]
  /// stays empty for storage hosts). [refresh] returns a freshly signed URL;
  /// the player calls it once when the host answers 401/403/410 (the
  /// signature expired) and continues from where it was. [start] is where
  /// playback begins (the viewer taking over from a card).
  const AttachmentSource.network(
    Uri this.url, {
    this.headers = const {},
    this.refresh,
    this.start = Duration.zero,
    this.cacheKey,
    this.cacheAccount,
  }) : file = null;

  final File? file;
  final Uri? url;
  final Map<String, String> headers;
  final Future<Uri> Function()? refresh;
  final Duration start;

  /// What the on-disk video cache needs to keep this video: [cacheKey] names
  /// the content (the attachment id; it must stay the same when the URL is
  /// signed again) and [cacheAccount] says whose cache it goes into. Without
  /// both the source is streamed and never cached.
  final String? cacheKey;
  final VideoCacheAccount? cacheAccount;
  bool get isNetwork => url != null;

  /// This source signed again: a new [url] (and, usually, a new [start]), the
  /// same headers and the same place in the cache. The new source has no
  /// [refresh]: a signature is renewed once.
  AttachmentSource resigned(Uri url, {required Duration start}) =>
      AttachmentSource.network(
        url,
        headers: headers,
        start: start,
        cacheKey: cacheKey,
        cacheAccount: cacheAccount,
      );
}

abstract interface class AttachmentPlayer {
  Stream<AttachmentPlayback> get changes;

  /// The last published state (a late listener starts from it).
  AttachmentPlayback get playback;

  /// The picture is a native view (`SurfaceView`, `AVPlayerLayer`) that does
  /// not move, clip or animate with Flutter content.
  bool get usesPlatformView;
  Widget video();
  Future<void> open(AttachmentSource source);
  Future<void> toggle();
  Future<void> pause();
  Future<void> seek(Duration value);
  Future<void> volume(double value);
  Future<void> dispose();
}

/// The media_kit/libmpv player, for Windows and Linux only (see
/// `createAttachmentPlayer`); the other platforms use their system player.
class NativeAttachmentPlayer implements AttachmentPlayer {
  /// [maxVideoSize] bounds the decoded picture on desktop (the surface is
  /// resized to the video's aspect inside it): an inline card never needs a
  /// 1080p software frame.
  NativeAttachmentPlayer({
    bool video = true,
    this.maxVideoSize = const Size(1920, 1080),
    this.transparentVideo = false,
  }) {
    MediaKit.ensureInitialized();
    hwdecRequested =
        parseLinuxHwdec(Platform.environment[linuxHwdecVariable]) ?? 'no';
    player = Player(
      configuration: const PlayerConfiguration(
        // The attachment's own http(s) URL is streamed (mpv does its own
        // networking, through the proxy of `applyProxy`); nothing else.
        protocolWhitelist: ['file', 'http', 'https', 'tcp', 'tls', 'crypto'],
        libass: false,
        // warn+ so the next failure carries its reason (see raft.media: lines).
        logLevel: MPVLogLevel.warn,
      ),
    );
    controller = video
        ? VideoController(
            player,
            // Linux keeps the CPU renderer (no dependency on the host's GL
            // stack, proven by the release evidence). Windows uses media_kit's
            // default GPU texture, as miraa-app does; forcing software there
            // made 30 fps swscale the desktop default. Android, iOS and macOS
            // never get here (see createAttachmentPlayer).
            configuration: Platform.isLinux
                ? VideoControllerConfiguration(
                    enableHardwareAcceleration: false,
                    // The texture path copies frames in software anyway. mpv's
                    // default `auto` probes CUDA, VDPAU, V4L2 and VAAPI from a
                    // bundled userland against the host's drivers, which only
                    // adds failures and start-up delay on Linux. Copy-back
                    // decoding is opt-in through RAFT_LINUX_HWDEC.
                    hwdec: hwdecRequested,
                  )
                : const VideoControllerConfiguration(),
          )
        : null;
    for (final stream in <Stream<dynamic>>[
      player.stream.playing,
      player.stream.position,
      player.stream.duration,
      player.stream.volume,
      player.stream.width,
      player.stream.height,
      player.stream.buffering,
    ]) {
      subscriptions.add(stream.listen((_) => publish()));
    }
    if (controller != null) {
      if (Platform.isLinux) {
        // media_kit_video's Linux software renderer derives the frame size
        // with an integer division (`width / height * 1080`) once a video is
        // taller than 1080 px, so a 720x1280 clip rendered into a 720x1080
        // texture and stayed black. Give the surface the video's own aspect
        // explicitly instead; the bound also keeps the CPU frame small.
        for (final stream in <Stream<int?>>[
          player.stream.width,
          player.stream.height,
        ]) {
          subscriptions.add(stream.listen((_) => fitSurface()));
        }
      }
      unawaited(
        controller!.waitUntilFirstFrameRendered.then((_) {
          hasFrame = true;
          publish();
          if (Platform.isLinux) unawaited(logDecoder());
        }, onError: (_) {}),
      );
    }
    // A short clip repeats by itself (mpv's loop-file), once its length is
    // known; audio never does.
    if (controller != null) {
      subscriptions.add(player.stream.duration.listen(_loopShortClip));
    }
    // media_kit's error stream also fires for harmless libmpv errors (a
    // hardware decoder that is absent, no sound card) while the video plays.
    // Failure comes from classified log lines only; every warn+ line is kept
    // in the journal, redacted, so a failure can be diagnosed afterwards.
    // The same lines (and the error stream's text) are what the failure is
    // classified from, see [onFailure].
    subscriptions.add(
      player.stream.error.listen((text) => _remember(text)),
    );
    subscriptions.add(
      player.stream.log.listen((event) {
        final line = limiter.admit(
          formatMediaLog(event.level, event.prefix, event.text),
        );
        if (line != null) _writeLog(line);
        if (_evidence(event.prefix)) _remember(event.text);
        if (isPlaybackFailure(
          event.level,
          event.prefix,
          event.text,
          video: controller != null,
        )) {
          unawaited(onFailure());
        }
      }),
    );
  }

  /// mpv's `loop-file` for a video of [length]: `inf` for a short clip,
  /// otherwise `no`.
  @visibleForTesting
  static String loopFileFor(Duration length) => loopsAtEnd(length) ? 'inf' : 'no';

  Future<void> _loopShortClip(Duration length) async {
    if (closed || length <= Duration.zero) return;
    final native = player.platform;
    if (native is! NativePlayer) return;
    try {
      await native.setProperty('loop-file', loopFileFor(length));
    } on Object {
      // Looping is a nicety; playback goes on without it.
    }
  }

  /// The libmpv text since the last open (warn and above), the evidence a
  /// failure is classified from. Bounded; never logged raw.
  final recent = <String>[];

  /// Only the lines about opening the input: decoder, audio and video output
  /// lines are about the machine and would colour the class.
  static bool _evidence(String prefix) =>
      prefix == 'ffmpeg' ||
      prefix == 'stream' ||
      prefix == 'file' ||
      prefix == 'demux' ||
      prefix == 'cplayer' ||
      prefix.startsWith('lavf');

  void _remember(String text) {
    if (recent.length >= 24) recent.removeAt(0);
    recent.add(text);
  }

  bool diagnosing = false;

  /// Counts opens, so a failure line is attributed to the attempt it belongs
  /// to (the re-sign reopens while the first failure is still being handled).
  int attempt = 0;
  int? queuedAttempt;

  /// What the user is told: the failure of the last attempt.
  MediaFailure? failure;

  /// libmpv reported that the input cannot be played. Classifies why (the
  /// log text first; when it names no cause, one probe request through the
  /// same proxy decision), signs the URL again once when that can help, and
  /// otherwise publishes the failure.
  @visibleForTesting
  Future<void> onFailure() async {
    if (failed || closed) return;
    if (diagnosing) {
      queuedAttempt = attempt;
      return;
    }
    diagnosing = true;
    final handled = attempt;
    try {
      // The log is asynchronous: the cause line can land just after the
      // `Failed to open` that triggered this.
      await Future<void>.delayed(const Duration(milliseconds: 150));
      if (closed) return;
      final current = source;
      final network = current != null && current.isNetwork;
      final found = await MediaDiagnosis.diagnose(
        text: recent.join('\n'),
        url: network ? current.url : null,
        headers: network ? current.headers : const {},
        playerFollowsApp: true,
        started: player.state.position > Duration.zero,
      );
      if (closed) return;
      _writeLog('raft.media: playback failed ${found.logLine}');
      // mpv's log does not carry the HTTP status, so like video_player the
      // first failure of a streamed source signs again once before it is
      // reported (when signing again can help at all).
      if (found.worthResigning && current?.refresh != null && !refreshed) {
        if (await refreshExpired()) return;
      }
      failure = found;
      publish(error: true);
    } finally {
      diagnosing = false;
      // A failure of the reopened attempt that arrived while the first was
      // being handled.
      if (queuedAttempt != null && queuedAttempt != handled && queuedAttempt == attempt && !failed && !closed) {
        queuedAttempt = null;
        unawaited(onFailure());
      }
    }
  }

  final limiter = MediaLogLimiter();
  static void _writeLog(String line) {
    try {
      stderr.writeln(line);
    } on Object {
      // stderr may be closed (detached GUI session); logging is best effort.
    }
  }

  /// The mpv `hwdec` option in effect on Linux (`no` unless opted in).
  late final String hwdecRequested;

  /// Writes one `raft.media: hwdec ...` line naming the decoder mpv really
  /// uses once the first frame is out; best effort, never throws.
  Future<void> logDecoder() async {
    final native = player.platform;
    if (closed || native is! NativePlayer) return;
    try {
      // The first rendered frame can arrive before mpv has set up the decoder;
      // the video size is only published once a frame has been decoded, and
      // hwdec-current is valid from then on.
      if ((player.state.width ?? 0) <= 0) {
        await player.stream.width
            .firstWhere((w) => (w ?? 0) > 0)
            .timeout(const Duration(seconds: 20));
      }
      Future<String?> read(String name) async {
        try {
          return await native.getProperty(name, waitForInitialization: false);
        } on Object {
          return null;
        }
      }

      final current = await read('hwdec-current');
      final codec = await read('video-format');
      if (closed) return;
      _writeLog(
        formatHwdecLog(
          requested: hwdecRequested,
          current: current,
          codec: codec,
          width: player.state.width,
          height: player.state.height,
        ),
      );
    } on Object {
      // Diagnostics only.
    }
  }

  late final Player player;
  late final VideoController? controller;
  final Size maxVideoSize;

  /// Nothing behind the picture, so a poster beneath it shows until the first
  /// frame; otherwise media_kit's black backdrop.
  final bool transparentVideo;
  bool hasFrame = false;
  Size? surface;

  /// The decoded size bounded to [maxVideoSize], keeping the aspect ratio and
  /// never enlarging; null while the size is unknown.
  static Size? fitted(int? width, int? height, Size bound) {
    if (width == null || height == null || width <= 0 || height <= 0) {
      return null;
    }
    final scale = [
      1.0,
      bound.width / width,
      bound.height / height,
    ].reduce((a, b) => a < b ? a : b);
    return Size(
      (width * scale).roundToDouble().clamp(2, double.infinity),
      (height * scale).roundToDouble().clamp(2, double.infinity),
    );
  }

  void fitSurface() {
    if (closed) return;
    final size = fitted(player.state.width, player.state.height, maxVideoSize);
    if (size == null || size == surface) return;
    surface = size;
    unawaited(() async {
      try {
        await controller!.setSize(
          width: size.width.round(),
          height: size.height.round(),
        );
        // The software renderer drew nothing (or the old size) before the
        // surface had its final size, and a paused video never redraws by
        // itself: seeking to the start paints the first frame again.
        if (!closed && !player.state.playing) await player.seek(Duration.zero);
      } catch (_) {}
    }());
  }

  final output = StreamController<AttachmentPlayback>.broadcast();
  final subscriptions = <StreamSubscription<dynamic>>[];
  bool closed = false, failed = false;
  void publish({bool error = false}) {
    if (closed) return;
    failed = failed || error;
    output.add(
      AttachmentPlayback(
        playing: player.state.playing,
        position: player.state.position,
        duration: player.state.duration,
        volume: player.state.volume,
        error: failed,
        hasFrame: hasFrame,
        buffering: player.state.buffering,
        videoSize: _videoSize(),
        failure: failed ? failure : null,
      ),
    );
  }

  Size? _videoSize() {
    final w = player.state.width, h = player.state.height;
    return w == null || h == null || w <= 0 || h <= 0
        ? null
        : Size(w.toDouble(), h.toDouble());
  }

  @override
  Stream<AttachmentPlayback> get changes => output.stream;
  @override
  AttachmentPlayback get playback => AttachmentPlayback(
    playing: player.state.playing,
    position: player.state.position,
    duration: player.state.duration,
    volume: player.state.volume,
    error: failed,
    hasFrame: hasFrame,
    buffering: player.state.buffering,
    videoSize: _videoSize(),
    failure: failed ? failure : null,
  );
  @override
  bool get usesPlatformView => false;
  @override
  Widget video() => Video(
    controller: controller!,
    // ds-allow: native video surface backdrop, not themed UI
    fill: transparentVideo ? const Color(0x00000000) : const Color(0xFF000000),
    controls: NoVideoControls,
    pauseUponEnteringBackgroundMode: true,
    resumeUponEnteringForegroundMode: false,
  );
  AttachmentSource? source;
  bool refreshed = false;

  @override
  Future<void> open(AttachmentSource source) async {
    this.source = source;
    refreshed = false;
    failure = null;
    attempt++;
    recent.clear();
    final native = player.platform;
    // Through the on-disk cache when it applies: mpv gets a loopback URL (and
    // never goes via an HTTP proxy for it); failures are diagnosed against
    // [source], the real URL.
    final mine = attempt;
    // Video only: audio is streamed as before.
    final routed = controller == null ? source : await VideoCache.route(source);
    if (closed || mine != attempt) return;
    final cached = !identical(routed, source);
    final target = source.isNetwork ? routed.url.toString() : source.file!.path;
    if (native is NativePlayer) {
      for (final property in const [
        'cache-on-disk',
        'access-references',
        'load-scripts',
        'ytdl',
        'sub-auto',
        'audio-file-auto',
        'autoload-files',
      ]) {
        await native.setProperty(property, 'no');
      }
      // A file is read directly; a stream keeps a bounded read-ahead in
      // memory (never on disk: only the Download action saves a file).
      await native.setProperty('cache', source.isNetwork ? 'yes' : 'no');
      if (source.isNetwork) {
        await native.setProperty('demuxer-max-bytes', '${maxVideoSize.width > 1000 ? 64 : 32}MiB');
        await native.setProperty('demuxer-max-back-bytes', '8MiB');
        if (cached) {
          // The loopback URL never goes through a proxy, and the cache holds
          // the headers: nothing is sent to it.
          await native.setProperty('http-proxy', '');
          await native.setProperty('stream-lavf-o', 'http_proxy=');
          await native.setProperty('http-header-fields', '');
        } else {
          await native.setProperty('http-proxy', httpProxyFor(source.url!));
          await native.setProperty('stream-lavf-o', lavfOptionsFor(source.url!));
          await native.setProperty(
            'http-header-fields',
            source.headers.entries.map((e) => '${e.key}: ${e.value}').join(','),
          );
        }
      }
      await native.setProperty(
        'start',
        source.start > Duration.zero ? '${source.start.inMilliseconds / 1000}' : 'none',
      );
      // media_kit.open uses an intermediate playlist. Keep external references
      // disabled and load the already-authorized input directly instead.
      await native.setProperty('pause', 'yes');
      // The previous source's repeat setting does not carry over; the length
      // of this one sets it again once it is known.
      await native.setProperty('loop-file', 'no');
      await native.command(['loadfile', target, 'replace']);
      return;
    }
    await player.open(
      Media(
        source.isNetwork ? target : source.file!.uri.toString(),
        httpHeaders: source.headers.isEmpty ? null : source.headers,
        start: source.start > Duration.zero ? source.start : null,
      ),
      play: false,
    );
  }

  /// mpv's `http-proxy` value for [url]: the app's proxy decision (Settings,
  /// environment, OS), `` for DIRECT. Only host and port leave the decision;
  /// credentials of a manual proxy are part of it and are set as a runtime
  /// property, never through argv or logs.
  @visibleForTesting
  static String httpProxyFor(Uri url) {
    final decision = SystemProxy.instance.findProxyForClient(url);
    for (final part in decision.split(';')) {
      final entry = part.trim();
      if (entry.toUpperCase().startsWith('PROXY ')) {
        return 'http://${entry.substring(6).trim()}';
      }
      if (entry.toUpperCase() == 'DIRECT') return '';
    }
    return '';
  }

  /// mpv's `stream-lavf-o` for [url]. mpv passes an empty `http-proxy` on as
  /// no option at all, and FFmpeg then falls back to the process's
  /// `http_proxy` environment variable, for https URLs too. So a DIRECT
  /// decision (e.g. only `http_proxy` set, or a stale proxy left in the
  /// session environment) still went through that proxy and the stream failed
  /// to open. An explicit empty FFmpeg `http_proxy` keeps DIRECT direct; with
  /// a proxy the option is cleared so `http-proxy` applies.
  @visibleForTesting
  static String lavfOptionsFor(Uri url) => httpProxyFor(url).isEmpty ? 'http_proxy=' : '';

  /// Where a re-signed source reopens: where playback got to, or, for a
  /// source that failed before it played (no position yet), the start it was
  /// asked for.
  @visibleForTesting
  static Duration resignPosition(Duration position, Duration start) =>
      position > Duration.zero ? position : start;

  /// A streamed source that failed to open or play (typically a host that
  /// answered 401/403/410 for an expired signature): sign again once and
  /// continue from the current position.
  Future<bool> refreshExpired() async {
    final current = source;
    final refresh = current?.refresh;
    if (closed || current == null || !current.isNetwork || refresh == null || refreshed) {
      return false;
    }
    refreshed = true;
    try {
      final url = await refresh();
      if (closed) return false;
      final at = resignPosition(player.state.position, current.start);
      failed = false;
      await open(current.resigned(url, start: at));
      refreshed = true;
      return true;
    } on Object {
      return false;
    }
  }

  @override
  Future<void> toggle() => player.playOrPause();
  @override
  Future<void> pause() => player.pause();
  @override
  Future<void> seek(Duration value) => player.seek(value);
  @override
  Future<void> volume(double value) => player.setVolume(value);
  @override
  Future<void> dispose() async {
    if (closed) return;
    closed = true;
    for (final s in subscriptions) {
      await s.cancel();
    }
    await player.dispose();
    await output.close();
  }
}
