import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_client/raft_client.dart';

import '../data/workspace_controller.dart';
import '../data/attachment_image_repository.dart';
import '../platform/attachment_files.dart';
import '../platform/native_sharing.dart';
import 'attachment_preview_dialog.dart';
import 'attachment_html_preview.dart';
import 'private_route_guard.dart';

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
  });
  final WorkspaceController controller;
  final Map<String, dynamic> metadata;
  final AttachmentFiles? files;
  final String? messageId;
  final bool exportMode;
  final VoidCallback? onExportReady;
  final Size? imageExtent;
  final BoxFit imageFit;
  @override
  State<AttachmentView> createState() => _AttachmentViewState();
}

class _AttachmentViewState extends State<AttachmentView> {
  late AttachmentFiles files;
  int bindingRevision = 0;
  late String metadataFingerprint;
  final sharing = NativeSharing();
  SharedFileLease? sharedLease;
  CancelToken imageCancel = CancelToken(), downloadCancel = CancelToken();
  Uint8List? image;
  MemoryImage? imageProvider;
  final imagePresentation = ValueNotifier<int>(0);
  WorkspaceAttachmentImageLease? imageLease;
  String? error;
  bool loading = false, saving = false, invalidated = false;
  bool exportReadyReported = false, opening = false;
  DialogRoute<void>? previewRoute, progressRoute;
  late int generation;
  Map<String, dynamic>? channelAuthority;
  late String? principal, server, sourceChannel, projectedServer, role;
  WorkspaceController get w => widget.controller;
  String get name => '${widget.metadata['filename'] ?? 'Attachment'}';
  String get mime =>
      '${widget.metadata['mimeType'] ?? 'application/octet-stream'}';
  bool get isImage {
    final type = mime.toLowerCase().split(';').first.trim();
    // Original Web only presents SVG inline when a raster projection exists.
    // Native never feeds authored SVG bytes to the raster decoder.
    return type.startsWith('image/') && type != 'image/svg+xml';
  }

  bool get visibleExportDescendant =>
      widget.exportMode &&
      w.messages.any((parent) {
        final thread = parent.threadId;
        return thread != null &&
            w.ledger.messages(thread).any((m) => m['id'] == widget.messageId);
      });
  bool get authorized =>
      mounted &&
      !invalidated &&
      generation == w.client.generation &&
      principal == w.client.user?.id &&
      server == w.client.serverId &&
      sourceChannel == w.channel?.id &&
      !channelAuthorityReduced(channelAuthority, w.channel?.json) &&
      projectedServer == w.server?.id &&
      role == w.server?.string('role') &&
      (widget.messageId == null ||
          w.presentsMessage(widget.messageId) ||
          w.presentsReply(widget.messageId) ||
          w.threadParent?.id == widget.messageId ||
          visibleExportDescendant);

  @override
  void initState() {
    super.initState();
    files = widget.files ?? AttachmentFiles();
    metadataFingerprint = fingerprint();
    captureAuthority();
    w.addListener(scopeChanged);
    beginImage();
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

  void beginImage() {
    if (isImage &&
        (widget.metadata['sizeBytes'] as num? ?? 0) <= 50 * 1024 * 1024) {
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
    downloadCancel.cancel();
    imageLease?.release();
    imageLease = null;
    if (sharedLease != null) unawaited(sharedLease!.dispose());
    sharedLease = null;
    for (final route in [previewRoute, progressRoute]) {
      if (route?.isActive == true) route!.navigator?.removeRoute(route);
    }
    previewRoute = progressRoute = null;
    imageCancel = CancelToken();
    downloadCancel = CancelToken();
    files = widget.files ?? files;
    metadataFingerprint = nextFingerprint;
    image = null;
    imageProvider = null;
    error = null;
    loading = saving = opening = invalidated = exportReadyReported = false;
    captureAuthority();
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
      if (sharedLease != null) unawaited(sharedLease!.dispose());
      sharedLease = null;
      imageCancel.cancel();
      downloadCancel.cancel();
      for (final route in [previewRoute, progressRoute]) {
        if (route?.isActive == true) route!.navigator?.removeRoute(route);
      }
      imageLease?.release();
      imageLease = null;
      if (image != null && mounted) {
        setState(() {
          image = null;
          imageProvider = null;
        });
      }
    }
  }

  @override
  void dispose() {
    ++bindingRevision;
    w.removeListener(scopeChanged);
    if (sharedLease != null) unawaited(sharedLease!.dispose());
    sharedLease = null;
    imageCancel.cancel();
    downloadCancel.cancel();
    imageLease?.release();
    imageLease = null;
    for (final route in [previewRoute, progressRoute]) {
      if (route?.isActive == true) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (route!.isActive) route.navigator?.removeRoute(route);
        });
      }
    }
    image = null;
    imageProvider = null;
    imagePresentation.dispose();
    super.dispose();
  }

  Future<String> resolve(String disposition) async {
    final data = await w.query(
      '/attachments/${widget.metadata['id']}/url',
      query: {'disposition': disposition},
    );
    return data['url'] as String;
  }

  Future<void> loadImage() async {
    if (!authorized || loading) return;
    final revision = bindingRevision, controller = w;
    final metadata = Map<String, dynamic>.from(widget.metadata);
    final transfer = files;
    bool current() => revision == bindingRevision && authorized;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      imageLease?.release();
      final ownerChannel =
          '${widget.metadata['channelId'] ?? (w.presentsReply(widget.messageId) ? w.threadChannelId : w.channel?.id) ?? ''}';
      final key = AttachmentImageKey.fromMetadata(
        scope: w.attachmentImageScope,
        channelId: ownerChannel,
        metadata: widget.metadata,
      );
      final lease = w.acquireAttachmentImage(
        key,
        authorized: current,
        load: (cancel) async {
          final value = await controller.query(
            '/attachments/${metadata['id']}/url',
            query: {'disposition': 'inline'},
          );
          final url = value['url'] as String;
          if (cancel.isCancelled) throw const StaleAttachmentImage();
          return transfer.image(url, cancel: cancel);
        },
      );
      imageLease = lease;
      final provider = await lease.lease.ready;
      if (current() && identical(imageLease, lease)) {
        setState(() {
          image = provider.bytes;
          imageProvider = provider;
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
      if (revision == bindingRevision && (image != null || error != null)) {
        exportReady();
      }
    }
  }

  Future<void> shareAttachment() async {
    final revision = bindingRevision;
    bool current() => revision == bindingRevision && authorized;
    if (!current() || saving || !sharing.supported) return;
    setState(() => saving = true);
    final operationCancel = CancelToken();
    downloadCancel = operationCancel;
    try {
      final url = await resolve('attachment');
      if (!current()) return;
      if (sharedLease != null) await sharedLease!.dispose();
      final prepared = await sharing.prepareAttachment(
        url: url,
        filename: name,
        cancel: operationCancel,
        authorized: current,
        onProgress: (_, _) {
          if (!current()) operationCancel.cancel();
        },
      );
      if (prepared == null) return;
      if (!current()) {
        await prepared.dispose();
        return;
      }
      sharedLease = prepared;
      await sharing.shareFile(prepared, mime);
    } catch (_) {
      if (mounted && current() && !operationCancel.isCancelled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              raftText(context, 'The attachment could not be shared.'),
            ),
          ),
        );
      }
    } finally {
      if (mounted && revision == bindingRevision) {
        setState(() => saving = false);
      }
    }
  }

  Future<void> download() async {
    final revision = bindingRevision;
    bool current() => revision == bindingRevision && authorized;
    if (!current() || saving) return;
    setState(() => saving = true);
    final operationCancel = CancelToken();
    downloadCancel = operationCancel;
    final progress = ValueNotifier<double?>(null);
    var dialogVisible = true;
    var progressOpened = false;
    DialogRoute<void>? operationRoute;
    // Use the platform save picker first; show progress only after it closes.
    try {
      final url = await resolve('attachment');
      if (!current()) return;
      final saved = await files.save(
        url: url,
        filename: name,
        mimeType: mime,
        cancel: operationCancel,
        authorized: current,
        onProgress: (received, total) {
          if (!current()) {
            operationCancel.cancel();
            return;
          }
          if (!progressOpened) {
            progressOpened = true;
            operationRoute = DialogRoute<void>(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                title: Text('Downloading $name'),
                content: ValueListenableBuilder<double?>(
                  valueListenable: progress,
                  builder: (_, value, _) =>
                      LinearProgressIndicator(value: value),
                ),
                actions: [
                  TextButton(
                    onPressed: operationCancel.cancel,
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            );
            progressRoute = operationRoute;
            Navigator.of(
              context,
              rootNavigator: true,
            ).push(operationRoute!).whenComplete(() => dialogVisible = false);
          }
          progress.value = total > 0 ? received / total : null;
        },
      );
      if (progressOpened && mounted && dialogVisible) {
        operationRoute?.navigator?.removeRoute(operationRoute!);
        dialogVisible = false;
      }
      if (saved != null && mounted && current()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved $name'),
            action: SnackBarAction(
              label: 'Open',
              onPressed: () async {
                try {
                  await files.open(saved, mime);
                } catch (_) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No application can open this file.'),
                      ),
                    );
                  }
                }
              },
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted && current() && !operationCancel.isCancelled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Download failed. Try again.')),
        );
      }
    } finally {
      if (revision == bindingRevision) saving = false;
      if (progressOpened && operationRoute?.isActive == true) {
        operationRoute!.navigator?.removeRoute(operationRoute!);
      }
      if (identical(progressRoute, operationRoute)) progressRoute = null;
      // The dialog builder may still be mounted for its closing animation.
      Future<void>.delayed(const Duration(seconds: 1), progress.dispose);
    }
  }

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

  Future<void> openCurrent() async {
    final revision = bindingRevision;
    bool current() => revision == bindingRevision && authorized;
    final html =
        '${widget.metadata['mimeType'] ?? ''}'
                .toLowerCase()
                .split(';')
                .first
                .trim() ==
            'text/html' ||
        RegExp(r'\.html?$', caseSensitive: false).hasMatch(name);
    if (!isImage && (attachmentPreviewKind(widget.metadata) != null || html)) {
      var enabled = true;
      try {
        final gate = await w.query('/messages/attachment-preview/enabled');
        if (!current()) return;
        enabled = gate is Map && gate['enabled'] == true;
      } on RaftApiException catch (error) {
        if (!current() || [401, 403].contains(error.status)) return;
      } catch (_) {
        if (!current()) return;
      }
      if (!enabled) {
        await download();
        return;
      }
      if (!mounted || !current()) return;
      late final DialogRoute<void> operationRoute;
      operationRoute = DialogRoute<void>(
        context: context,
        builder: (dialogContext) => html
            ? HtmlAttachmentPreviewDialog(
                controller: w,
                metadata: widget.metadata,
                authorized: current,
                onClose: () {
                  if (dialogContext.mounted &&
                      identical(previewRoute, operationRoute) &&
                      operationRoute.isCurrent) {
                    operationRoute.navigator?.pop();
                  }
                },
                onDownload: download,
              )
            : AttachmentPreviewDialog(
                controller: w,
                metadata: widget.metadata,
                authorized: current,
                onClose: () {
                  if (dialogContext.mounted &&
                      identical(previewRoute, operationRoute) &&
                      operationRoute.isCurrent) {
                    operationRoute.navigator?.pop();
                  }
                },
                onDownload: download,
              ),
      );
      previewRoute = operationRoute;
      await Navigator.of(context, rootNavigator: true).push(operationRoute);
      if (identical(previewRoute, operationRoute)) previewRoute = null;
      return;
    }
    if (!isImage) {
      await download();
      return;
    }
    if (!mounted || !current()) return;
    // Source opens the image lightbox at intent, independently of thumbnail
    // readiness. A pending thumbnail load must not consume the user's click.
    if (image == null && !loading) unawaited(loadImage());
    late final DialogRoute<void> operationRoute;
    operationRoute = DialogRoute<void>(
      context: context,
      builder: (dialogContext) => RaftAttachmentLightbox(
        title: name,
        titleBold: true,
        onClose: () {
          if (identical(previewRoute, operationRoute) &&
              operationRoute.isActive) {
            operationRoute.navigator?.removeRoute(operationRoute);
          }
        },
        footer: RaftTextButton(
          label: 'Download original',
          glyph: RaftGlyph.download,
          onPressed: current() ? download : null,
          variant: RaftControlVariant.ghost,
        ),
        child: ValueListenableBuilder<int>(
          valueListenable: imagePresentation,
          builder: (_, _, _) {
            if (!current()) return const SizedBox.shrink();
            return Center(
              child: imageProvider == null
                  ? error == null
                        ? const RaftSpinner(inverse: true)
                        : const Text(
                            'Preview unavailable. Download the original file.',
                          )
                  : InteractiveViewer(
                      child: Image(
                        image: imageProvider!,
                        key: ValueKey(
                          'attachment-image-${widget.metadata['id']}',
                        ),
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Text(
                          'Preview unavailable. Download the original file.',
                        ),
                      ),
                    ),
            );
          },
        ),
      ),
    );
    previewRoute = operationRoute;
    await Navigator.of(context, rootNavigator: true).push(operationRoute);
    if (identical(previewRoute, operationRoute)) previewRoute = null;
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

  @override
  Widget build(BuildContext context) => RaftAttachmentCard(
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
    busy: loading || saving,
    error: error,
    onRetry: loadImage,
    onOpen: open,
    onDownload: download,
    onShare: sharing.supported ? shareAttachment : null,
    onCancel: saving ? downloadCancel.cancel : null,
    preview: image == null
        ? null
        : Image(
            image: imageProvider!,
            fit: widget.imageFit,
            errorBuilder: (_, _, _) => const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Preview unavailable. Download the original file.'),
            ),
          ),
  );
}
