import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/workspace_controller.dart';
import '../platform/attachment_files.dart';
import '../platform/attachment_player.dart';
import '../platform/attachment_player_factory.dart';
import '../platform/attachment_player_sessions.dart';
import '../platform/attachment_stream.dart';
import '../platform/media_failure.dart';
import '../platform/video_frame_probe.dart';
import '../platform/video_frame_scheduler.dart';
import 'media_failure_text.dart';
import 'media_browser.dart' show MediaBrowser;
import 'video_card_poster.dart';

/// Seams for suites that mount the real message rows without a decoder (the
/// parity extension suite): the player handed to every inline card that has no
/// explicit override. Null in the product.
abstract final class InlineMediaTestHooks {
  static AttachmentPlayer Function()? playerFactory;

  /// Takes the picture of a card's video for its still (`toImage` of the
  /// boundary in the product); a test counts the calls.
  static Future<ui.Image> Function(
    RenderRepaintBoundary boundary,
    double pixelRatio,
  )?
  stillSnapshot;
}

/// Why a card gave its player back (see `InlineMediaLoader.releasePlayer`).
enum PlayerRelease { ended, offscreen, hidden, background, evicted }

/// Loads one attachment's inline media the way Web's inline cards do: the URL
/// (`disposition=inline`) is signed once the card is on screen, then the
/// player opens it and streams it (progressive range reads; nothing is saved
/// or downloaded first) and the card plays it. Failures read as "Download to
/// view".
///
/// The player belongs to a session shared with the full-screen viewer of the
/// same attachment (see [PlayerSessions]): the card holds it, never owns it.
mixin InlineMediaLoader<T extends StatefulWidget> on State<T> {
  WorkspaceController get controller;
  Map<String, dynamic> get metadata;
  String? get channelId;
  bool get pending;
  bool Function() get authorized;
  AttachmentPlayer Function()? get playerFactoryOverride;
  bool get wantsVideo;

  /// Whether the card prepares its media as soon as it is near the viewport.
  bool get autoLoad => true;

  /// Bounds of the decoded picture on desktop (see NativeAttachmentPlayer).
  Size get maxVideoSize => const Size(1920, 1080);
  bool get transparentVideo => false;

  /// The media is open and paused at its first frame.
  void mediaReady() {}

  /// Every native playback event, after the state was updated.
  void playbackChanged(AttachmentPlayback value) {}

  PlayerHold? hold;
  Duration resumeAt = Duration.zero;

  /// A downscaled still of the last picture, shown while no player exists (after
  /// playback ended, or the player was released to free its decoder).
  ui.Image? still;
  final stillKey = GlobalKey();

  AttachmentPlayer? player;
  StreamSubscription<AttachmentPlayback>? playbackEvents;
  AttachmentPlayback playback = const AttachmentPlayback();
  RaftInlineMediaState mediaState = RaftInlineMediaState.idle;

  /// Why the media failed (set with [RaftInlineMediaState.failed]).
  MediaFailure? failure;
  bool disposed = false;

  String get filename => '${metadata['filename'] ?? 'attachment'}';
  bool get current => mounted && !disposed && authorized();

  /// A full-screen viewer holds this card's player: the card must not pause
  /// or stop it (the viewer shows it).
  bool get viewerHolds => hold?.session.viewerOpen ?? false;

  /// A card must stay built this long before it prepares its player: a fast
  /// scroll past a column of clips would otherwise open (and abandon) one per
  /// clip.
  static const settle = Duration(milliseconds: 250);
  Timer? settleTimer;

  String get mediaKey => attachmentMediaKey(metadata);

  @override
  void initState() {
    super.initState();
    final sessions = controller.attachmentMedia.playerSessions;
    // A card built again for an attachment prepared earlier shows its last
    // picture and where it stopped, and prepares on a tap (see
    // PlayerSessions.prepared), never by itself.
    still = sessions.stillFor(mediaKey);
    resumeAt = sessions.resumeAt[mediaKey] ?? Duration.zero;
    if (!pending && autoLoad && !sessions.prepared.contains(mediaKey)) {
      // Web: an IntersectionObserver (160px margin) starts the load once the
      // card is near the viewport; the list only builds rows that are.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        waitUntilSeen();
      });
    }
  }

  /// Starts the load once the card has been near the viewport for [settle]
  /// (Web: an IntersectionObserver with a margin). Cards built only because
  /// the list builds ahead of the viewport, or flung past, start nothing.
  void waitUntilSeen() {
    settleTimer?.cancel();
    settleTimer = Timer(settle, () {
      if (!mounted || disposed) return;
      if (nearViewport()) {
        unawaited(loadMedia());
      } else {
        waitUntilSeen();
      }
    });
  }

  /// Whether the card is within [margin] of the scrollable that holds it (a
  /// card outside any scrollable counts as seen).
  bool nearViewport({double margin = 160}) {
    final box = context.findRenderObject();
    final scrollable = Scrollable.maybeOf(context)?.context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return false;
    if (scrollable is! RenderBox || !scrollable.attached) return true;
    final card = box.localToGlobal(Offset.zero) & box.size;
    final view = scrollable.localToGlobal(Offset.zero) & scrollable.size;
    return card.overlaps(view.inflate(margin));
  }

  AttachmentPlayer createPlayer() =>
      (playerFactoryOverride ??
      InlineMediaTestHooks.playerFactory ??
      () => createAttachmentPlayer(
        video: wantsVideo,
        maxVideoSize: maxVideoSize,
        transparentVideo: transparentVideo,
      ))();

  Future<void> loadMedia() async {
    if (mediaState == RaftInlineMediaState.loading ||
        mediaState == RaftInlineMediaState.ready) {
      return;
    }
    setState(() => mediaState = RaftInlineMediaState.loading);
    try {
      final owner = channelId ?? metadata['channelId'] as String?;
      // One player per attachment for the session, shared with the viewer: a
      // clip scrolled out of view and back, or opened full screen, continues
      // from its own stream.
      final acquired = controller.attachmentMedia.playerSessions.acquire(
        mediaKey,
        scope: controller.attachmentImageScope,
        channelId: owner,
        create: createPlayer,
        source: () => attachmentStreamSource(
          controller,
          '${metadata['id']}',
          channelId: owner,
          start: resumeAt,
        ),
      );
      controller.attachmentMedia.playerSessions.prepared.add(mediaKey);
      hold = acquired;
      acquired.onEvicted = () =>
          unawaited(releasePlayer(PlayerRelease.evicted));
      player = acquired.player;
      playback = acquired.player.playback;
      // ignore: raft_lints/avoid_unreleased_resource -- Cancelled through the `events` alias in releaseInputs().
      playbackEvents = acquired.player.changes.listen((value) {
        if (!current) return;
        setState(() {
          playback = value;
          if (value.error) {
            mediaState = RaftInlineMediaState.failed;
            failure = value.failure ?? failure;
          }
        });
        playbackChanged(value);
        if (value.hasFrame) keepFirstStill();
        if (mediaState == RaftInlineMediaState.ready && playbackEnded(value)) {
          scheduleEndedRelease();
        }
      });
      await acquired.ready;
      if (current && !acquired.orphaned) {
        final now = acquired.player.playback;
        setState(() {
          playback = now;
          // A failure reported while the open was still pending stands.
          if (now.error) {
            mediaState = RaftInlineMediaState.failed;
            failure = now.failure ?? failure;
          } else {
            mediaState = RaftInlineMediaState.ready;
          }
        });
        if (!now.error) mediaReady();
      }
    } catch (error) {
      // The player rejected the source (video_player throws, with the class),
      // or the signed URL could not be obtained.
      if (current) {
        setState(() {
          mediaState = RaftInlineMediaState.failed;
          failure = failureOfError(error);
        });
      }
    }
  }

  /// Retry on a failed card: drops the failed player (a failed session is
  /// never shared) and prepares a new one, which signs the link again.
  Future<void> retryMedia() async {
    if (!current || mediaState != RaftInlineMediaState.failed) return;
    final held = hold, events = playbackEvents;
    hold = null;
    player = null;
    playbackEvents = null;
    unawaited(events?.cancel());
    held?.session.failed = true;
    held?.release();
    setState(() {
      mediaState = RaftInlineMediaState.idle;
      failure = null;
      playback = const AttachmentPlayback();
    });
    await loadMedia();
  }

  /// Playback reached the end and stopped.
  static bool playbackEnded(AttachmentPlayback value) =>
      !value.playing &&
      !value.error &&
      value.duration > Duration.zero &&
      value.position >= value.duration - const Duration(milliseconds: 250);

  bool endedReleaseQueued = false;
  void scheduleEndedRelease() {
    if (endedReleaseQueued || viewerHolds) return;
    endedReleaseQueued = true;
    // After this frame: the release changes the card's state.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      endedReleaseQueued = false;
      if (!mounted || disposed || viewerHolds) return;
      final value = playback;
      if (playbackEnded(value)) unawaited(releasePlayer(PlayerRelease.ended));
    });
  }

  /// How long a card that left the screen keeps its player.
  static const releaseGrace = Duration(seconds: 3);
  Timer? graceTimer;

  /// The card is out of view (scrolled away, route covered, app in the
  /// background): release its player after [releaseGrace], unless the viewer
  /// holds it. [cancelRelease] undoes it when the card is seen again.
  void armRelease(PlayerRelease reason) {
    if (player == null || graceTimer != null || viewerHolds) return;
    graceTimer = Timer(releaseGrace, () {
      graceTimer = null;
      if (!mounted || disposed || viewerHolds) return;
      unawaited(releasePlayer(reason));
    });
  }

  void cancelRelease() {
    graceTimer?.cancel();
    graceTimer = null;
  }

  bool stillQueued = false;

  /// The first picture becomes the card's still in the session (once per
  /// attachment): a card disposed with its player alive (a list drops rows far
  /// from the viewport) still has a picture when it is built again.
  void keepFirstStill() {
    final sessions = controller.attachmentMedia.playerSessions;
    if (stillQueued || sessions.hasStill(mediaKey)) return;
    stillQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || disposed) return;
      if (!stillCaptureSafe) {
        // The app left the foreground between the frame and now: try again
        // with the next picture.
        stillQueued = false;
        return;
      }
      final image = await captureStill();
      if (image == null) return;
      if (disposed) {
        image.dispose();
        return;
      }
      sessions.keepStill(mediaKey, image);
      image.dispose();
    });
  }

  /// Whether a picture of the screen may be taken now. Only while the app is
  /// in the foreground: from the background (`hidden`, `paused`; Android's
  /// surface is already gone then, and `inactive` can still end in a lost
  /// surface) the snapshot of the Impeller OpenGL ES backend dies with
  /// SIGSEGV on the raster thread (`DeviceBufferGLES::OnGetContents`, see
  /// flutter/flutter#192365: a stale upload of the throwaway context the
  /// snapshot builds without a surface). Vulkan, Metal and Skia are not
  /// affected; the OpenGL ES backend is what Android devices without a usable
  /// Vulkan driver and many emulators get. Null (no binding state yet) counts
  /// as foreground.
  bool get stillCaptureSafe {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    return lifecycle == null || lifecycle == AppLifecycleState.resumed;
  }

  /// A downscaled still of the picture on screen, or null (also when the app
  /// is not in the foreground: see [stillCaptureSafe]; the card then keeps the
  /// still it has, the first picture of the clip).
  Future<ui.Image?> captureStill() async {
    if (!stillCaptureSafe) return null;
    final boundary = stillKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary || !playback.hasFrame) return null;
    try {
      final snapshot = InlineMediaTestHooks.stillSnapshot;
      return await (snapshot != null
          ? snapshot(boundary, 1.5)
          : boundary.toImage(pixelRatio: 1.5));
    } on Object {
      return null;
    }
  }

  /// Frees the native player (decoder and frame buffers) and keeps a still of
  /// the last picture; the card is idle again and a tap prepares a new player
  /// (a stream: only the ranges needed). [PlayerRelease.ended] restarts at 0,
  /// the others resume where the card was.
  Future<void> releasePlayer(PlayerRelease reason) async {
    final held = hold;
    if (held == null || disposed) return;
    cancelRelease();
    final last = playback;
    final captured = reason == PlayerRelease.evicted && held.orphaned
        ? null
        : await captureStill();
    if (disposed || !mounted || !identical(hold, held)) {
      captured?.dispose();
      return;
    }
    resumeAt = reason == PlayerRelease.ended ? Duration.zero : last.position;
    final sessions = controller.attachmentMedia.playerSessions;
    sessions.resumeAt[mediaKey] = resumeAt;
    if (captured != null) sessions.keepStill(mediaKey, captured);
    final events = playbackEvents;
    hold = null;
    player = null;
    playbackEvents = null;
    unawaited(events?.cancel());
    held.release();
    final old = still;
    setState(() {
      if (captured != null) still = captured;
      mediaState = RaftInlineMediaState.idle;
      playback = AttachmentPlayback(
        duration: last.duration,
        videoSize: last.videoSize,
      );
    });
    if (old != null && captured != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
    mediaReleased(reason);
  }

  /// The player was released (see [releasePlayer]).
  void mediaReleased(PlayerRelease reason) {}

  Future<void> guarded(Future<void> Function(AttachmentPlayer) run) async {
    final p = player;
    if (!current || p == null) return;
    try {
      await run(p);
    } catch (error) {
      if (current) {
        setState(() {
          mediaState = RaftInlineMediaState.failed;
          failure = playback.failure ?? failureOfError(error);
        });
      }
    }
  }

  @override
  void dispose() {
    disposed = true;
    settleTimer?.cancel();
    graceTimer?.cancel();
    if (hold != null && !pending) {
      controller.attachmentMedia.playerSessions.resumeAt[mediaKey] =
          playbackEnded(playback) ? Duration.zero : playback.position;
    }
    final events = playbackEvents, held = hold, picture = still;
    hold = null;
    player = null;
    playbackEvents = null;
    still = null;
    picture?.dispose();
    unawaited(events?.cancel());
    // Gives the player back; the session disposes it when nobody holds it
    // (a viewer may still), or keeps it paused for a moment.
    held?.release();
    super.dispose();
  }
}

/// A timeline video poster. Opening it starts playback in the viewer.
class InlineVideoAttachment extends StatefulWidget {
  const InlineVideoAttachment({
    super.key,
    required this.controller,
    required this.metadata,
    this.channelId,
    required this.authorized,
    required this.pending,
    this.onOpenPreview,
    this.files,
    this.frameProbe,
    this.frameScheduler,
    this.heroActive = false,
    this.posterListenable,
    this.onDownload,
  });
  final WorkspaceController controller;
  final Map<String, dynamic> metadata;
  final String? channelId;
  final bool Function() authorized;

  /// The Download action of a card whose preview could not be made.
  final VoidCallback? onDownload;

  /// Fetches the poster (the server thumbnail); the shared client by default.
  final AttachmentFiles? files;

  /// Reads the first frame of a video that has no server thumbnail (the
  /// platform's by default) and the scheduler that limits those reads (the
  /// app-wide one by default). Tests inject both.
  final VideoFrameProbe? frameProbe;
  final VideoFrameScheduler? frameScheduler;

  /// The poster wears the card-to-viewer Hero while the viewer it opened is on
  /// screen.
  final bool heroActive;

  /// Receives the poster's image provider whenever it changes (the viewer
  /// stands it in for the video's first frame and flies it).
  final ValueNotifier<ImageProvider?>? posterListenable;

  /// An optimistic (still uploading) attachment: no URL yet, spinner shown.
  final bool pending;

  final VoidCallback? onOpenPreview;

  @override
  State<InlineVideoAttachment> createState() => _InlineVideoAttachmentState();
}

class _InlineVideoAttachmentState extends State<InlineVideoAttachment> {
  ScrollPosition? watched;

  Map<String, dynamic> get metadata => widget.metadata;
  String get filename => '${metadata['filename'] ?? 'attachment'}';
  bool get current => mounted && widget.authorized();

  AttachmentFiles? _ownFiles;
  AttachmentFiles get files =>
      widget.files ?? (_ownFiles ??= AttachmentFiles());

  // Timeline cards only own a bounded poster read. Playback sessions are
  // created by the viewer after the user opens it, on every platform.
  late final VideoCardPoster poster = VideoCardPoster(
    controller: widget.controller,
    metadata: () => widget.metadata,
    channelId: () => widget.channelId ?? '${metadata['channelId'] ?? ''}',
    files: files,
    authorized: () => current,
    nearViewport: nearViewport,
    probeOverride: widget.frameProbe,
    scheduler: widget.frameScheduler,
    onChanged: posterChanged,
  );

  ImageProvider? announced;

  void posterChanged() {
    if (!mounted) return;
    setState(() {});
    announcePoster();
  }

  void announcePoster() {
    final listenable = widget.posterListenable;
    final image = poster.image;
    if (listenable == null || identical(announced, image)) return;
    announced = image;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && identical(announced, image)) listenable.value = image;
    });
  }

  void syncPoster() {
    if (widget.pending) return;
    poster.sync(
      box: Size(448, MediaQuery.sizeOf(context).height * .6),
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    );
    announcePoster();
  }

  bool nearViewport({double margin = 160}) {
    final box = context.findRenderObject();
    final scrollable = Scrollable.maybeOf(context)?.context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return false;
    if (scrollable is! RenderBox || !scrollable.attached) return true;
    final card = box.localToGlobal(Offset.zero) & box.size;
    final view = scrollable.localToGlobal(Offset.zero) & scrollable.size;
    return card.overlaps(view.inflate(margin));
  }

  void watchViewport() {
    final position = Scrollable.maybeOf(context)?.position;
    if (position == watched) return;
    unwatchViewport();
    watched = position;
    position?.addListener(checkViewport);
  }

  void unwatchViewport() {
    watched?.removeListener(checkViewport);
    watched = null;
  }

  bool viewportCheckQueued = false;

  // Measure after layout, once per scroll frame, so poster reads outside the
  // viewport are cancelled by the shared scheduler.
  void checkViewport() {
    if (viewportCheckQueued || !mounted) return;
    viewportCheckQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      viewportCheckQueued = false;
      if (mounted) poster.gate();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    syncPoster();
    watchViewport();
  }

  @override
  void didUpdateWidget(InlineVideoAttachment oldWidget) {
    super.didUpdateWidget(oldWidget);
    syncPoster();
  }

  @override
  void dispose() {
    poster.dispose();
    unwatchViewport();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shape = poster.shape;
    return RaftTooltip(
      message: filename,
      child: RaftVideoPosterCard(
        filename: filename,
        poster: widget.pending ? null : poster.image,
        aspectRatio: shape?.aspect,
        duration: shape == null || shape.duration <= Duration.zero
            ? null
            : shape.duration,
        loading: widget.pending,
        onOpen: widget.pending ? null : widget.onOpenPreview,
        failure: widget.pending ? null : poster.failure,
        onRetry: poster.retry,
        onDownload: widget.onDownload,
        heroTag: MediaBrowser.heroTagFor('${metadata['id']}'),
        heroEnabled: widget.heroActive,
      ),
    );
  }
}

/// Web InlineAudioAttachmentCard + InlineAudioPlayer.
class InlineAudioAttachment extends StatefulWidget {
  const InlineAudioAttachment({
    super.key,
    required this.controller,
    required this.metadata,
    this.channelId,
    required this.authorized,
    required this.pending,
    this.onDownload,
    this.onNetworkSettings,
    this.playerFactory,
  });
  final WorkspaceController controller;
  final Map<String, dynamic> metadata;
  final String? channelId;
  final bool Function() authorized;
  final bool pending;
  final VoidCallback? onDownload, onNetworkSettings;
  final AttachmentPlayer Function()? playerFactory;

  @override
  State<InlineAudioAttachment> createState() => _InlineAudioAttachmentState();
}

class _InlineAudioAttachmentState extends State<InlineAudioAttachment>
    with InlineMediaLoader {
  @override
  WorkspaceController get controller => widget.controller;
  @override
  Map<String, dynamic> get metadata => widget.metadata;
  @override
  String? get channelId => widget.channelId;
  @override
  bool get pending => widget.pending;
  @override
  bool Function() get authorized => widget.authorized;
  @override
  AttachmentPlayer Function()? get playerFactoryOverride =>
      widget.playerFactory;
  @override
  bool get wantsVideo => false;

  bool playRequested = false;

  @override
  void mediaReady() {
    if (!playRequested) return;
    playRequested = false;
    unawaited(guarded((p) => p.toggle()));
  }

  /// A tap on an audio card whose player is released or still being prepared
  /// prepares it and plays as soon as it is ready; it is never dropped.
  Future<void> togglePlay() async {
    if (widget.pending) return;
    if (mediaState == RaftInlineMediaState.idle) {
      playRequested = true;
      await loadMedia();
    } else if (mediaState == RaftInlineMediaState.loading) {
      playRequested = true;
    } else if (mediaState == RaftInlineMediaState.ready) {
      await guarded((p) => p.toggle());
    }
  }

  @override
  Widget build(BuildContext context) => RaftInlineAudio(
    filename: filename,
    state: widget.pending ? RaftInlineMediaState.loading : mediaState,
    playing: playback.playing,
    position: playback.position,
    duration: playback.duration,
    volume: (playback.volume / 100).clamp(0.0, 1.0),
    onDownload: widget.pending ? null : widget.onDownload,
    onTogglePlay: () => unawaited(togglePlay()),
    onSeek: (v) => guarded((p) => p.seek(v)),
    onVolume: (v) => guarded((p) => p.volume(v * 100)),
    failureMessage: mediaState == RaftInlineMediaState.failed
        ? mediaFailureMessage(context, failure, video: false)
        : null,
    onRetry: failedActions.retry ? () => unawaited(retry()) : null,
    onNetworkSettings: failedActions.networkSettings
        ? widget.onNetworkSettings
        : null,
  );

  MediaFailureActions get failedActions =>
      mediaState == RaftInlineMediaState.failed
      ? MediaFailureActions.of(failure)
      : const MediaFailureActions();

  /// Retry on the failed card: prepare again and play once it is ready.
  Future<void> retry() async {
    playRequested = true;
    await retryMedia();
  }
}
