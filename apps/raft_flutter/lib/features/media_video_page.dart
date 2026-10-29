import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import '../platform/attachment_files.dart';
import '../platform/attachment_http.dart';
import '../platform/attachment_player.dart';
import '../platform/attachment_player_factory.dart';
import '../platform/attachment_player_sessions.dart';
import '../platform/attachment_stream.dart';
import '../platform/media_failure.dart';
import '../platform/mp4_hdr_probe.dart';
import 'attachment_preview_dialog.dart' show HdrDetector;
import 'media_failure_text.dart';

/// Responsive layout overrides for media tests.
abstract final class MediaBrowserFlags {
  /// Forces the phone layout on (true) or off (false) for a suite that mounts
  /// the real cards and viewer chrome. It never selects a timeline player.
  /// Null in the product.
  @visibleForTesting
  static bool? phoneLayout;
}

/// A touch device, whatever its window size (a phone held sideways, an
/// unfolded foldable, a tablet). Its video cards show the poster only and open
/// the viewer to play; a narrow desktop window keeps desktop viewer chrome.
bool phoneMediaLayout(BuildContext context) =>
    MediaBrowserFlags.phoneLayout ?? RaftInteraction.of(context).touch;

/// A video up to this size prepares by itself once its page has rested; a
/// larger one waits for the first Play (the cards' rule).
const mediaVideoAutoPrepareBytes = 24 * 1024 * 1024;

/// A page must rest this long before it prepares a player: swiping through a
/// gallery opens nothing for the pages that were only passed (the cards' rule).
const mediaVideoSettle = Duration(milliseconds: 250);

/// How long a page that was left keeps its hold on the player: swiping back
/// and forth costs nothing.
const mediaVideoGrace = Duration(seconds: 3);

/// The player lifecycle of one video page of the media browser.
///
/// The page holds the attachment's session as a viewer (see [PlayerSessions]):
/// opened from a card that has a player, it takes that player over (no new
/// request, position and playback continue); otherwise it prepares one after
/// the page has rested [settle], paused at the first frame, never playing by
/// itself. Leaving the page pauses at once and releases the hold after [grace];
/// a card that holds the session keeps it (paused where the page left it), with
/// no card the decoder is freed. An HDR video gets its native view only while
/// the page rests ([moving] false, route settled) and loses it at the first
/// moment of any swipe, drag or pop.
class MediaVideoStage extends ChangeNotifier {
  MediaVideoStage({
    required this.controller,
    required this.metadata,
    required this.authorized,
    this.channelId,
    this.playerFactory,
    this.hdrDetector,
    this.settle = mediaVideoSettle,
    this.grace = mediaVideoGrace,
  });

  final WorkspaceController controller;
  final Map<String, dynamic> metadata;
  final String? channelId;
  final bool Function() authorized;
  final AttachmentPlayer Function()? playerFactory;
  final HdrDetector? hdrDetector;
  final Duration settle, grace;

  PlayerSessions get sessions => controller.attachmentMedia.playerSessions;
  String get key => attachmentMediaKey(metadata);
  String? get owner => channelId ?? metadata['channelId'] as String?;
  int? get sizeBytes => (metadata['sizeBytes'] as num?)?.toInt();

  PlayerHold? hold, hdrHold;
  AttachmentPlayer? player;
  AttachmentPlayback playback = const AttachmentPlayback();
  StreamSubscription<AttachmentPlayback>? _events;

  /// Why the video cannot be played (null: it can).
  MediaFailure? failure;

  /// The player is being prepared.
  bool opening = false;

  /// A Play tapped before the player was ready: honoured when it is.
  bool playRequested = false;

  /// This page is the one on screen (set by [enter] / [leave]).
  bool isCurrent = false;

  /// The page is being swiped, dragged or popped: no native view.
  bool moving = false;

  /// The shared player is catching up with the native view's position: the
  /// stage stays black meanwhile.
  bool swappingBack = false;
  bool _disposed = false;
  Timer? _settleTimer, _graceTimer;

  bool get live => hold != null;

  bool get _usable => !_disposed && authorized();

  /// The page became the current one: take the live player over at once, or
  /// prepare after it has rested.
  ///
  /// [autoplay]: the page was opened to play (a tap on a phone's video card):
  /// the player is prepared at once whatever the size and plays as soon as it
  /// is ready.
  void enter({bool autoplay = false}) {
    if (_disposed) return;
    isCurrent = true;
    _graceTimer?.cancel();
    _graceTimer = null;
    // A failed page shows its failure again; only Retry opens another stream.
    if (failure != null) return;
    if (autoplay) playRequested = true;
    final held = hold;
    if (held != null && !held.orphaned && failure == null) {
      _rest();
      if (autoplay && !opening && !playback.playing) unawaited(_play());
      return;
    }
    if (held != null) _drop();
    if (autoplay) {
      unawaited(prepare());
    } else if (sessions.isLive(key)) {
      // A card (or the grace of a page left a moment ago) has the player: the
      // same stream, no request.
      unawaited(prepare());
    } else if ((sizeBytes ?? 0) <= mediaVideoAutoPrepareBytes) {
      _settleTimer?.cancel();
      _settleTimer = Timer(settle, () {
        _settleTimer = null;
        if (isCurrent && !_disposed) unawaited(prepare());
      });
    }
  }

  /// The page is no longer the current one: pause at once, keep the hold for
  /// [grace].
  void leave() {
    if (_disposed) return;
    isCurrent = false;
    playRequested = false;
    _settleTimer?.cancel();
    _settleTimer = null;
    unawaited(endHdr(rebind: false));
    final p = player;
    if (p != null) {
      sessions.resumeAt[key] = p.playback.position;
      unawaited(p.pause().catchError((Object _) {}));
    }
    if (hold == null) return;
    _graceTimer?.cancel();
    _graceTimer = Timer(grace, () {
      _graceTimer = null;
      if (!isCurrent) _drop();
    });
  }

  /// Opens (or takes over) the player. Safe to call again.
  Future<void> prepare() async {
    if (!_usable || hold != null) return;
    failure = null;
    opening = true;
    notifyListeners();
    try {
      final acquired = sessions.acquire(
        key,
        scope: controller.attachmentImageScope,
        channelId: owner,
        viewer: true,
        create:
            playerFactory ??
            () => createAttachmentPlayer(video: true, transparentVideo: true),
        source: () => attachmentStreamSource(
          controller,
          '${metadata['id']}',
          channelId: owner,
          start: sessions.resumeAt[key] ?? Duration.zero,
        ),
      );
      sessions.prepared.add(key);
      hold = acquired;
      acquired.onEvicted = () {
        if (identical(hold, acquired)) _drop();
      };
      _bind(acquired.player);
      await acquired.ready;
      if (!_usable || !identical(hold, acquired)) return;
      opening = false;
      playback = acquired.player.playback;
      if (playback.error) {
        failure = playback.failure ?? failureOfError(StateError('playback'));
      }
      notifyListeners();
      if (failure != null) return;
      if (playRequested && isCurrent) {
        playRequested = false;
        await _play();
      }
      unawaited(considerHdr());
    } catch (error) {
      if (_disposed) return;
      opening = false;
      playRequested = false;
      failure = failureOfError(error);
      notifyListeners();
    }
  }

  void _bind(AttachmentPlayer next) {
    final old = _events;
    _events = null;
    unawaited(old?.cancel());
    player = next;
    playback = next.playback;
    // ignore: raft_lints/avoid_unreleased_resource -- Cancelled in _drop() and dispose().
    _events = next.changes.listen((value) {
      if (_disposed || !identical(player, next)) return;
      playback = value;
      if (value.error) {
        failure =
            value.failure ?? failure ?? failureOfError(StateError('playback'));
        unawaited(next.pause().catchError((Object _) {}));
      }
      notifyListeners();
    });
    notifyListeners();
  }

  /// Gives the players back (the card, when it holds the session, keeps it).
  void _drop() {
    _graceTimer?.cancel();
    _graceTimer = null;
    final events = _events, shared = hold, native = hdrHold;
    _events = null;
    hold = null;
    hdrHold = null;
    player = null;
    unawaited(events?.cancel());
    native?.release();
    shared?.release();
    opening = false;
    playback = AttachmentPlayback(
      duration: playback.duration,
      videoSize: playback.videoSize,
    );
    if (!_disposed) notifyListeners();
  }

  Future<void> togglePlay() async {
    if (!_usable || failure != null) return;
    if (hold == null) {
      playRequested = true;
      await prepare();
      return;
    }
    if (opening) {
      playRequested = true;
      return;
    }
    final value = playback;
    if (!value.playing &&
        value.duration > Duration.zero &&
        value.position >= value.duration - const Duration(milliseconds: 250)) {
      await _guard((p) => p.seek(Duration.zero));
    }
    await _play();
  }

  Future<void> _play() => _guard((p) => p.toggle());

  Future<void> seek(Duration value) => _guard((p) => p.seek(value));
  Future<void> setVolume(double value) => _guard((p) => p.volume(value));

  Future<void> _guard(Future<void> Function(AttachmentPlayer) run) async {
    final p = player;
    if (!_usable || p == null) return;
    try {
      await run(p);
    } catch (error) {
      if (_disposed) return;
      failure = p.playback.failure ?? failureOfError(error);
      notifyListeners();
    }
  }

  /// Retry after a failure: a new player (a failed session is never shared
  /// again), which signs the link again.
  Future<void> retry() async {
    if (!_usable) return;
    await endHdr(rebind: false);
    hold?.session.failed = true;
    _drop();
    failure = null;
    await prepare();
  }

  // ---- HDR: the native view needs a player of its own ----------------------

  bool get platformViewsAvailable =>
      hdrDetector != null ||
      (playerFactory == null &&
          attachmentBackendFor(defaultTargetPlatform) ==
              AttachmentBackend.system);

  Future<bool> _detectHdr() async {
    final verdicts = sessions.hdrVerdicts;
    final known = verdicts[key];
    if (known != null) return known;
    final url = AttachmentFiles.attachmentUri(
      await controller.attachmentMedia.url(
        '${metadata['id']}',
        channelId: owner,
        coalesce: true,
      ),
    );
    final detector = hdrDetector;
    final verdict = detector != null
        ? await detector(url)
        : (await probeMp4Color(AttachmentHttp.shared, url))?.hdr ?? false;
    if (verdicts.length > 64) verdicts.remove(verdicts.keys.first);
    return verdicts[key] = verdict;
  }

  bool get _resting => isCurrent && !moving && !_disposed;

  /// An HDR video opens a native-view player of its own at the shared
  /// player's position (the first moment the page rests); SDR videos never
  /// get here.
  Future<void> considerHdr() async {
    final shared = hold;
    if (shared == null || !platformViewsAvailable || hdrHold != null) return;
    var pausedPlaying = false;
    Future<void> resumeShared() async {
      if (!pausedPlaying || shared.orphaned) return;
      pausedPlaying = false;
      try {
        if (!shared.player.playback.playing) await shared.player.toggle();
      } on Object {
        // best effort: the shared player may already be gone
      }
    }

    try {
      if (!await _detectHdr() || !_resting || hdrHold != null) return;
      final started = Stopwatch()..start();
      final base = shared.player.playback;
      await shared.player.pause();
      pausedPlaying = base.playing;
      final native = sessions.acquire(
        '$key|hdr',
        scope: controller.attachmentImageScope,
        channelId: owner,
        viewer: true,
        create:
            playerFactory ??
            () => createAttachmentPlayer(video: true, hdr: true),
        source: () => attachmentStreamSource(
          controller,
          '${metadata['id']}',
          channelId: owner,
          start: base.position,
        ),
      );
      hdrHold = native;
      await native.ready;
      if (!_resting || !identical(hdrHold, native)) {
        if (identical(hdrHold, native)) hdrHold = null;
        native.release();
        await resumeShared();
        return;
      }
      await native.player.volume(base.volume);
      if (base.playing) await native.player.toggle();
      debugPrint(
        'raft.media: browser hdr handoff ${started.elapsedMilliseconds} ms at ${base.position.inMilliseconds} ms',
      );
      _bind(native.player);
    } on Object {
      if (hdrHold != null && !identical(player, hdrHold!.player)) {
        hdrHold?.release();
        hdrHold = null;
      }
      if (hdrHold == null) await resumeShared();
    }
  }

  /// Back from the native view to the shared player, at the position (and
  /// play state) the native one reached.
  Future<void> endHdr({bool rebind = true}) async {
    final native = hdrHold, shared = hold;
    if (native == null) return;
    hdrHold = null;
    final last = native.player.playback;
    if (rebind && !_disposed) {
      swappingBack = true;
      notifyListeners();
    }
    native.release();
    if (shared != null && !shared.orphaned) {
      try {
        await shared.player.seek(last.position);
        await shared.player.volume(last.volume);
        if (last.playing) await shared.player.toggle();
      } on Object {
        // best effort
      }
    }
    if (rebind && shared != null && !shared.orphaned && !_disposed) {
      _bind(shared.player);
      swappingBack = false;
      notifyListeners();
    }
  }

  /// A swipe, drag or pop began or ended on this page.
  void setMoving(bool value) {
    if (moving == value || _disposed) return;
    moving = value;
    if (value) {
      if (hdrHold != null) unawaited(endHdr());
    } else {
      _rest();
    }
    notifyListeners();
  }

  void _rest() {
    if (hold != null && failure == null && !opening && _resting) {
      unawaited(considerHdr());
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _settleTimer?.cancel();
    _graceTimer?.cancel();
    final events = _events, shared = hold, native = hdrHold;
    _events = null;
    hold = null;
    hdrHold = null;
    unawaited(() async {
      // The native view's player is the page's own; the shared player (the
      // card's, when there is one) carries on from the position reached.
      if (native != null && shared != null && !shared.orphaned) {
        final last = native.player.playback;
        native.release();
        try {
          await shared.player.seek(last.position);
          await shared.player.volume(last.volume);
          if (last.playing) await shared.player.toggle();
        } on Object {
          // best effort
        }
      } else {
        native?.release();
      }
      await events?.cancel();
      shared?.release();
    }());
    super.dispose();
  }
}

/// One video page: the poster, the player's picture and its controls, or the
/// failure with what helps.
class MediaVideoPage extends StatefulWidget {
  const MediaVideoPage({
    super.key,
    required this.stage,
    required this.filename,
    required this.immersive,
    this.poster,
    this.heroTag,
    this.declaredSize,
    this.onSurfaceTap,
    this.controlsInset = 0,
    this.controlsVisible,
    this.onDownload,
    this.onNetworkSettings,
  });
  final MediaVideoStage stage;
  final String filename;

  /// Phone page: the whole stage, a tap toggles the chrome.
  final bool immersive;
  final ImageProvider? poster;

  /// The card-to-viewer Hero: the picture (the card's poster flies, then the
  /// player's picture is there) is the destination of the card's flight.
  /// [declaredSize] is the video's pixel size from the message or a stored
  /// read, used until the player knows the real one.
  final Object? heroTag;
  final Size? declaredSize;
  final VoidCallback? onSurfaceTap;
  final double controlsInset;

  /// Phone page: the chrome state; the playing video's controls follow it.
  final bool? controlsVisible;
  final Future<void> Function()? onDownload;
  final VoidCallback? onNetworkSettings;

  @override
  State<MediaVideoPage> createState() => _MediaVideoPageState();
}

class _MediaVideoPageState extends State<MediaVideoPage> {
  ModalRoute<dynamic>? route;
  bool entered = false;

  MediaVideoStage get stage => widget.stage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = ModalRoute.of(context);
    if (identical(next, route)) return;
    route?.animation?.removeListener(routeMoved);
    route?.navigator?.userGestureInProgressNotifier.removeListener(routeMoved);
    route = next;
    next?.animation?.addListener(routeMoved);
    next?.navigator?.userGestureInProgressNotifier.addListener(routeMoved);
    entered = next?.animation == null || next!.animation!.isCompleted;
  }

  /// The route is opening, closing or being swiped away: no native view.
  void routeMoved() {
    final r = route;
    if (r == null) return;
    final animation = r.animation;
    final gesture = r.navigator?.userGestureInProgress ?? false;
    final leaving =
        animation?.status == AnimationStatus.reverse || gesture || !r.isActive;
    final nowEntered = animation == null || animation.isCompleted;
    if (nowEntered != entered) setState(() => entered = nowEntered);
    if (leaving) stage.setMoving(true);
  }

  @override
  void dispose() {
    route?.animation?.removeListener(routeMoved);
    route?.navigator?.userGestureInProgressNotifier.removeListener(routeMoved);
    super.dispose();
  }

  /// The picture inside the card-to-viewer Hero, laid out at the video's own
  /// shape (contain) so the flight lands on the picture, not on the stage.
  Widget heroed(Widget picture) {
    final tag = widget.heroTag;
    if (tag == null) return picture;
    final natural = stage.playback.videoSize ?? widget.declaredSize;
    return LayoutBuilder(
      builder: (context, constraints) {
        final bound = constraints.biggest;
        var box = bound;
        if (natural != null &&
            !natural.isEmpty &&
            bound.isFinite &&
            !bound.isEmpty) {
          final scale =
              bound.width / natural.width < bound.height / natural.height
              ? bound.width / natural.width
              : bound.height / natural.height;
          box = Size(natural.width * scale, natural.height * scale);
        }
        return Center(
          child: SizedBox.fromSize(
            size: box,
            child: RaftMediaHero(
              tag: tag,
              image: widget.poster,
              fit: BoxFit.contain,
              child: picture,
            ),
          ),
        );
      },
    );
  }

  Widget picture(AttachmentPlayer? p) => heroed(_picture(p));

  Widget _picture(AttachmentPlayer? p) {
    // ds-allow: video stage is black by design (Web VideoPreviewBody)
    const black = ColoredBox(color: Color(0xFF000000));
    final poster = widget.poster == null
        ? black
        // ignore: raft_lints/avoid_raw_image_decode -- The poster is the strip's already decoded thumbnail.
        : Image(
            image: widget.poster!,
            fit: BoxFit.contain,
            gaplessPlayback: true,
          );
    if (p == null) return poster;
    final native = p.usesPlatformView;
    if (stage.swappingBack || (native && !(entered && !stage.moving))) {
      return black;
    }
    return Stack(
      fit: StackFit.expand,
      children: [if (!native && !stage.playback.hasFrame) poster, p.video()],
    );
  }

  Widget failurePane(BuildContext context, MediaFailure failure) {
    final actions = MediaFailureActions.of(failure);
    return RaftLoadError(
      mediaFailureMessage(context, failure, video: true),
      onDark: true,
      onRetry: actions.retry ? () => unawaited(stage.retry()) : null,
      actions: [
        if (actions.networkSettings && widget.onNetworkSettings != null)
          RaftLoadErrorAction(
            key: const Key('viewer-network-settings'),
            label: 'Network Settings',
            glyph: RaftGlyph.network,
            onPressed: widget.onNetworkSettings,
          ),
        if (widget.onDownload != null)
          RaftLoadErrorAction(
            key: const Key('viewer-download'),
            label: 'Download Original',
            glyph: RaftGlyph.download,
            onPressed: () => unawaited(widget.onDownload!()),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: stage,
    builder: (context, _) {
      final failure = stage.failure;
      // ds-allow: video stage is black by design (Web VideoPreviewBody)
      const black = Color(0xFF000000);
      if (failure != null) {
        return ColoredBox(color: black, child: failurePane(context, failure));
      }
      final value = stage.playback;
      return RaftVideoViewer(
        filename: widget.filename,
        video: picture(stage.player),
        videoSize: value.videoSize,
        playing: value.playing,
        buffering: value.buffering || (stage.opening && stage.playRequested),
        position: value.position,
        duration: value.duration,
        volume: value.volume,
        immersive: widget.immersive,
        onSurfaceTap: widget.immersive ? widget.onSurfaceTap : null,
        controlsInset: widget.controlsInset,
        controlsVisible: widget.immersive ? widget.controlsVisible : null,
        onTogglePlay: () => unawaited(stage.togglePlay()),
        onSeek: (v) => unawaited(stage.seek(v)),
        onVolume: (v) => unawaited(stage.setVolume(v)),
        onDownload: widget.immersive ? null : widget.onDownload,
      );
    },
  );
}
