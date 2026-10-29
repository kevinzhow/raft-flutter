import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

import 'attachment_player.dart';
import 'attachment_player_log.dart';
import 'media_failure.dart';
import 'media_probe.dart';
import 'video_cache.dart';

/// The platform's own player behind [AttachmentPlayer]: ExoPlayer (Media3) on
/// Android, AVPlayer on iOS and macOS, through the official `video_player`
/// plugin. Colour (HDR to SDR tone mapping), hardware decoding and codec
/// support are the system's; Windows and Linux keep [NativeAttachmentPlayer]
/// because their system codecs are optional or absent.
///
/// The player streams the attachment's own URL (`VideoPlayerController
/// .networkUrl`): ExoPlayer and AVPlayer read the byte ranges they need and
/// nothing is saved to disk by us (video_player_android has no cache option;
/// AVPlayer buffers in memory). The signed URL is the only credential, so no
/// header is sent unless the source carries one. A private local file is
/// still a valid source (tests, the Download action's consumers).
class VideoPlayerAttachmentPlayer
    with WidgetsBindingObserver
    implements AttachmentPlayer {
  /// An audio-only attachment is opened the same way; it never builds
  /// [video], so no picture surface exists for it.
  VideoPlayerAttachmentPlayer({
    this.transparentVideo = false,
    this.platformView = false,
    this.hasPicture = true,
  });

  /// A video (not audio only): only a video goes through the on-disk cache,
  /// and a short one repeats by itself, see [kLoopingVideoMaxDuration].
  final bool hasPicture;

  /// Render into the plugin's native view ([VideoViewType.platformView]:
  /// `SurfaceView` on Android, `AVPlayerLayer` on iOS and macOS) instead of a
  /// Flutter texture. The texture path tone-maps HDR to SDR on every
  /// platform; the native view hands HDR to the compositor untouched, so an
  /// HDR clip stays HDR on an HDR screen. A platform view does not clip,
  /// scroll or animate like Flutter content, so only the full-screen viewer
  /// asks for it, never a card in a list.
  final bool platformView;

  /// Nothing behind the picture, so a poster beneath it shows until the first
  /// frame; otherwise a black backdrop.
  final bool transparentVideo;

  /// Players built and not yet disposed (the interaction suite asserts that a
  /// closed viewer leaves none behind).
  static int debugLive = 0;
  bool _counted = false;

  @override
  bool get usesPlatformView => platformView;

  AttachmentSource? _source;
  bool _refreshed = false, _refreshing = false;

  final _controller = ValueNotifier<VideoPlayerController?>(null);
  final _output = StreamController<AttachmentPlayback>.broadcast();
  final _limiter = MediaLogLimiter(limit: 20);
  bool _closed = false, _failed = false, _observing = false;
  bool _diagnosing = false;
  MediaFailure? _failure;
  bool _hasFrame = false;
  AttachmentPlayback? _last;

  VideoPlayerController? get _active => _controller.value;

  @override
  Stream<AttachmentPlayback> get changes => _output.stream;

  @override
  AttachmentPlayback get playback => _last ?? const AttachmentPlayback();

  @override
  Widget video() => _VideoSurface(
    player: this,
    // ds-allow: native video surface backdrop, not themed UI
    fill: transparentVideo ? const Color(0x00000000) : const Color(0xFF000000),
  );

  @override
  Future<void> open(AttachmentSource source) async {
    if (_closed) return;
    if (!_counted) {
      _counted = true;
      debugLive++;
    }
    _source = source;
    _refreshed = false;
    await _open(source);
  }

  VideoPlayerController _build(AttachmentSource source) {
    final viewType = platformView
        ? VideoViewType.platformView
        : VideoViewType.textureView;
    final options = VideoPlayerOptions(
      // The lifecycle observer of video_player resumes playback when the app
      // returns; a video that was paused by leaving must stay paused (see
      // didChangeAppLifecycleState).
      allowBackgroundPlayback: true,
    );
    return source.isNetwork
        ? VideoPlayerController.networkUrl(
            source.url!,
            httpHeaders: source.headers,
            viewType: viewType,
            videoPlayerOptions: options,
          )
        : VideoPlayerController.file(
            source.file!,
            viewType: viewType,
            videoPlayerOptions: options,
          );
  }

  Future<void> _open(AttachmentSource source) async {
    await _release();
    _failed = false;
    _failure = null;
    _hasFrame = false;
    _last = null;
    // Through the on-disk cache when it applies: the player gets a loopback
    // URL; failures are still diagnosed against [source], the real URL.
    final routed = hasPicture ? await VideoCache.route(source) : source;
    if (_closed) return;
    final controller = _build(routed);
    controller.addListener(_publish);
    _controller.value = controller;
    if (!_observing) {
      _observing = true;
      WidgetsBinding.instance.addObserver(this);
    }
    try {
      // Opens paused at the first frame.
      await controller.initialize();
      if (_closed || _active != controller) return;
      if (source.start > Duration.zero) await controller.seekTo(source.start);
      // A short clip repeats by itself (ExoPlayer's and AVPlayer's own repeat
      // mode); a long one stops at the end as before.
      if (hasPicture && loopsAtEnd(controller.value.duration)) {
        await controller.setLooping(true);
      }
    } on Object catch (error) {
      if (_closed || _active != controller) return;
      // video_player reports "Source error" for a rejected request without the
      // status, so the class comes from the error text where it has one and
      // from one probe request where it has not. An expired signature (or a
      // cause nobody could name) signs once more and tries again, at the
      // position this open was asked for (a resume), not at zero.
      final found = await _diagnose(
        mediaErrorText(error),
        source,
        started: false,
      );
      if (_closed || _active != controller) return;
      if (found.worthResigning &&
          await _retryWithFreshUrl(source, source.start)) {
        return;
      }
      // The re-sign attempt failed too and already reported its own failure.
      if (_failed) throw MediaPlaybackException(_failure ?? found);
      _fail(found, 'open failed');
      throw MediaPlaybackException(found);
    }
    _publish();
  }

  /// One re-sign per source: the first failure of a streamed source asks its
  /// `refresh` for a new URL and reopens at [position].
  Future<bool> _retryWithFreshUrl(
    AttachmentSource source,
    Duration position,
  ) async {
    final refresh = source.refresh;
    if (_closed || !source.isNetwork || refresh == null || _refreshed) {
      return false;
    }
    _refreshed = true;
    try {
      final url = await refresh();
      if (_closed) return false;
      final next = source.resigned(url, start: position);
      _source = next;
      await _open(next);
      return true;
    } on Object {
      return false;
    }
  }

  /// Called by the video surface once the picture was built after the player
  /// reported a size: the poster beneath can go.
  void _firstFrame() {
    if (_closed || _hasFrame) return;
    _hasFrame = true;
    _publish();
  }

  void _publish({bool error = false}) {
    if (_closed) return;
    final controller = _active;
    if (controller == null) return;
    final value = controller.value;
    if (value.hasError) {
      if (!_failed) {
        // Report only once the class is known (and, for a stream that failed
        // after it started, once a fresh URL had its chance).
        if (!_diagnosing && !_refreshing) {
          _diagnosing = true;
          unawaited(_onPlaybackError(value));
        }
        return;
      }
      error = true;
    }
    _failed = _failed || error;
    final size = value.size;
    final next = AttachmentPlayback(
      playing: value.isPlaying,
      position: value.position,
      // An erroneous value forgets the length; keep what the card knew.
      duration: value.hasError
          ? (_last?.duration ?? value.duration)
          : value.duration,
      volume: (value.volume * 100).clamp(0.0, 100.0),
      error: _failed,
      hasFrame: _hasFrame,
      buffering: value.isBuffering,
      videoSize: size.isEmpty ? null : size,
      failure: _failed ? _failure : null,
    );
    final last = _last;
    if (last != null &&
        last.playing == next.playing &&
        last.position == next.position &&
        last.duration == next.duration &&
        last.volume == next.volume &&
        last.error == next.error &&
        last.hasFrame == next.hasFrame &&
        last.buffering == next.buffering &&
        last.videoSize == next.videoSize &&
        last.failure == next.failure) {
      return;
    }
    _last = next;
    _output.add(next);
  }

  /// Settles the class of a failure: [text] first, then one probe (see
  /// [MediaDiagnosis]). ExoPlayer and AVPlayer follow the OS proxy only.
  Future<MediaFailure> _diagnose(
    String text,
    AttachmentSource? source, {
    required bool started,
  }) {
    final network = source != null && source.isNetwork;
    return MediaDiagnosis.diagnose(
      text: text,
      url: network ? source.url : null,
      headers: network ? source.headers : const {},
      playerFollowsApp: false,
      started: started,
    );
  }

  /// Records and publishes the final failure.
  void _fail(MediaFailure found, String what) {
    _failure = found;
    _failed = true;
    _log('$what ${found.logLine}');
    _publish(error: true);
  }

  /// The controller reported an error after it was initialised (a ranged
  /// request refused, the link dropped). Once, a fresh URL is tried and
  /// playback continues from where it stopped; otherwise the class is
  /// published.
  Future<void> _onPlaybackError(VideoPlayerValue value) async {
    final source = _source;
    try {
      final found = await _diagnose(
        value.errorDescription ?? '',
        source,
        started: value.isInitialized,
      );
      if (_closed) return;
      if (found.worthResigning &&
          source != null &&
          !_refreshed &&
          source.refresh != null &&
          value.isInitialized) {
        final wasPlaying = _last?.playing ?? false;
        final at = value.position;
        _refreshing = true;
        final done = await _retryWithFreshUrl(source, at);
        _refreshing = false;
        if (_closed) return;
        if (done) {
          if (wasPlaying) await _active?.play();
          return;
        }
        // The re-sign attempt failed too and already reported its failure.
        if (_failed) return;
      }
      _fail(found, 'playback error');
    } finally {
      _diagnosing = false;
      _refreshing = false;
    }
  }

  void _log(String text) {
    final line = _limiter.admit(formatMediaLog('error', 'video_player', text));
    if (line == null) return;
    // logcat on Android, the unified log on iOS and macOS.
    debugPrint(line);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Leaving the app pauses; coming back does not resume on its own. macOS
    // reports a hidden or minimised window as `hidden` and never `paused`;
    // iOS and Android pass through `hidden` on the way to `paused`.
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      final controller = _active;
      if (controller != null && controller.value.isPlaying) {
        unawaited(controller.pause().catchError((_) {}));
      }
    }
  }

  @override
  Future<void> toggle() async {
    final controller = _active;
    if (controller == null || _closed) return;
    final value = controller.value;
    if (value.isPlaying) return controller.pause();
    final end =
        value.isCompleted ||
        (value.duration > Duration.zero && value.position >= value.duration);
    if (end) await controller.seekTo(Duration.zero);
    await controller.play();
  }

  @override
  Future<void> pause() async {
    if (_closed) return;
    await _active?.pause();
  }

  @override
  Future<void> seek(Duration value) async {
    final controller = _active;
    if (controller == null || _closed) return;
    final length = controller.value.duration;
    var target = value < Duration.zero ? Duration.zero : value;
    if (length > Duration.zero && target > length) target = length;
    await controller.seekTo(target);
  }

  @override
  Future<void> volume(double value) async {
    if (_closed) return;
    await _active?.setVolume((value / 100).clamp(0.0, 1.0));
  }

  Future<void> _release() async {
    final controller = _active;
    _controller.value = null;
    if (controller == null) return;
    controller.removeListener(_publish);
    try {
      await controller.dispose();
    } on Object {
      // A failing native player must not keep its file.
    }
  }

  @override
  Future<void> dispose() async {
    if (_closed) return;
    _closed = true;
    if (_observing) {
      _observing = false;
      WidgetsBinding.instance.removeObserver(this);
    }
    if (_counted) {
      _counted = false;
      debugLive--;
    }
    await _release();
    _controller.dispose();
    await _output.close();
  }
}

/// The picture: contained inside the box it is given, nothing until the player
/// knows its size. Reports the first built frame back to the player.
class _VideoSurface extends StatelessWidget {
  const _VideoSurface({required this.player, required this.fill});
  final VideoPlayerAttachmentPlayer player;
  final Color fill;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: fill,
    child: ValueListenableBuilder<VideoPlayerController?>(
      valueListenable: player._controller,
      builder: (context, controller, _) {
        if (controller == null) return const SizedBox.expand();
        return ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            if (!value.isInitialized || value.size.isEmpty) {
              return const SizedBox.expand();
            }
            if (!player._hasFrame) {
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => player._firstFrame(),
              );
            }
            return Center(
              child: AspectRatio(
                aspectRatio: value.aspectRatio,
                child: VideoPlayer(controller),
              ),
            );
          },
        );
      },
    ),
  );
}
