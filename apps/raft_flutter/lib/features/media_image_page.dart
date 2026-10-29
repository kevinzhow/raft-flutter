import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/attachment_image_repository.dart';
import '../data/workspace_controller.dart';
import 'attachment_image_zoom.dart';
import 'attachment_transfer_view.dart';
import 'media_items.dart';

/// Gallery state of the lightbox: the message's media (Web `images` /
/// `currentIndex`, plus videos behind the media-browser flag).
class AttachmentLightboxGallery {
  const AttachmentLightboxGallery({
    required this.index,
    required this.thumbnails,
    required this.onSelect,
    this.items,
  });
  final int index;
  final List<ImageProvider?> thumbnails;
  final ValueChanged<int> onSelect;

  /// Kinds and durations of the pages (video thumbnails carry a badge);
  /// without them every page is an image.
  final List<MediaItem>? items;
  int get count => thumbnails.length;
}

/// The media browser frame around the stage. Wide layouts keep Web's
/// `ImageLightbox` frame: title bar (kind glyph, bold filename, sub-line,
/// gallery counter, [actions]), stage and the strip in a reserved band; no
/// previous / next arrows (owner decision 2026-10-13). Phone layouts are the
/// black immersive stage: [mediaActions] (Share, More) in the top bar, tap
/// toggles the chrome, a drag down dismisses.
class AttachmentImageLightbox extends StatelessWidget {
  const AttachmentImageLightbox({
    super.key,
    required this.title,
    required this.zoom,
    required this.onClose,
    required this.child,
    this.subtitle,
    this.kind,
    this.actions = const [],
    this.mediaActions = const [],
    this.shortcuts = const {},
    this.gallery,
    this.page = false,
    this.chrome,
    this.caption,
    this.dismissEnabled = true,
    this.onDismissDrag,
  });
  final String title;
  final String? subtitle;

  /// Kind of the current page: the wide header's glyph (Web's image lightbox
  /// header has none, so a null kind draws none).
  final MediaKind? kind;
  final TransformationController zoom;
  final VoidCallback onClose;
  final Widget child;

  /// Wide header actions (Download).
  final List<Widget> actions;

  /// Phone top-bar actions (Share, More, Download without a share sheet).
  final List<RaftMediaAction> mediaActions;
  final Map<ShortcutActivator, VoidCallback> shortcuts;
  final AttachmentLightboxGallery? gallery;
  final bool page;

  /// Phone chrome visibility (tap toggles it); wide layouts ignore it.
  final ValueListenable<bool>? chrome;
  final String? caption;
  final bool dismissEnabled;

  /// A phone drag-to-dismiss began or ended.
  final ValueChanged<bool>? onDismissDrag;

  @override
  Widget build(BuildContext context) {
    final g = gallery != null && gallery!.count > 1 ? gallery : null;
    final strip = g == null
        ? null
        : RaftMediaStrip(
            compact: page,
            index: g.index,
            onSelect: g.onSelect,
            items: [
              for (var i = 0; i < g.count; i++)
                RaftMediaStripItem(
                  thumbnail: g.thumbnails[i],
                  video: g.items?[i].isVideo ?? false,
                  duration: g.items?[i].duration,
                  label: raftFormat(
                    context,
                    (g.items?[i].isVideo ?? false)
                        ? 'Video {index} of {count}'
                        : 'Image {index} of {count}',
                    {'index': i + 1, 'count': g.count},
                  ),
                ),
            ],
          );
    final counter = g == null
        ? null
        : RaftLightboxCounter(index: g.index, count: g.count);
    if (page) {
      return RaftMediaImmersiveShell(
        title: title,
        subtitle: subtitle,
        chrome: chrome ?? const _Always(),
        onClose: onClose,
        counter: counter,
        actions: mediaActions,
        strip: strip,
        caption: caption,
        shortcuts: shortcuts,
        dismissEnabled: dismissEnabled,
        onDismissDrag: onDismissDrag,
        child: child,
      );
    }
    return RaftAttachmentLightbox(
      title: title,
      subtitle: subtitle,
      leading: kind == null
          ? null
          : RaftIcon(
              kind == MediaKind.video ? RaftGlyph.video : RaftGlyph.image,
              size: 16,
            ),
      titleBold: true,
      shortcuts: shortcuts,
      onResetZoom: () => zoom.value = Matrix4.identity(),
      onClose: onClose,
      meta: counter,
      actions: actions,
      overlayInset: strip == null ? 0 : raftMediaDesktopStripBand,
      overlay: strip,
      child: child,
    );
  }
}

class _Always extends ValueListenable<bool> {
  const _Always();
  @override
  bool get value => true;
  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
}

/// Lightbox body: the full-resolution original, decoded only while open.
/// The list preview (thumbnail) stands in until it is ready (Web shows the
/// thumbnail); a thin bar along its bottom edge and a size chip show the
/// original's download. Without a thumbnail a placeholder with the image's
/// aspect ratio takes its place. Leaving the viewer cancels the download.
class AttachmentLightboxImage extends StatefulWidget {
  const AttachmentLightboxImage({
    super.key,
    required this.imageKey,
    required this.zoom,
    this.acquire,
    this.image,
    required this.placeholder,
    required this.previewFailed,
    this.title = '',
    this.transferTotalHint,
    this.imageSize,
    this.onReady,
    this.settledBefore = false,
    this.heroTag,
    this.onTap,
    this.onZoomGesture,
    this.closeOnTapOutside = true,
  });

  /// Tag of the picture's Hero (card to stage); null leaves it out.
  final Object? heroTag;

  /// A single tap on the stage (phone: toggles the chrome).
  final VoidCallback? onTap;

  /// A zoom gesture began (phone: hides the chrome).
  final VoidCallback? onZoomGesture;

  /// Web: a tap outside the painted image closes (desktop). A phone's tap
  /// toggles the chrome instead.
  final bool closeOnTapOutside;

  /// The viewer showed this page's original already: paging back to it does
  /// not bring the progress chip back.
  final bool settledBefore;

  /// Called once the full-resolution original is on screen (or failed): the
  /// viewer then preloads this page's neighbours.
  final VoidCallback? onReady;

  /// File name of the failure card.
  final String title;
  final Key imageKey;
  final TransformationController zoom;

  /// Leases the full-resolution original; null when [image] is already known.
  final WorkspaceAttachmentImageLease Function()? acquire;

  /// An already decoded original (tests and callers that hold the bitmap).
  final ImageProvider? image;
  final ImageProvider? placeholder;
  final bool previewFailed;

  /// The original's size in bytes; stands in for a missing Content-Length.
  final int? transferTotalHint;

  /// The original's pixel size (attachment `width` / `height`); the stand-in
  /// takes this aspect ratio so the stage does not jump when the image lands.
  final Size? imageSize;
  @override
  State<AttachmentLightboxImage> createState() =>
      AttachmentLightboxImageState();
}

class AttachmentLightboxImageState extends State<AttachmentLightboxImage> {
  WorkspaceAttachmentImageLease? lease;
  AttachmentTransferView? transfer;
  ImageProvider? full;
  Object? failure;
  bool get failed => failure != null;
  bool get _canRetry => failure is! AttachmentImageDecodeFailed;
  bool get _downloadFailed =>
      failure is! AttachmentImageBudgetExceeded &&
      failure is! AttachmentImageDecodeFailed &&
      failure is! AttachmentImageDecodeUnavailable;

  String get _failureMessage => switch (failure) {
    AttachmentImageBudgetExceeded() =>
      'Not enough memory to preview this image. Download it to open in another app.',
    AttachmentImageDecodeFailed() =>
      'Cannot decode this image. Download it to open in another app.',
    AttachmentImageDecodeUnavailable() =>
      'Cannot prepare this image preview right now. Try again or download it to open in another app.',
    _ => 'Failed to load image',
  };

  /// The progress chip waits [progressDelay] after the load starts: a load
  /// that ends sooner (cache, neighbour, paging back) never flashes it.
  static const progressDelay = Duration(milliseconds: 300);
  bool progressShown = false;
  Timer? _progressTimer;

  /// Completes when the load under way ends (never errors); a save of this
  /// page's original waits for it instead of fetching the bytes again.
  Future<void> settled = Future<void>.value();

  @override
  void initState() {
    super.initState();
    full = widget.image;
    if (widget.acquire != null) {
      settled = load();
      unawaited(settled);
    } else {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => widget.onReady?.call(),
      );
    }
  }

  Future<void> load() async {
    final WorkspaceAttachmentImageLease next;
    try {
      next = widget.acquire!();
    } catch (error) {
      failure = error;
      // A retry reaches here after the frame; initState must not setState.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
      return;
    }
    lease = next;
    transfer = AttachmentTransferView(next.lease.progress);
    final ready = next.lease.value;
    if (ready == null && !widget.settledBefore) _startProgressDelay();
    if (ready != null) {
      full = ready;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onReady?.call();
      });
      return;
    }
    try {
      final provider = await next.lease.ready;
      _stopProgressDelay();
      if (mounted && identical(lease, next)) setState(() => full = provider);
    } catch (error) {
      _stopProgressDelay();
      if (mounted && identical(lease, next)) setState(() => failure = error);
    }
    if (mounted && identical(lease, next)) widget.onReady?.call();
  }

  void _startProgressDelay() {
    _progressTimer?.cancel();
    progressShown = false;
    _progressTimer = Timer(progressDelay, () {
      _progressTimer = null;
      if (mounted) setState(() => progressShown = true);
    });
  }

  void _stopProgressDelay() {
    _progressTimer?.cancel();
    _progressTimer = null;
    progressShown = false;
  }

  /// Tap on the failed chip: fetch the original again.
  void retry() {
    lease?.release(discard: true);
    lease = null;
    transfer = null;
    setState(() => failure = null);
    settled = load();
    unawaited(settled);
  }

  @override
  void dispose() {
    _unwatchDecodedSize();
    // The full-resolution bitmap is not kept once the lightbox closes; its
    // bytes stay in the persistent store for the next open. Releasing the
    // last consumer of an in-flight download cancels it.
    _progressTimer?.cancel();
    lease?.release(discard: true);
    lease = null;
    super.dispose();
  }

  final surfaceKey = GlobalKey<ImageZoomSurfaceState>();

  /// Wraps the picture in the card-to-stage Hero.
  Widget hero(Widget picture, ImageProvider? shuttle) => widget.heroTag == null
      ? picture
      : RaftMediaHero(
          tag: widget.heroTag!,
          image: shuttle,
          fit: BoxFit.contain,
          child: picture,
        );

  /// The pixel size the stage lays the picture out for, decided without
  /// waiting for anything: the decoded original once it is known, else the
  /// attachment's size when it agrees with the thumbnail that is on screen
  /// (server dimensions can be missing or wrong: an EXIF-rotated original, a
  /// forwarded file), else none (the box then takes the thumbnail's shape and
  /// fills the stage).
  Size? get stageNatural {
    final decodedSize = decoded;
    if (decodedSize != null) return decodedSize;
    final declared = widget.imageSize;
    final thumb = placeholderSize;
    if (declared == null) return null;
    if (thumb == null) return declared;
    return _sameShape(declared, thumb) ? declared : null;
  }

  /// Width over height of the box while [stageNatural] is unknown: the
  /// thumbnail's own shape (the card it came from shows that), else 4:3.
  double get stageAspect {
    final thumb = placeholderSize;
    return thumb == null ? 4 / 3 : thumb.width / thumb.height;
  }

  static bool _sameShape(Size a, Size b) =>
      (a.width / a.height) / (b.width / b.height) - 1 < _shapeTolerance &&
      (b.width / b.height) / (a.width / a.height) - 1 < _shapeTolerance;

  /// Aspect ratios within 4 % are the same picture (thumbnails are rounded).
  static const _shapeTolerance = 0.04;

  /// The stage: the thumbnail (or a neutral box) standing in, and the loaded
  /// original from the moment it is there, in ONE tree. The picture is a
  /// single Hero element whose image provider changes (gapless), so the
  /// flight never retargets when the original replaces the stand-in; the
  /// zoom surface (tap, double tap, pinch) and the controller carry over too.
  /// The transfer chip and Retry stay outside the transform.
  Widget stage(BuildContext context, ImageProvider? thumbnail) {
    // The original takes over once its bitmap is decoded (or cannot be): until
    // then the stand-in stays, so the picture is never blank in between.
    final original = full;
    final provider = original != null && _decodedWatch.settled
        ? original
        : (thumbnail ?? original);
    final natural = stageNatural;
    final aspect = stageAspect;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Keep clear of the thumbnail strip band, mirrored so the box stays
        // centred (and the size chip never lands under the strip).
        final inset = RaftLightboxStageInset.of(context);
        final fitted = fittedImageSize(
          constraints.biggest,
          natural,
          verticalInset: inset,
          fillAspect: aspect,
        );
        final picture = provider == null
            ? _addressPlaceholder(context)
            : hero(
                // ignore: raft_lints/avoid_raw_image_decode -- Lightbox stage images are leases decoded at screen size x zoom cap by the repository; the viewer keeps that bounded path.
                Image(
                  image: provider,
                  key: widget.imageKey,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                  errorBuilder: !identical(provider, full)
                      ? null
                      : (context, _, _) => RaftLightboxFailure(
                          title: widget.title,
                          message: 'Failed to load image',
                        ),
                ),
                thumbnail ?? provider,
              );
        // Source ImageLightbox: "Empty-stage clicks close the lightbox. After
        // zoom/pan ... also guard against stage-target clicks that land inside
        // the transformed image." A tap (not a pan / pinch) outside the
        // painted image closes the route; the tap recognizer loses the arena
        // to a drag.
        return Stack(
          fit: StackFit.expand,
          children: [
            ImageZoomSurface(
              key: surfaceKey,
              controller: widget.zoom,
              natural: natural,
              fillAspect: aspect,
              verticalInset: inset,
              onTapOutside: widget.closeOnTapOutside
                  ? () => unawaited(Navigator.maybePop(context))
                  : null,
              onTap: widget.onTap,
              onZoomGesture: widget.onZoomGesture,
              child: picture,
            ),
            if (full == null)
              Center(
                child: SizedBox(
                  width: fitted.width,
                  height: fitted.height,
                  child: _transferOverlay(context, thumbnail),
                ),
              ),
            if (full == null && RaftTokens.of(context).isRaftLook)
              Positioned.fill(
                child: IgnorePointer(
                  child: _withAddressPhase(
                    context,
                    () => _waitingForAddress
                        ? const RaftLightboxLoading()
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  bool get _waitingForAddress =>
      full == null &&
      !failed &&
      widget.placeholder == null &&
      (lease?.lease.waitingForAddress ?? false);

  Widget _withAddressPhase(BuildContext context, Widget Function() builder) {
    final progress = lease?.lease.progress;
    if (!RaftTokens.of(context).isRaftLook || progress == null) {
      return builder();
    }
    return ValueListenableBuilder<AttachmentTransferProgress?>(
      valueListenable: progress,
      builder: (context, _, child) => builder(),
    );
  }

  Widget _addressPlaceholder(BuildContext context) => _withAddressPhase(
    context,
    () => RaftTokens.of(context).isRaftLook && _waitingForAddress
        ? const SizedBox.shrink()
        : const RaftTransferPlaceholder(onDark: true),
  );

  Widget _transferOverlay(BuildContext context, ImageProvider? thumbnail) =>
      _withAddressPhase(
        context,
        () => RaftTokens.of(context).isRaftLook && _waitingForAddress
            ? const SizedBox.shrink()
            : _transferOverlayBody(context, thumbnail),
      );

  Widget _transferOverlayBody(BuildContext context, ImageProvider? thumbnail) =>
      Stack(
        fit: StackFit.expand,
        children: [
          if (failed) ...[
            RaftImageTransferOverlay.failed(inset: 10, onRetry: retry),
            // The red chip alone is easy to miss: a plain Retry button.
            if (widget.acquire != null && _canRetry)
              Center(
                child: RaftTextButton(
                  key: const ValueKey('lightbox-retry'),
                  label: raftText(context, 'Retry'),
                  glyph: RaftGlyph.refreshCw,
                  onPressed: retry,
                ),
              ),
          ] else if (transfer != null && progressShown)
            RaftImageTransferOverlay(
              progress: transfer!,
              fallbackTotal: widget.transferTotalHint,
              labelPrefix: thumbnail == null
                  ? null
                  : raftText(context, 'Original image'),
              inset: 10,
            ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final thumbnail = widget.placeholder;
    if (full == null && failed && (thumbnail == null || !_downloadFailed)) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RaftLightboxFailure(
              title: widget.title,
              // Web ImageLightbox: `common.lightbox.failedToLoad`.
              message: _failureMessage,
            ),
            if (widget.acquire != null && _canRetry)
              RaftTextButton(
                key: const ValueKey('lightbox-retry'),
                label: raftText(context, 'Retry'),
                glyph: RaftGlyph.refreshCw,
                onPressed: retry,
              ),
          ],
        ),
      );
    }
    _watchDecodedSize();
    return stage(context, thumbnail);
  }

  final _decodedWatch = _BitmapSizeWatch();
  final _placeholderWatch = _BitmapSizeWatch();

  /// The decoded original's pixel size (null until it is decoded).
  Size? get decoded => _decodedWatch.size;

  /// The pixel size of the thumbnail standing in: the card's own bitmap, known
  /// on the first build when the card shows it.
  Size? get placeholderSize => _placeholderWatch.size;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _watchPlaceholderSize();
    _watchDecodedSize();
  }

  @override
  void didUpdateWidget(AttachmentLightboxImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _watchPlaceholderSize();
    _watchDecodedSize();
  }

  void _resized() {
    if (!mounted) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      // Learnt while building: rebuild after the frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  void _watchDecodedSize() => _decodedWatch.watch(
    full,
    createLocalImageConfiguration(context),
    _resized,
  );

  void _watchPlaceholderSize() => _placeholderWatch.watch(
    widget.placeholder,
    createLocalImageConfiguration(context),
    _resized,
  );

  void _unwatchDecodedSize() {
    _decodedWatch.dispose();
    _placeholderWatch.dispose();
  }
}

/// The pixel size of an image provider's bitmap once it resolves: synchronously
/// when the bitmap is already in the image cache (the card's thumbnail is), so
/// the first build can use it.
class _BitmapSizeWatch {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  Size? size;

  /// The bitmap decoded, or failed to: the provider can be shown (or its
  /// error).
  bool get settled => size != null || failed;
  bool failed = false;

  /// Follows [provider] (null stops); [changed] runs when the size is
  /// learnt after the call that started watching.
  void watch(
    ImageProvider? provider,
    ImageConfiguration configuration,
    VoidCallback changed,
  ) {
    if (provider == null) {
      dispose();
      size = null;
      failed = false;
      return;
    }
    final stream = provider.resolve(configuration);
    if (_stream?.key == stream.key) return;
    dispose();
    failed = false;
    size = null;
    final listener = ImageStreamListener(
      (info, synchronous) {
        final image = info.image;
        final next = Size(image.width.toDouble(), image.height.toDouble());
        // The stream hands every listener its own clone; only the size is kept.
        info.dispose();
        if (size == next) return;
        size = next;
        // A synchronous call happens while building; the build reads it next.
        if (!synchronous) changed();
      },
      onError: (Object _, StackTrace? _) {
        failed = true;
        changed();
      },
    );
    stream.addListener(listener);
    _stream = stream;
    _listener = listener;
  }

  void dispose() {
    final listener = _listener;
    if (listener != null) _stream?.removeListener(listener);
    _stream = null;
    _listener = null;
  }
}
