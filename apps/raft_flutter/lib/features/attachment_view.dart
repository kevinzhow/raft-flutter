import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'layout_hold.dart';

import 'package:raft_ui/raft_ui.dart';

import '../data/raft_location.dart';
import '../data/workspace_controller.dart';
import '../data/attachment_image_repository.dart';
import '../platform/attachment_files.dart';
import '../platform/native_sharing.dart';
import '../platform/video_frame_probe.dart';
import 'attachment_preview_dialog.dart';
import 'attachment_html_preview.dart';
import 'attachment_image_loader.dart';
import 'attachment_transfers.dart';
import 'attachment_preview_gate.dart';
import 'attachment_shape.dart';
import 'inline_attachment_media.dart';
import 'media_browser.dart';
import 'media_items.dart';
import 'mobile_route_gate.dart';
import 'private_route_guard.dart';

bool _isSvgMime(String mime) =>
    mime.toLowerCase().split(';').first.trim() == 'image/svg+xml';

/// Web isPreviewableImageAttachment (urlImageFallback.ts): any `image/*`, but
/// an SVG only when the server rasterized it (`thumbnailUrl`, a 320px WebP).
/// Native never feeds authored SVG bytes to the raster decoder.
bool attachmentIsInlineImage(Map<String, dynamic> metadata) {
  final mime = '${metadata['mimeType'] ?? 'application/octet-stream'}';
  final type = mime.toLowerCase().split(';').first.trim();
  if (!type.startsWith('image/')) return false;
  if (!_isSvgMime(type)) return true;
  final thumbnail = metadata['thumbnailUrl'];
  return thumbnail is String &&
      (thumbnail.startsWith('https://') || thumbnail.startsWith('http://'));
}

/// The dialog of a picker download in progress (moved unchanged from the
/// download flow); the file is complete only when the save finishes.
DialogRoute<void> attachmentDownloadProgressRoute({
  required BuildContext context,
  required String name,
  required ValueListenable<double?> progress,
  required VoidCallback onCancel,
}) => DialogRoute<void>(
  context: context,
  barrierDismissible: false,
  builder: (context) => AlertDialog(
    title: Text('Downloading $name'),
    content: ValueListenableBuilder<double?>(
      valueListenable: progress,
      builder: (_, value, _) => LinearProgressIndicator(value: value),
    ),
    actions: [TextButton(onPressed: onCancel, child: const Text('Cancel'))],
  ),
);

class AttachmentView extends StatefulWidget {
  const AttachmentView({
    super.key,
    required this.controller,
    required this.metadata,
    this.files,
    this.messageId,
    this.exportMode = false,
    this.onExportReady,
    this.imageExtent,
    this.imageFit = BoxFit.contain,
    this.galleryItems,
    this.sharing,
    this.mediaMessage,
    this.frameProbe,
  });
  final WorkspaceController controller;
  final Map<String, dynamic> metadata;
  final AttachmentFiles? files;
  final String? messageId;
  final bool exportMode;
  final VoidCallback? onExportReady;
  final Size? imageExtent;
  final BoxFit imageFit;

  /// The message's previewable images (Web `lightboxImages`): the viewer
  /// pages through them. Null for an attachment shown on its own.
  final List<Map<String, dynamic>>? galleryItems;

  /// The platform share / photo-library bridge (tests inject one).
  final NativeSharing? sharing;

  /// Who sent the message, when and what it says, read when the viewer opens
  /// (the browser's `sender · time` sub-line and phone caption).
  final MediaMessageInfo Function()? mediaMessage;

  /// Reads the first frame of a video without a server thumbnail (the
  /// platform's by default; tests inject one).
  final VideoFrameProbe? frameProbe;
  @override
  State<AttachmentView> createState() => _AttachmentViewState();
}

class _AttachmentViewState extends State<AttachmentView> {
  late AttachmentFiles files;
  int bindingRevision = 0;
  late String metadataFingerprint;
  late final NativeSharing sharing = widget.sharing ?? NativeSharing();
  CancelToken imageCancel = CancelToken();
  late AttachmentTransfers transfers;

  /// The list preview: thumbnail or original decoded at the reserved box.
  ImageProvider? imageProvider;
  final imagePresentation = ValueNotifier<int>(0);
  WorkspaceAttachmentImageLease? imageLease;

  // ignore: raft_lints/avoid_imperative_notice_state -- Image load error: cleared when an image load starts, on a ready image adoption and on rebind.
  String? error;
  bool loading = false, invalidated = false;
  bool get saving => transfers.saving;

  /// The last explicit download failed; the file card offers a retry.
  bool get downloadFailed => transfers.downloadFailed;

  /// A cold network load fades in once; cached images appear directly.
  bool fadeIn = false;
  bool begun = false;

  /// The picture wears the card-to-stage Hero while the media browser it
  /// opened is on screen (a Hero only for the tapped card: the same message
  /// can appear twice in a route, e.g. in a thread's parent).
  bool heroActive = false;

  /// The poster of this attachment's video poster card, for the viewer
  /// that opens from it.
  final videoPoster = ValueNotifier<ImageProvider?>(null);
  double devicePixelRatio = 1;
  bool exportReadyReported = false, opening = false;
  ModalRoute<void>? previewRoute;
  late int generation;
  Map<String, dynamic>? channelAuthority;
  late String? principal, server, sourceChannel, projectedServer, role;
  WorkspaceController get w => widget.controller;
  String get name => '${widget.metadata['filename'] ?? 'Attachment'}';
  String get mime =>
      '${widget.metadata['mimeType'] ?? 'application/octet-stream'}';
  bool get isImage => attachmentIsInlineImage(widget.metadata);
  bool get isSvg => _isSvgMime(mime);

  bool get visibleExportDescendant =>
      widget.exportMode &&
      w.messageDomain.messages.any((parent) {
        final thread = parent.threadId;
        return thread != null &&
            w.messageDomain.ledger
                .messages(thread)
                .any((m) => m['id'] == widget.messageId);
      });
  bool get authorized =>
      mounted &&
      !invalidated &&
      generation == w.client.generation &&
      principal == w.client.user?.id &&
      server == w.client.serverId &&
      projectedServer == w.server?.id &&
      role == w.server?.string('role') &&
      (pageIsCovered || presentsConversation);

  /// A phone page that is covered, or popped and animating out, is not the
  /// page the workspace is on. The workspace's conversation (channel, thread,
  /// presented rows) already belongs to the next page: closing a thread
  /// clears it at the first frame of the back. Judging this row against it
  /// dropped the image of the page still sliding away. Account, server and
  /// role are still checked, and the row is judged again against the
  /// workspace the moment its page is current.
  bool get pageIsCovered => coveredReader();

  /// The workspace is on this row's conversation and still presents it.
  bool get presentsConversation =>
      sourceChannel == w.channel?.id &&
      !channelAuthorityReduced(channelAuthority, w.channel?.json) &&
      (widget.messageId == null ||
          w.messageDomain.presentsMessage(widget.messageId) ||
          w.messageDomain.presentsReply(widget.messageId) ||
          w.messageDomain.state.threadParent?.id == widget.messageId ||
          visibleExportDescendant);

  @override
  void initState() {
    super.initState();
    files = widget.files ?? AttachmentFiles();
    metadataFingerprint = fingerprint();
    captureAuthority();
    transfers = newTransfers();
    w.addListener(scopeChanged);
    if (isImage && attachmentDeclaredShape(widget.metadata) == null) {
      // No size in the message: the one learnt before (this session or on
      // disk) gives the card its box in the first frames; else it is learnt
      // from the preview's decode.
      w.attachmentMedia.playerSessions.shapeChanges.addListener(shapeLearnt);
      unawaited(
        readStoredShape(
          w,
          widget.metadata,
          kind: 'image-shape',
          channelId: ownerChannel,
          authorized: () => authorized,
        ),
      );
    }
  }

  /// A shape was learnt somewhere: a card without a message size re-lays out.
  void shapeLearnt() {
    if (mounted) setState(() {});
  }

  /// Learns the picture's shape from the preview just decoded (no extra
  /// download), for a message that did not carry one.
  void learnImageShape(AttachmentImageLease lease) {
    if (attachmentDeclaredShape(widget.metadata) != null) return;
    final decoded = lease.decoded;
    if (decoded == null || decoded.width <= 0 || decoded.height <= 0) return;
    final shape = VideoShape(width: decoded.width, height: decoded.height);
    // After this frame: the rows listening must not rebuild during a build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      learnShape(
        w,
        widget.metadata,
        shape,
        kind: 'image-shape',
        channelId: ownerChannel,
      );
    });
  }

  /// Save / share of this attachment; one operation's authority is the
  /// binding revision it started under.
  AttachmentTransfers newTransfers() => AttachmentTransfers(
    controller: w,
    files: files,
    sharing: sharing,
    metadata: widget.metadata,
    ownerChannel: ownerChannel,
    isImage: isImage,
    progressRoute: attachmentDownloadProgressRoute,
    context: () => mounted ? context : null,
    scope: () {
      final revision = bindingRevision;
      return (
        alive: () => mounted && revision == bindingRevision,
        current: () => revision == bindingRevision && authorized,
      );
    },
    onChanged: () {
      if (mounted) setState(() {});
    },
  );

  /// Whether this row's phone page is covered or leaving (see [pageIsCovered]).
  bool Function() coveredReader = () => false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    coveredReader = MobileRouteGate.coveredReader(context);
    devicePixelRatio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    tickerEnabled = TickerMode.valuesOf(context).enabled;
    if (begun) {
      retentionChanged();
      return;
    }
    begun = true;
    beginImage();
  }

  /// A row on a covered route, an offstage tab or a folded panel (TickerMode
  /// is off there) keeps no decoded bitmap after [hiddenImageDelay]: it lets
  /// go of its lease and its image stream. The repository keeps the decoded
  /// image for a quick return (first-frame paint) until its idle sweep or a
  /// memory trim, and a returning row adopts it synchronously.
  ///
  /// Rows that are on screen when the app goes to the background keep theirs:
  /// no frames run while the app is hidden, so a released row could not drop
  /// its bitmap, and would only blink on return.
  static const hiddenImageDelay = Duration(seconds: 5);
  bool tickerEnabled = true;

  /// The preview was released for memory and must be adopted again.
  bool memoryReleased = false;
  Timer? hiddenTimer;

  void retentionChanged() {
    if (!mounted || widget.exportMode) return;
    if (tickerEnabled) {
      hiddenTimer?.cancel();
      hiddenTimer = null;
      if (memoryReleased) {
        memoryReleased = false;
        beginImage();
      }
      return;
    }
    if (memoryReleased || imageLease == null || imageProvider == null) return;
    hiddenTimer ??= Timer(hiddenImageDelay, () {
      hiddenTimer = null;
      if (!tickerEnabled) releaseImageForMemory();
    });
  }

  void releaseImageForMemory() {
    final lease = imageLease;
    // An open lightbox shows this preview as its stand-in, and a load in
    // flight owns the lease; both call back here when they finish.
    if (!mounted ||
        lease == null ||
        imageProvider == null ||
        loading ||
        previewRoute != null) {
      return;
    }
    memoryReleased = true;
    imageLease = null;
    lease.release();
    setState(() => imageProvider = null);
  }

  String fingerprint({bool withMessage = true}) => jsonEncode([
    withMessage ? widget.messageId : null,
    widget.exportMode,
    for (final key in [
      'id',
      'channelId',
      'mimeType',
      'sizeBytes',
      'width',
      'height',
      'contentVersion',
      'contentHash',
      'updatedAt',
    ])
      widget.metadata[key],
  ]);

  void captureAuthority() {
    generation = w.client.generation;
    principal = w.client.user?.id;
    server = w.client.serverId;
    sourceChannel = w.channel?.id;
    channelAuthority = w.channel == null
        ? null
        : {
            ...w.channel!.json,
            if (w.channel!.json['channelCapabilities'] is Map)
              'channelCapabilities': {
                ...(w.channel!.json['channelCapabilities'] as Map),
              },
          };
    projectedServer = w.server?.id;
    role = w.server?.string('role');
  }

  /// Server-generated 320px WebP (Web's inline `thumbnailUrl` source).
  String? get thumbnailUrl {
    final value = widget.metadata['thumbnailUrl'];
    return value is String &&
            (value.startsWith('https://') || value.startsWith('http://'))
        ? value
        : null;
  }

  /// Logical box the list preview is displayed in: the gallery's extent, or
  /// the single-image reservation (Web reserveSingleImage) at its largest.
  Size get previewBox {
    final extent = widget.imageExtent;
    if (extent != null && extent.width > 0 && extent.height > 0) return extent;
    final shape = attachmentShape(w, widget.metadata);
    final width = shape?.width.toDouble();
    final height = shape?.height.toDouble();
    const maxWidth = AttachmentPrimitive.singleImageMaxWidth,
        maxHeight = AttachmentPrimitive.singleImageMaxHeight;
    if (width == null ||
        height == null ||
        !(width > 0 && height > 0 && width.isFinite && height.isFinite)) {
      return const Size(maxWidth, maxHeight);
    }
    final scale = math.min(1.0, math.min(maxWidth / width, maxHeight / height));
    return Size(width * scale, height * scale);
  }

  String get ownerChannel =>
      '${widget.metadata['channelId'] ?? (w.messageDomain.presentsReply(widget.messageId) ? w.threadChannelId : w.channel?.id) ?? ''}';

  AttachmentImageKey keyFor({required bool preview}) {
    final box = previewBox;
    return AttachmentImageKey.fromMetadata(
      scope: w.attachmentImageScope,
      channelId: ownerChannel,
      metadata: widget.metadata,
      // An SVG's bytes are never decoded: its raster thumbnail serves the
      // list preview and the lightbox alike.
      rendition: (preview || isSvg) && thumbnailUrl != null
          ? 'thumbnail'
          : 'original',
      target: preview
          ? AttachmentDecodeTarget.box(
              box.width,
              box.height,
              devicePixelRatio: devicePixelRatio,
              cover: widget.imageFit == BoxFit.cover,
            )
          : null,
    );
  }

  /// List rows never decode the full original; only the lightbox does.
  AttachmentImageKey get imageKey => keyFor(preview: true);
  AttachmentImageKey get fullImageKey => keyFor(preview: false);

  /// Fetches the key's source bytes. Capability URLs live only in this call.
  AttachmentImageLoader loaderFor(AttachmentImageKey key) =>
      attachmentImageLoader(
        controller: w,
        files: files,
        metadata: widget.metadata,
        key: key,
      );

  /// A decoded image the controller still retains (channel revisit, row
  /// recycling) is adopted in the first frame; no loading state, no bytes GET.
  bool adoptReadyImage() {
    if (!authorized) return false;
    final WorkspaceAttachmentImageLease? lease;
    try {
      lease = w.attachmentMedia.peekImage(
        imageKey,
        authorized: () => authorized,
      );
    } catch (_) {
      return false;
    }
    final provider = lease?.lease.value;
    if (lease == null) return false;
    if (provider == null) {
      lease.release();
      return false;
    }
    imageLease?.release();
    imageLease = lease;
    imageProvider = provider;
    error = null;
    learnImageShape(lease.lease);
    return true;
  }

  void beginImage() {
    if (isImage &&
        (widget.metadata['sizeBytes'] as num? ?? 0) <= 50 * 1024 * 1024) {
      if (adoptReadyImage()) {
        imagePresentation.value++;
        exportReady();
        return;
      }
      loadImage();
    } else {
      exportReady();
    }
  }

  @override
  void didUpdateWidget(AttachmentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextFingerprint = fingerprint();
    if (oldWidget.controller == w &&
        oldWidget.files == widget.files &&
        nextFingerprint == metadataFingerprint) {
      return;
    }
    // An optimistic row's attachment (no message yet) adopting the accepted
    // message keeps the loaded preview; authority is still read per use.
    if (oldWidget.controller == w &&
        oldWidget.files == widget.files &&
        oldWidget.messageId == null &&
        widget.messageId != null &&
        oldWidget.exportMode == widget.exportMode &&
        fingerprint(withMessage: false) == metadataFingerprint) {
      metadataFingerprint = nextFingerprint;
      return;
    }
    oldWidget.controller.removeListener(scopeChanged);
    ++bindingRevision;
    imageCancel.cancel();
    transfers.abort();
    imageLease?.release();
    imageLease = null;
    if (previewRoute?.isActive == true) {
      previewRoute!.navigator?.removeRoute(previewRoute!);
    }
    previewRoute = null;
    imageCancel = CancelToken();
    files = widget.files ?? files;
    metadataFingerprint = nextFingerprint;
    imageProvider = null;
    error = null;
    memoryReleased = false;
    hiddenTimer?.cancel();
    hiddenTimer = null;
    loading = opening = invalidated = exportReadyReported = false;
    fadeIn = false;
    captureAuthority();
    transfers = newTransfers();
    w.addListener(scopeChanged);
    beginImage();
  }

  void exportReady() {
    if (!widget.exportMode || exportReadyReported) return;
    final revision = bindingRevision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (revision != bindingRevision || !authorized || exportReadyReported) {
        return;
      }
      exportReadyReported = true;
      widget.onExportReady?.call();
    });
  }

  void scopeChanged() {
    if (!authorized) {
      invalidated = true;
      imageCancel.cancel();
      transfers.abort();
      if (previewRoute?.isActive == true) {
        previewRoute!.navigator?.removeRoute(previewRoute!);
      }
      imageLease?.release();
      imageLease = null;
      if (imageProvider != null && mounted) {
        setState(() => imageProvider = null);
      }
    }
  }

  @override
  void dispose() {
    ++bindingRevision;
    hiddenTimer?.cancel();
    hiddenTimer = null;
    w.removeListener(scopeChanged);
    w.attachmentMedia.playerSessions.shapeChanges.removeListener(shapeLearnt);
    imageCancel.cancel();
    transfers.abort();
    imageLease?.release();
    imageLease = null;
    for (final route in [previewRoute]) {
      if (route?.isActive == true) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (route!.isActive) route.navigator?.removeRoute(route);
        });
      }
    }
    imageProvider = null;
    imagePresentation.dispose();
    videoPoster.dispose();
    super.dispose();
  }

  Future<void> loadImage() async {
    if (!authorized || loading) return;
    final revision = bindingRevision;
    bool current() => revision == bindingRevision && authorized;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      imageLease?.release();
      final key = imageKey;
      final lease = w.attachmentMedia.acquireImage(
        key,
        authorized: current,
        load: loaderFor(key),
        bestAvailable: true,
      );
      imageLease = lease;
      final provider = await lease.lease.ready;
      if (current() && identical(imageLease, lease)) {
        learnImageShape(lease.lease);
        setState(() {
          imageProvider = provider;
          fadeIn = !widget.exportMode && !lease.lease.fromStore;
        });
      }
    } catch (_) {
      if (current() && !imageCancel.isCancelled) {
        setState(() => error = 'The image could not be loaded.');
      }
    } finally {
      if (mounted && revision == bindingRevision) {
        setState(() => loading = false);
        imagePresentation.value++;
      }
      if (revision == bindingRevision &&
          (imageProvider != null || error != null)) {
        exportReady();
      }
      if (mounted && revision == bindingRevision) retentionChanged();
    }
  }

  Future<void> shareAttachment() => transfers.share();

  Future<void> download() => transfers.download();

  Future<void> open() async {
    if (!authorized || opening || previewRoute?.isActive == true) return;
    final revision = bindingRevision;
    opening = true;
    try {
      await openCurrent();
    } finally {
      if (revision == bindingRevision) opening = false;
    }
  }

  ModalRoute<void> createPreviewRoute(bool page, WidgetBuilder builder) =>
      _heldRoute(_previewRoute(page, builder));

  /// The media browser's route: transparent, the picture flies in from the
  /// card; the phone shell [staged] stages the scrim and chrome around the
  /// flight itself; reduced motion cross-fades in 80 ms.
  ModalRoute<void> createMediaRoute(
    WidgetBuilder builder, {
    bool staged = false,
  }) => _heldRoute(
    RaftMediaBrowserRoute<void>(
      settings: const RouteSettings(name: '/attachment-preview'),
      reducedMotion: MediaQuery.disableAnimationsOf(context),
      staged: staged,
      builder: builder,
    ),
  );

  ModalRoute<void> _heldRoute(ModalRoute<void> route) {
    LayoutHold.hold(route);
    return route;
  }

  ModalRoute<void> _previewRoute(bool page, WidgetBuilder builder) =>
      attachmentPreviewRoute(context, page, builder);

  Future<void> openCurrent() async {
    final revision = bindingRevision;
    bool current() => revision == bindingRevision && authorized;
    final page = RaftAdaptiveWorkspace.compactOf(context);
    final html =
        '${widget.metadata['mimeType'] ?? ''}'
                .toLowerCase()
                .split(';')
                .first
                .trim() ==
            'text/html' ||
        RegExp(r'\.html?$', caseSensitive: false).hasMatch(name);
    if (!isImage && (attachmentPreviewKind(widget.metadata) != null || html)) {
      // The gate is a server setting: a value this device has seen opens the
      // preview at once (re-read behind it); only a gate never seen is read
      // while the preview is already on screen.
      final known = knownAttachmentPreviewGate(w);
      final gate = readAttachmentPreviewGate(w);
      if (known == false) {
        final decided = await gate;
        if (!current() || decided == AttachmentPreviewGate.unauthorized) {
          return;
        }
        if (decided == AttachmentPreviewGate.disabled) {
          await download();
          return;
        }
      }
      if (!mounted || !current()) return;
      if (attachmentPreviewKind(widget.metadata) == 'video') {
        await openBrowser(page: page, current: current);
        return;
      }
      late final ModalRoute<void> operationRoute;
      operationRoute = createPreviewRoute(page, (dialogContext) {
        void close() {
          if (dialogContext.mounted &&
              identical(previewRoute, operationRoute) &&
              operationRoute.isCurrent) {
            operationRoute.navigator?.pop();
          }
        }

        return html
            ? HtmlAttachmentPreviewDialog(
                page: page,
                controller: w,
                metadata: widget.metadata,
                authorized: current,
                onClose: close,
                onDownload: download,
                onShare: sharing.supported ? shareAttachment : null,
              )
            : AttachmentPreviewDialog(
                page: page,
                controller: w,
                metadata: widget.metadata,
                channelId: ownerChannel,
                authorized: current,
                onClose: close,
                onDownload: download,
                onShare: sharing.supported ? shareAttachment : null,
                onNetworkSettings: kIsWeb
                    ? null
                    : () {
                        close();
                        openNetworkSettings();
                      },
              );
      });
      previewRoute = operationRoute;
      if (known == null) {
        unawaited(
          gate.then((decided) {
            if (decided == AttachmentPreviewGate.enabled ||
                !identical(previewRoute, operationRoute) ||
                !operationRoute.isActive) {
              return;
            }
            operationRoute.navigator?.removeRoute(operationRoute);
            if (decided == AttachmentPreviewGate.disabled && current()) {
              unawaited(download());
            }
          }),
        );
      }
      await Navigator.of(context, rootNavigator: true).push(operationRoute);
      if (identical(previewRoute, operationRoute)) previewRoute = null;
      return;
    }
    if (!isImage) {
      await download();
      return;
    }
    if (!mounted || !current()) return;
    await openBrowser(page: page, current: current);
  }

  /// Opens the media browser on this attachment: Web opens the lightbox with
  /// the message's previewable images and the clicked one selected; a lone
  /// image (files panel, forwarded) is its own gallery. With the video flag
  /// the videos of the message are pages too.
  Future<void> openBrowser({
    required bool page,
    required bool Function() current,
  }) async {
    // Source opens the image lightbox at intent, independently of thumbnail
    // readiness. A pending thumbnail load must not consume the user's click.
    if (isImage && imageProvider == null && !loading) unawaited(loadImage());
    final siblings =
        widget.messageId != null && (widget.galleryItems?.length ?? 0) > 1
        ? widget.galleryItems!
        : [widget.metadata];
    final start = siblings.indexWhere((m) => m['id'] == widget.metadata['id']);
    final info = widget.mediaMessage?.call();
    final messageId = widget.messageId;
    final channelId = ownerChannel;
    // The immersive stage (swipe down to dismiss, tap toggles the chrome, long
    // press saves / shares) is how a finger views media, at any window size: a
    // phone held sideways, an unfolded foldable and a tablet all get it. The
    // desktop lightbox (click outside closes, header buttons, strip) is for a
    // pointer, also in a narrow window. [page] only says the window is narrow.
    final phone = RaftInteraction.of(context).touch;
    final hero = !MediaQuery.disableAnimationsOf(context);
    final opener = imageProvider ?? videoPoster.value;
    if (hero && opener != null) setState(() => heroActive = true);
    // A video poster is a Play affordance on every platform.
    final autoplay =
        start >= 0 &&
        siblings[start]['id'] == widget.metadata['id'] &&
        attachmentPreviewKind(widget.metadata) == 'video' &&
        !isImage;
    late final ModalRoute<void> operationRoute;
    void close() {
      if (identical(previewRoute, operationRoute) && operationRoute.isCurrent) {
        // The browser fades out like the preview dialog does; the image
        // stays interactive meanwhile.
        operationRoute.navigator?.pop();
      }
    }

    operationRoute = createMediaRoute(
      staged: phone,
      (dialogContext) => ValueListenableBuilder<int>(
        valueListenable: imagePresentation,
        builder: (_, _, _) {
          if (!current()) return const SizedBox.shrink();
          return MediaBrowser(
            controller: w,
            files: files,
            sharing: sharing,
            items: [
              for (final m in siblings)
                attachmentIsInlineImage(m)
                    ? MediaItem.image(m)
                    : MediaItem.video(m),
            ],
            initialIndex: start < 0 ? 0 : start,
            messageId: messageId,
            message: info,
            authorized: current,
            page: phone,
            openerPlaceholder: opener,
            openerPreviewFailed: error != null,
            autoplay: autoplay,
            progressRoute: attachmentDownloadProgressRoute,
            onNetworkSettings: kIsWeb
                ? null
                : () {
                    close();
                    openNetworkSettings();
                  },
            onShowInMessage: messageId == null
                ? null
                : () {
                    close();
                    unawaited(w.jumpToMessage(channelId, messageId));
                  },
            onClose: close,
          );
        },
      ),
    );
    previewRoute = operationRoute;
    await Navigator.of(context, rootNavigator: true).push(operationRoute);
    // The image remains interactive while its page animates out.
    await operationRoute.completed;
    if (mounted && heroActive) setState(() => heroActive = false);
    if (identical(previewRoute, operationRoute)) previewRoute = null;
    retentionChanged();
  }

  /// The original's pixel size from the attachment metadata, when valid.
  Size? get imageSize {
    final width = (widget.metadata['width'] as num?)?.toDouble();
    final height = (widget.metadata['height'] as num?)?.toDouble();
    return width != null &&
            height != null &&
            width > 0 &&
            height > 0 &&
            width.isFinite &&
            height.isFinite
        ? Size(width, height)
        : null;
  }

  /// Web MessageItem AttachmentChip branches: document previews (summary
  /// "Document preview", mime meta), HTML / video / audio previews, else a
  /// download card with the mime type.
  ({String? summary, String meta, bool preview}) get webChip {
    final kind = attachmentPreviewKind(widget.metadata);
    final type = mime.toLowerCase().split(';').first.trim();
    final html =
        type == 'text/html' ||
        RegExp(r'\.html?$', caseSensitive: false).hasMatch(name);
    final rawMime = widget.metadata['mimeType'] as String?;
    final mimeLabel = rawMime == null || rawMime.isEmpty ? null : rawMime;
    if (kind == 'video') {
      return (
        summary: null,
        meta: raftText(context, 'Video preview'),
        preview: true,
      );
    }
    if (kind == 'audio') {
      return (
        summary: null,
        meta: raftText(context, 'Audio preview'),
        preview: true,
      );
    }
    final lowerName = name.toLowerCase();
    if (lowerName.endsWith('.diff') ||
        lowerName.endsWith('.patch') ||
        const [
          'text/x-diff',
          'text/x-patch',
          'application/x-patch',
        ].contains(type)) {
      // DiffPatchStatsLine: the stats need the fetched preview; until then
      // (and in this client) the summary line reads "Diff preview".
      return (
        summary: raftText(context, 'Diff preview'),
        meta: mimeLabel ?? raftText(context, 'patch'),
        preview: false,
      );
    }
    if (kind != null) {
      return (
        summary: raftText(context, 'Document preview'),
        meta: mimeLabel ?? raftText(context, 'document'),
        preview: true,
      );
    }
    if (html) {
      return (
        summary: null,
        meta: raftText(context, 'HTML preview'),
        preview: true,
      );
    }
    return (
      summary: null,
      meta: mimeLabel ?? raftText(context, 'file'),
      preview: false,
    );
  }

  bool get isHtml =>
      '${widget.metadata['mimeType'] ?? ''}'
              .toLowerCase()
              .split(';')
              .first
              .trim() ==
          'text/html' ||
      RegExp(r'\.html?$', caseSensitive: false).hasMatch(name);

  /// Settings > Network (the failed media card's action when the cause is a
  /// proxy or the connection).
  void openNetworkSettings() {
    if (!authorized) return;
    w.closeThread(navigate: false);
    w.navigation.navigate(
      RaftLocation.at(
        serverSlug: w.location.serverSlug,
        route: RaftRoute.settings,
        settingsPath: const ['network'],
      ),
    );
    w.notifyListeners();
  }

  @override
  Widget build(BuildContext context) {
    return buildAttachment(context);
  }

  Widget buildAttachment(BuildContext context) {
    final kind = attachmentPreviewKind(widget.metadata);
    if (!widget.exportMode && !isImage && kind == 'video') {
      return InlineVideoAttachment(
        key: ValueKey('inline-video-${widget.metadata['id']}'),
        controller: w,
        files: files,
        metadata: widget.metadata,
        channelId: ownerChannel,
        authorized: () => authorized,
        pending: widget.messageId == null,
        onOpenPreview: open,
        frameProbe: widget.frameProbe,
        heroActive: heroActive,
        posterListenable: videoPoster,
      );
    }
    if (!widget.exportMode && !isImage && kind == 'audio') {
      return InlineAudioAttachment(
        key: ValueKey('inline-audio-${widget.metadata['id']}'),
        controller: w,
        metadata: widget.metadata,
        channelId: ownerChannel,
        authorized: () => authorized,
        pending: widget.messageId == null,
        onDownload: download,
        onNetworkSettings: kIsWeb ? null : openNetworkSettings,
      );
    }
    return card(context);
  }

  Widget card(BuildContext context) => RaftAttachmentCard(
    summary: webChip.summary,
    metaLabel: webChip.meta,
    previewAffordance: webChip.preview,
    exportMode: widget.exportMode,
    filename: name,
    mimeType: mime,
    imageExtent: widget.imageExtent,
    imageWidth: (widget.metadata['width'] as num?)?.toDouble(),
    imageHeight: (widget.metadata['height'] as num?)?.toDouble(),
    sizeBytes: (widget.metadata['sizeBytes'] as num?)?.toInt(),
    // Image previews load behind a neutral placeholder box (Web's tinted
    // image box): no spinner and no transfer text in list tiles.
    busy: saving,
    previewPending: loading,
    error: error,
    onRetry: loadImage,
    downloadFailed: downloadFailed,
    onOpen: open,
    onCancel: saving ? transfers.cancel.cancel : null,
    preview: imageProvider == null ? null : previewImage(imageProvider!),
  );

  Widget previewImage(ImageProvider provider) {
    // ignore: raft_lints/avoid_raw_image_decode -- The provider comes from an AttachmentImageRepository lease: already decoded at the target size and shared with the message bubble.
    Widget image({Animation<double>? opacity}) => Image(
      image: provider,
      opacity: opacity,
      fit: widget.imageFit,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => const RaftLoadError(
        'Preview unavailable. Download the original file.',
        expand: false,
      ),
    );
    // The Hero is always mounted and switched on with `heroActive`: the card's
    // picture is not rebuilt (and never re-decoded) for the flight.
    return RaftMediaHero(
      tag: MediaBrowser.heroTagFor('${widget.metadata['id']}'),
      image: provider,
      radius: RaftShapes.attachment(RaftTokens.of(context)),
      fit: widget.imageFit,
      enabled: heroActive,
      child: fadeIn
          ? TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: AttachmentPrimitive.previewFade,
              // Image.opacity blends pixels directly and avoids an offscreen layer.
              builder: (_, opacity, _) =>
                  image(opacity: AlwaysStoppedAnimation(opacity)),
            )
          : image(),
    );
  }
}
