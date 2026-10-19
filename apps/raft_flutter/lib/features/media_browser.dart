import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/attachment_image_repository.dart';
import '../data/workspace_controller.dart';
import '../platform/attachment_files.dart';
import '../platform/attachment_player.dart';
import '../platform/attachment_stream.dart' show attachmentMediaKey;
import '../platform/native_sharing.dart';
import 'attachment_image_loader.dart';
import 'attachment_preview_dialog.dart' show HdrDetector;
import 'attachment_transfers.dart';
import 'media_image_page.dart';
import 'inline_attachment_media.dart' show InlineMediaTestHooks;
import 'media_items.dart';
import 'media_video_page.dart';

/// The media browser of a message (Web `ImageLightbox`, extended): every
/// previewable image of the message, arrows / ArrowLeft / ArrowRight / swipe
/// between them (no wrap), the counter chip and thumbnail strip, zoom that
/// resets when the page changes.
///
/// Wide layouts keep Web's frame (Download in the header). Phones show a black
/// immersive stage: a tap toggles the chrome (top bar with Share and More, the
/// strip and the caption below), a drag down dismisses, a long press opens the
/// Save / Share menu. The picture flies in from the tapped card ([heroTag]).
///
/// Each page loads its original on demand through the shared repository
/// (signed when it is not stored). Once the current page is ready, its two
/// neighbours are fetched once at display size (one image each side); nothing
/// further is signed ahead.
class MediaBrowser extends StatefulWidget {
  const MediaBrowser({
    super.key,
    required this.controller,
    required this.files,
    required this.sharing,
    required this.items,
    required this.initialIndex,
    required this.messageId,
    required this.authorized,
    required this.onClose,
    this.message,
    this.page = false,
    this.openerPlaceholder,
    this.openerPreviewFailed = false,
    this.autoplay = false,
    this.progressRoute,
    this.onShowInMessage,
    this.onNetworkSettings,
    this.playerFactory,
    this.hdrDetector,
  });
  final WorkspaceController controller;
  final AttachmentFiles files;
  final NativeSharing sharing;

  /// Every page of the browser, in message order.
  final List<MediaItem> items;
  final int initialIndex;
  final String? messageId;

  /// Who sent the message, when, and what it says (sub-line and caption).
  final MediaMessageInfo? message;
  final bool Function() authorized;
  final VoidCallback onClose;

  /// Phone page route (not the wide dialog).
  final bool page;

  /// The list preview of `items[initialIndex]`, standing in until its
  /// original is ready.
  final ImageProvider? openerPlaceholder;
  final bool openerPreviewFailed;

  /// The opening page is a video that was opened to play (a tap on a phone's
  /// video card): it starts as soon as its player is ready.
  final bool autoplay;

  /// The dialog that shows a picker download's progress.
  final AttachmentProgressRouteBuilder? progressRoute;

  /// Settings > Network, offered by a video that failed because of the
  /// connection or a proxy (closes the browser first).
  final VoidCallback? onNetworkSettings;

  /// Replace the platform player and the HDR probe (tests).
  final AttachmentPlayer Function()? playerFactory;
  final HdrDetector? hdrDetector;

  /// "Show in message": closes the browser and scrolls the chat to the
  /// message. Null leaves the menu entry out.
  final VoidCallback? onShowInMessage;

  /// Hero tag of the picture of attachment [id].
  static Object heroTagFor(String id) => 'media-$id';

  @override
  State<MediaBrowser> createState() => MediaBrowserState();
}

class MediaBrowserState extends State<MediaBrowser>
    with WidgetsBindingObserver {
  late int index = widget.initialIndex.clamp(0, widget.items.length - 1);
  late final PageController pages = PageController(initialPage: index);
  final zooms = <int, TransformationController>{};
  final pageKeys = <int, GlobalKey<AttachmentLightboxImageState>>{};
  final _transfers = <int, AttachmentTransfers>{};

  /// The player lifecycle of every video page that was built.
  final stages = <int, MediaVideoStage>{};
  final _thumbLeases = <int, WorkspaceAttachmentImageLease>{};
  final _thumbs = <int, ImageProvider>{};
  final _preloads = <int, WorkspaceAttachmentImageLease>{};
  bool _preloadSuppressed = false;
  bool zoomed = false;
  bool _disposed = false;

  /// Phone chrome (top bar, caption, strip, video controls) visibility; a tap
  /// toggles it. Hidden is the immersive mode (the app's own chrome only: the
  /// system bars are never touched).
  final chrome = ValueNotifier<bool>(true);

  /// A screen reader is on: the chrome stays, a tap does not toggle it,
  /// nothing auto-hides.
  bool _accessible = false;

  /// The viewer is closing (or gone): nothing auto-hides any more.
  bool _closing = false;

  /// A playing video hides the chrome after [raftVideoControlsIdle] without an
  /// interaction: no finger down, no menu open.
  Timer? _autoHide;
  int _pointers = 0;
  bool _menuOpen = false;
  MediaVideoStage? _watched;

  /// Pages whose original has been on screen: paging back to one does not
  /// show the progress chip again.
  final _settledPages = <int>{};

  WorkspaceController get w => widget.controller;
  List<MediaItem> get items => widget.items;
  Map<String, dynamic> item(int i) => items[i].metadata;
  String ownerChannel(int i) =>
      attachmentOwnerChannel(w, item(i), widget.messageId);

  /// Phones: Share and Save to the photo library are on offer.
  bool get phoneMenu =>
      widget.page &&
      (widget.files.gallerySupported || widget.sharing.supported);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    chrome.addListener(_chromeChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadThumbnails();
      if (items[index].isVideo) {
        stageFor(index).enter(autoplay: widget.autoplay);
      }
      _watchStage();
    });
  }

  /// A video page owns one player lifecycle; it exists as soon as the page is
  /// built and prepares only once it is entered and has rested.
  MediaVideoStage stageFor(int i) => stages.putIfAbsent(
    i,
    () => MediaVideoStage(
      controller: w,
      metadata: item(i),
      authorized: widget.authorized,
      channelId: ownerChannel(i),
      playerFactory: widget.playerFactory ?? InlineMediaTestHooks.playerFactory,
      hdrDetector: widget.hdrDetector,
    ),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _accessible = MediaQuery.accessibleNavigationOf(context);
    _syncAutoHide(restart: true);
  }

  void _chromeChanged() => _syncAutoHide(restart: true);

  /// A tap on the stage, the chrome or a thumbnail; a screen reader has no
  /// immersive mode.
  void toggleChrome() {
    if (_accessible) return;
    chrome.value = !chrome.value;
  }

  /// The first zoom gesture puts the chrome away.
  void _enterImmersive() {
    if (_accessible) return;
    chrome.value = false;
  }

  bool get _autoHideDue =>
      widget.page &&
      !_closing &&
      !_accessible &&
      !_menuOpen &&
      _pointers == 0 &&
      chrome.value &&
      items[index].isVideo &&
      (stages[index]?.playback.playing ?? false);

  /// (Re)starts the 3 s count while a video plays under visible chrome; any
  /// other state stops it. [restart]: an interaction just happened.
  void _syncAutoHide({bool restart = false}) {
    if (!_autoHideDue) {
      _autoHide?.cancel();
      _autoHide = null;
      return;
    }
    if (_autoHide != null && !restart) return;
    _autoHide?.cancel();
    _autoHide = Timer(raftVideoControlsIdle, () {
      _autoHide = null;
      if (mounted && _autoHideDue) chrome.value = false;
    });
  }

  /// Follows the playback of the current video page (play / pause arms and
  /// stops the auto-hide).
  void _watchStage() {
    final next = widget.page && items[index].isVideo ? stageFor(index) : null;
    if (identical(next, _watched)) return;
    _watched?.removeListener(_syncAutoHide);
    _watched = next;
    next?.addListener(_syncAutoHide);
    _syncAutoHide();
  }

  /// Audio stops when the app goes to the background (and does not resume).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) return;
    final p = stages[index]?.player;
    if (p != null) unawaited(p.pause().catchError((Object _) {}));
    _releasePreloads();
  }

  @override
  void didHaveMemoryPressure() {
    _preloadSuppressed = true;
    _releasePreloads();
  }

  void _releasePreloads() {
    for (final lease in _preloads.values) {
      lease.release(discard: true);
    }
    _preloads.clear();
  }

  /// One zoom / pan state per page; every one is disposed with the viewer.
  TransformationController zoomFor(int i) => zooms.putIfAbsent(
    i,
    () => TransformationController()..addListener(_zoomChanged),
  );

  void _zoomChanged() {
    final now = (zooms[index]?.value.getMaxScaleOnAxis() ?? 1) > 1.001;
    if (now != zoomed && mounted) setState(() => zoomed = now);
  }

  AttachmentTransfers transfersFor(int i) => _transfers.putIfAbsent(
    i,
    () => AttachmentTransfers(
      controller: w,
      files: widget.files,
      sharing: widget.sharing,
      metadata: item(i),
      ownerChannel: ownerChannel(i),
      isImage: !items[i].isVideo,
      context: () => mounted ? context : null,
      scope: () => (
        alive: () => mounted && !_disposed,
        current: () => mounted && !_disposed && widget.authorized(),
      ),
      onChanged: () {
        if (mounted) setState(() {});
      },
      settleOriginal: () =>
          pageKeys[i]?.currentState?.settled ?? Future.value(),
      progressRoute: widget.progressRoute,
    ),
  );

  AttachmentImageKey _originalKey(int i) =>
      attachmentOriginalKey(w, item(i), ownerChannel(i));

  AttachmentLightboxImageState? get _currentPage =>
      pageKeys[index]?.currentState;

  /// Server thumbnails (their signature came with the message) stand in for
  /// pages and fill the thumbnail strip. An image without one shows its
  /// number; nothing is signed for the strip.
  void _loadThumbnails() {
    if (_disposed) return;
    for (var i = 0; i < items.length; i++) {
      final meta = item(i);
      if (attachmentThumbnailUrl(meta) == null || _thumbLeases.containsKey(i)) {
        continue;
      }
      try {
        final key = AttachmentImageKey.fromMetadata(
          scope: w.attachmentImageScope,
          channelId: ownerChannel(i),
          metadata: meta,
          rendition: 'thumbnail',
        );
        final lease = w.attachmentMedia.acquireImage(
          key,
          authorized: widget.authorized,
          load: attachmentImageLoader(
            controller: w,
            files: widget.files,
            metadata: meta,
            key: key,
          ),
        );
        _thumbLeases[i] = lease;
        final ready = lease.lease.value;
        if (ready != null) {
          _thumbs[i] = ready;
        } else {
          unawaited(
            lease.lease.ready.then<void>((provider) {
              if (mounted && !_disposed) setState(() => _thumbs[i] = provider);
            }, onError: (Object _) {}),
          );
        }
      } catch (_) {
        // No thumbnail for this image: the strip shows its number.
      }
    }
    if (mounted) setState(() {});
  }

  ImageProvider? _placeholder(int i) => i == widget.initialIndex
      ? (widget.openerPlaceholder ?? _thumbs[i])
      : _thumbs[i];

  /// Once the current page shows its original, fetch each neighbour once at
  /// display size; release what is no longer adjacent.
  void _preloadNeighbours() {
    if (!mounted || _disposed || _preloadSuppressed || !widget.authorized()) {
      return;
    }
    final wanted = {
      for (final n in [index - 1, index + 1])
        if (n >= 0 && n < items.length && !items[n].isVideo) n,
    };
    for (final stale
        in _preloads.keys.where((k) => !wanted.contains(k)).toList()) {
      _preloads.remove(stale)?.release();
    }
    final stage = MediaQuery.sizeOf(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    for (final n in wanted) {
      if (_preloads.containsKey(n)) continue;
      final meta = item(n);
      try {
        final full = _originalKey(n);
        final key = AttachmentImageKey(
          scope: full.scope,
          channelId: full.channelId,
          attachmentId: full.attachmentId,
          revision: full.revision,
          rendition: full.rendition,
          target: AttachmentDecodeTarget.box(
            stage.width,
            stage.height,
            devicePixelRatio: dpr,
          ),
        );
        final lease = w.attachmentMedia.acquireImage(
          key,
          authorized: widget.authorized,
          load: attachmentImageLoader(
            controller: w,
            files: widget.files,
            metadata: meta,
            key: key,
          ),
        );
        _preloads[n] = lease;
        unawaited(lease.lease.ready.then<void>((_) {}, onError: (Object _) {}));
      } catch (_) {
        // A neighbour that cannot be preloaded loads when it is shown.
      }
    }
  }

  void _pageReady(int i) {
    if (pageKeys[i]?.currentState?.full != null) _settledPages.add(i);
    if (i == index) _preloadNeighbours();
  }

  void _onPageChanged(int next) {
    // Web: zoom and pan reset on prev / next.
    zooms[index]?.value = Matrix4.identity();
    stages[index]?.leave();
    setState(() {
      index = next;
      zoomed = false;
    });
    if (items[next].isVideo) stageFor(next).enter();
    _watchStage();
    _syncAutoHide(restart: true);
    final page = _currentPage;
    if (page != null && (page.full != null || page.failed)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _preloadNeighbours());
    }
  }

  /// Arrows, thumbnails and keys: no wrap.
  void goTo(int target) {
    if (target < 0 || target >= items.length || target == index) return;
    if (!pages.hasClients) return;
    // Web swaps the image at once (no transition) and the desktop keeps that;
    // a phone has no Web counterpart and swipes animate natively, so a step
    // to the next / previous image glides too (a longer jump would build,
    // and start loading, every page in between: it cuts). Reduced motion
    // snaps.
    if (widget.page &&
        (target - index).abs() == 1 &&
        !MediaQuery.disableAnimationsOf(context)) {
      unawaited(
        pages.animateToPage(
          target,
          duration: RaftScale.defaultTransitionDuration,
          curve: RaftScale.defaultTransitionCurve,
        ),
      );
    } else {
      pages.jumpToPage(target);
    }
  }

  /// Web handleKeyDown: while zoomed the arrows do not navigate.
  void _key(int delta) {
    if (zoomed) return;
    goTo(index + delta);
  }

  /// Shift + arrows seek the video page by [delta] (plain arrows page).
  void _seekBy(Duration delta) {
    final stage = stages[index];
    if (stage == null || stage.player == null) return;
    final now = stage.player!.playback;
    final to = now.position + delta;
    final end = now.duration;
    unawaited(
      stage.seek(
        to < Duration.zero
            ? Duration.zero
            : (end > Duration.zero && to > end ? end : to),
      ),
    );
  }

  double _mutedFrom = 100;

  void _toggleMute() {
    final stage = stages[index];
    if (stage == null || stage.player == null) return;
    final volume = stage.player!.playback.volume;
    if (volume > 0) _mutedFrom = volume;
    unawaited(stage.setVolume(volume > 0 ? 0 : _mutedFrom));
  }

  /// Keyboard and accessibility zoom of the current page.
  void zoomStep(double factor) =>
      _currentPage?.surfaceKey.currentState?.zoomStep(factor);

  void resetZoom() => _currentPage?.surfaceKey.currentState?.resetZoom();

  Future<void> _menu(Offset at, {bool full = false}) async {
    if (!widget.authorized()) return;
    final meta = item(index);
    final canSave =
        !items[index].isVideo &&
        widget.files.gallerySupported &&
        !attachmentIsSvg(meta);
    final canShare = !full && widget.sharing.supported;
    final canDownload = full && phoneMenu;
    final canShow = full && widget.onShowInMessage != null;
    if (!canSave && !canShare && !canDownload && !canShow) return;
    final transfers = transfersFor(index);
    String? choice;
    // The chrome stays while a menu is up.
    _menuOpen = true;
    _syncAutoHide();
    await showRaftMessageContextMenu<void>(
      context: context,
      anchor: at,
      builder: (menuContext) {
        void pick(String value) {
          choice = value;
          Navigator.of(menuContext).pop();
        }

        final ios = AttachmentFiles.galleryLabel == 'Save to Photos';
        return RaftMessageContextMenu(
          onDismiss: () => Navigator.of(menuContext).pop(),
          sections: [
            [
              if (canSave)
                RaftMessageContextMenuItem(
                  key: const ValueKey('viewer-menu-save'),
                  label: ios
                      ? raftText(menuContext, 'Save to Photos')
                      : raftText(menuContext, 'Save to Gallery'),
                  icon: raftMessageMenuIcon(RaftGlyph.download),
                  onPressed: () => pick('save'),
                ),
              if (canShare)
                RaftMessageContextMenuItem(
                  key: const ValueKey('viewer-menu-share'),
                  label: raftText(menuContext, 'Share'),
                  icon: raftMessageMenuIcon(RaftGlyph.share2),
                  onPressed: () => pick('share'),
                ),
              if (canDownload)
                RaftMessageContextMenuItem(
                  key: const ValueKey('viewer-menu-download'),
                  label: raftText(menuContext, 'Download file'),
                  icon: raftMessageMenuIcon(RaftGlyph.arrowDown),
                  onPressed: () => pick('download'),
                ),
              if (canShow)
                RaftMessageContextMenuItem(
                  key: const ValueKey('viewer-menu-show'),
                  label: raftText(menuContext, 'Show in message'),
                  icon: raftMessageMenuIcon(RaftGlyph.messageSquare),
                  onPressed: () => pick('show'),
                ),
            ],
          ],
        );
      },
    );
    _menuOpen = false;
    if (!mounted) return;
    _syncAutoHide(restart: true);
    switch (choice) {
      case 'save':
        await transfers.saveToGallery();
      case 'share':
        await transfers.share();
      case 'download':
        await transfers.download();
      case 'show':
        widget.onShowInMessage?.call();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _closing = true;
    _autoHide?.cancel();
    _watched?.removeListener(_syncAutoHide);
    chrome.removeListener(_chromeChanged);
    for (final lease in _thumbLeases.values) {
      lease.release();
    }
    for (final lease in _preloads.values) {
      lease.release();
    }
    _thumbLeases.clear();
    _preloads.clear();
    for (final transfers in _transfers.values) {
      transfers.abort();
    }
    for (final zoom in zooms.values) {
      zoom.removeListener(_zoomChanged);
      zoom.dispose();
    }
    WidgetsBinding.instance.removeObserver(this);
    for (final stage in stages.values) {
      stage.dispose();
    }
    stages.clear();
    chrome.dispose();
    pages.dispose();
    super.dispose();
  }

  /// `sender · time` (phone); wide adds the pixel size and the file size.
  String? _subtitle(BuildContext context, MediaItem current) {
    final info = widget.message;
    final size = current.pixelSize;
    final bytes = current.sizeBytes;
    final parts = [
      if (info?.sender case final sender? when sender.isNotEmpty) sender,
      ?info?.time,
      if (!widget.page && size != null)
        '${size.width.round()}x${size.height.round()}',
      if (!widget.page && bytes != null) RaftAttachmentCard.formatSize(bytes),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  Map<ShortcutActivator, VoidCallback> _shortcuts() {
    final count = items.length;
    void zoomIn() => zoomStep(1.5);
    void zoomOut() => zoomStep(1 / 1.5);
    return {
      if (count > 1) ...{
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _key(-1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _key(1),
        const SingleActivator(LogicalKeyboardKey.home): () => goTo(0),
        const SingleActivator(LogicalKeyboardKey.end): () => goTo(count - 1),
      },
      // `+` is Shift+= on a US layout and a key of its own on others.
      for (final key in [
        LogicalKeyboardKey.equal,
        LogicalKeyboardKey.add,
        LogicalKeyboardKey.numpadAdd,
      ]) ...{
        SingleActivator(key): zoomIn,
        SingleActivator(key, shift: true): zoomIn,
        RaftPlatformKeys.command(key): zoomIn,
      },
      for (final key in [
        LogicalKeyboardKey.minus,
        LogicalKeyboardKey.numpadSubtract,
      ]) ...{
        SingleActivator(key): zoomOut,
        RaftPlatformKeys.command(key): zoomOut,
      },
      RaftPlatformKeys.command(LogicalKeyboardKey.digit0): resetZoom,
      RaftPlatformKeys.command(LogicalKeyboardKey.numpad0): resetZoom,
      if (items[index].isVideo) ...{
        const SingleActivator(LogicalKeyboardKey.space): () =>
            unawaited(stages[index]?.togglePlay() ?? Future<void>.value()),
        const SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true): () =>
            _seekBy(const Duration(seconds: -5)),
        const SingleActivator(LogicalKeyboardKey.arrowRight, shift: true): () =>
            _seekBy(const Duration(seconds: 5)),
        const SingleActivator(LogicalKeyboardKey.keyM): _toggleMute,
      },
      // Web binds both Ctrl+W and Cmd+W to close, on every platform.
      const SingleActivator(LogicalKeyboardKey.keyW, control: true):
          widget.onClose,
      const SingleActivator(LogicalKeyboardKey.keyW, meta: true):
          widget.onClose,
    };
  }

  List<RaftMediaAction> _mediaActions(BuildContext context) {
    if (!widget.page) return const [];
    final transfers = transfersFor(index);
    final canMore = phoneMenu || widget.onShowInMessage != null;
    return [
      if (widget.sharing.supported)
        RaftMediaAction(
          id: const ValueKey('viewer-share'),
          glyph: RaftGlyph.share2,
          label: 'Share',
          onPressed: (_) {
            if (widget.authorized()) unawaited(transfers.share());
          },
        ),
      // A phone-sized window without a share sheet or a photo library (a
      // desktop): the header's Download stays one tap away.
      if (!phoneMenu)
        RaftMediaAction(
          id: const ValueKey('attachment-download'),
          glyph: RaftGlyph.download,
          label: 'Download',
          onPressed: (_) {
            if (widget.authorized()) unawaited(transfers.download());
          },
        ),
      if (canMore)
        RaftMediaAction(
          id: const ValueKey('viewer-more'),
          glyph: RaftGlyph.ellipsis,
          label: 'More',
          onPressed: (anchor) =>
              unawaited(_menu(anchor.bottomRight, full: true)),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final count = items.length;
    final current = items[index];
    final transfers = transfersFor(index);
    final actions = widget.page
        ? const <Widget>[]
        : [
            RaftLightboxIconAction(
              key: const ValueKey('attachment-download'),
              glyph: RaftGlyph.download,
              label: 'Download',
              onPressed: widget.authorized()
                  ? () => unawaited(transfers.download())
                  : null,
            ),
          ];
    final lightbox = AttachmentImageLightbox(
      page: widget.page,
      title: current.filename,
      subtitle: _subtitle(context, current),
      kind: current.kind,
      zoom: zoomFor(index),
      onClose: widget.onClose,
      actions: actions,
      mediaActions: _mediaActions(context),
      chrome: chrome,
      caption: widget.message?.caption,
      dismissEnabled: !zoomed,
      onDismissDrag: (dragging) => stages[index]?.setMoving(dragging),
      shortcuts: _shortcuts(),
      gallery: count > 1
          ? AttachmentLightboxGallery(
              index: index,
              thumbnails: [for (var i = 0; i < count; i++) _placeholder(i)],
              items: items,
              onSelect: goTo,
            )
          : null,
      child: GestureDetector(
        key: const ValueKey('viewer-stage'),
        behavior: HitTestBehavior.translucent,
        onLongPressStart: phoneMenu
            ? (d) => unawaited(_menu(d.globalPosition))
            : null,
        // A native video view (HDR) leaves the page for as long as it swipes.
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification.depth != 0) return false;
            if (notification is ScrollStartNotification) {
              stages[index]?.setMoving(true);
            } else if (notification is ScrollEndNotification) {
              stages[index]?.setMoving(false);
            }
            return false;
          },
          child: PageView.builder(
            key: const ValueKey('viewer-pages'),
            controller: pages,
            itemCount: count,
            // Zoomed in, a horizontal drag pans the image instead.
            physics: zoomed
                ? const NeverScrollableScrollPhysics()
                : const PageScrollPhysics(),
            onPageChanged: _onPageChanged,
            itemBuilder: _page,
          ),
        ),
      ),
    );
    if (!widget.page) return lightbox;
    // Any finger on the viewer (the stage, a bar, the seek rail) postpones the
    // auto-hide of a playing video; it counts again once the fingers are up.
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        _pointers++;
        _syncAutoHide();
      },
      onPointerUp: (_) => _pointerUp(),
      onPointerCancel: (_) => _pointerUp(),
      child: lightbox,
    );
  }

  void _pointerUp() {
    _pointers = _pointers > 0 ? _pointers - 1 : 0;
    _syncAutoHide(restart: true);
  }

  Widget _page(BuildContext context, int i) {
    final pageItem = items[i];
    if (pageItem.isVideo) return _videoPage(context, i);
    final pageMeta = pageItem.metadata;
    final key = pageKeys.putIfAbsent(
      i,
      () => GlobalKey<AttachmentLightboxImageState>(),
    );
    final original = _originalKey(i);
    final label = _pageLabel(context, i);
    return Semantics(
      container: true,
      label: label,
      customSemanticsActions: {
        CustomSemanticsAction(label: raftText(context, 'Zoom in')): () =>
            pageKeys[i]?.currentState?.surfaceKey.currentState?.zoomStep(1.5),
        CustomSemanticsAction(label: raftText(context, 'Zoom out')): () =>
            pageKeys[i]?.currentState?.surfaceKey.currentState?.zoomStep(
              1 / 1.5,
            ),
        CustomSemanticsAction(label: raftText(context, 'Fit to screen')): () =>
            pageKeys[i]?.currentState?.surfaceKey.currentState?.resetZoom(),
      },
      child: _imageRoom(
        context,
        AttachmentLightboxImage(
          key: key,
          imageKey: ValueKey('attachment-image-${pageMeta['id']}'),
          zoom: zoomFor(i),
          acquire: () {
            // Speculative neighbours must yield to a page explicitly opened
            // by the user, including the outgoing page during a swipe.
            _releasePreloads();
            return w.attachmentMedia.acquireImage(
              original,
              authorized: widget.authorized,
              load: attachmentImageLoader(
                controller: w,
                files: widget.files,
                metadata: pageMeta,
                key: original,
              ),
              foreground: true,
            );
          },
          placeholder: _placeholder(i),
          previewFailed: i == widget.initialIndex && widget.openerPreviewFailed,
          title: pageItem.filename,
          transferTotalHint: pageItem.sizeBytes,
          imageSize: pageItem.pixelSize,
          settledBefore: _settledPages.contains(i),
          onReady: () => _pageReady(i),
          heroTag: MediaBrowser.heroTagFor(pageItem.id),
          closeOnTapOutside: !widget.page,
          onTap: widget.page ? toggleChrome : null,
          onZoomGesture: widget.page ? _enterImmersive : null,
        ),
      ),
    );
  }

  /// An image page on a phone fits, and pans when zoomed, in the room between
  /// the top bar and the bottom band while the chrome shows (the room between
  /// the system bars while it is hidden), gliding between the two like the
  /// chrome fades.
  Widget _imageRoom(BuildContext context, Widget page) {
    final insets = RaftMediaChromeInsets.maybeOf(context);
    if (insets == null) return page;
    final room = AnimatedPadding(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : RaftScale.defaultTransitionDuration,
      curve: RaftScale.defaultTransitionCurve,
      padding: insets.imageRoom,
      child: page,
    );
    // The picture's own surface only covers the room; a tap on the rest of the
    // stage (the bars' backdrops, the system insets) toggles the chrome too.
    // Inside the room the surface's recognizer is deeper and wins the arena.
    return widget.page
        ? GestureDetector(
            key: const ValueKey('viewer-stage-tap'),
            behavior: HitTestBehavior.translucent,
            onTap: toggleChrome,
            child: room,
          )
        : room;
  }

  /// Semantics label of page [i] ("Video 2 of 9, name, sender, time").
  String _pageLabel(BuildContext context, int i) {
    final info = widget.message;
    return [
      raftFormat(
        context,
        items[i].isVideo
            ? 'Video {index} of {count}'
            : 'Image {index} of {count}',
        {'index': i + 1, 'count': items.length},
      ),
      items[i].filename,
      ?info?.sender,
      ?info?.time,
    ].join(', ');
  }

  /// The size a video was read to have (its first-frame read), when the
  /// message does not say.
  Size? _rememberedSize(int i) {
    final shape =
        w.attachmentMedia.playerSessions.shapes[attachmentMediaKey(item(i))];
    return shape == null
        ? null
        : Size(shape.width.toDouble(), shape.height.toDouble());
  }

  Widget _videoPage(BuildContext context, int i) {
    final stage = stageFor(i);
    final chromeInsets = RaftMediaChromeInsets.maybeOf(context);
    return Semantics(
      container: true,
      label: _pageLabel(context, i),
      // Desktop pictures and controls share the gallery's reserved strip room.
      // The immersive phone page uses its measured chrome inset instead.
      child: RaftLightboxStageInset(
        vertical: widget.page ? 0 : RaftLightboxStageInset.of(context),
        child: ValueListenableBuilder<bool>(
          valueListenable: chrome,
          builder: (context, shown, _) => MediaVideoPage(
            stage: stage,
            filename: items[i].filename,
            immersive: widget.page,
            poster: _placeholder(i),
            heroTag: MediaBrowser.heroTagFor(items[i].id),
            declaredSize: items[i].pixelSize ?? _rememberedSize(i),
            onSurfaceTap: widget.page ? toggleChrome : null,
            controlsInset: widget.page ? (chromeInsets?.bottom ?? 0) : 0,
            controlsVisible: widget.page ? shown || _accessible : null,
            onDownload: () => transfersFor(i).download(),
            onNetworkSettings: widget.onNetworkSettings,
          ),
        ),
      ),
    );
  }
}
