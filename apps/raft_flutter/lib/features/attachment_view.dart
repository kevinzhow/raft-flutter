import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_client/raft_client.dart';

import '../data/workspace_controller.dart';
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
  late final files = widget.files ?? AttachmentFiles();
  final sharing = NativeSharing();
  SharedFileLease? sharedLease;
  CancelToken imageCancel = CancelToken(), downloadCancel = CancelToken();
  Uint8List? image;
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
          w.messages.any((m) => m.id == widget.messageId) ||
          w.replies.any((m) => m.id == widget.messageId) ||
          w.threadParent?.id == widget.messageId ||
          visibleExportDescendant);

  @override
  void initState() {
    super.initState();
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
    w.addListener(scopeChanged);
    if (isImage &&
        (widget.metadata['sizeBytes'] as num? ?? 0) <= 50 * 1024 * 1024) {
      loadImage();
    } else {
      exportReady();
    }
  }

  void exportReady() {
    if (!widget.exportMode || exportReadyReported) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!authorized || exportReadyReported) return;
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
      if (image != null) unawaited(MemoryImage(image!).evict());
      if (image != null && mounted) setState(() => image = null);
    }
  }

  @override
  void dispose() {
    w.removeListener(scopeChanged);
    if (sharedLease != null) unawaited(sharedLease!.dispose());
    sharedLease = null;
    imageCancel.cancel();
    downloadCancel.cancel();
    if (image != null) unawaited(MemoryImage(image!).evict());
    for (final route in [previewRoute, progressRoute]) {
      if (route?.isActive == true) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (route!.isActive) route.navigator?.removeRoute(route);
        });
      }
    }
    image = null;
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
    setState(() {
      loading = true;
      error = null;
    });
    imageCancel = CancelToken();
    try {
      final url = await resolve('inline');
      if (!authorized) return;
      final bytes = await files.image(url, cancel: imageCancel);
      if (authorized) setState(() => image = bytes);
    } catch (_) {
      if (authorized && !imageCancel.isCancelled) {
        setState(() => error = 'The image could not be loaded.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
      if (image != null || error != null) exportReady();
    }
  }

  Future<void> shareAttachment() async {
    if (!authorized || saving || !sharing.supported) return;
    setState(() => saving = true);
    downloadCancel = CancelToken();
    try {
      final url = await resolve('attachment');
      if (!authorized) return;
      if (sharedLease != null) await sharedLease!.dispose();
      sharedLease = await sharing.prepareAttachment(
        url: url,
        filename: name,
        cancel: downloadCancel,
        authorized: () => authorized,
        onProgress: (_, _) {
          if (!authorized) downloadCancel.cancel();
        },
      );
      if (sharedLease == null) return;
      if (!authorized) {
        await sharedLease!.dispose();
        sharedLease = null;
        return;
      }
      await sharing.shareFile(sharedLease!, mime);
    } catch (_) {
      if (mounted && authorized && !downloadCancel.isCancelled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              raftText(context, 'The attachment could not be shared.'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> download() async {
    if (!authorized || saving) return;
    setState(() => saving = true);
    downloadCancel = CancelToken();
    final progress = ValueNotifier<double?>(null);
    var dialogVisible = true;
    var progressOpened = false;
    // Use the platform save picker first; show progress only after it closes.
    try {
      final url = await resolve('attachment');
      if (!authorized) return;
      final saved = await files.save(
        url: url,
        filename: name,
        mimeType: mime,
        cancel: downloadCancel,
        authorized: () => authorized,
        onProgress: (received, total) {
          if (!authorized) {
            downloadCancel.cancel();
            return;
          }
          if (!progressOpened) {
            progressOpened = true;
            progressRoute = DialogRoute<void>(
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
                    onPressed: downloadCancel.cancel,
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            );
            Navigator.of(
              context,
              rootNavigator: true,
            ).push(progressRoute!).whenComplete(() => dialogVisible = false);
          }
          progress.value = total > 0 ? received / total : null;
        },
      );
      if (progressOpened && mounted && dialogVisible) {
        progressRoute?.navigator?.removeRoute(progressRoute!);
        dialogVisible = false;
      }
      if (saved != null && mounted && authorized) {
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
      if (mounted && authorized && !downloadCancel.isCancelled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Download failed. Try again.')),
        );
      }
    } finally {
      saving = false;
      if (progressOpened && progressRoute?.isActive == true) {
        progressRoute!.navigator?.removeRoute(progressRoute!);
      }
      progressRoute = null;
      // The dialog builder may still be mounted for its closing animation.
      Future<void>.delayed(const Duration(seconds: 1), progress.dispose);
    }
  }

  Future<void> open() async {
    if (!authorized || opening || previewRoute?.isActive == true) return;
    opening = true;
    try {
      await openCurrent();
    } finally {
      opening = false;
    }
  }

  Future<void> openCurrent() async {
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
        if (!authorized) return;
        enabled = gate is Map && gate['enabled'] == true;
      } on RaftApiException catch (error) {
        if (!authorized || [401, 403].contains(error.status)) return;
      } catch (_) {
        if (!authorized) return;
      }
      if (!enabled) {
        await download();
        return;
      }
      if (!mounted || !authorized) return;
      previewRoute = DialogRoute<void>(
        context: context,
        builder: (dialogContext) => html
            ? HtmlAttachmentPreviewDialog(
                controller: w,
                metadata: widget.metadata,
                authorized: () => authorized,
                onClose: () {
                  if (dialogContext.mounted &&
                      previewRoute?.isCurrent == true) {
                    previewRoute!.navigator?.pop();
                  }
                },
                onDownload: download,
              )
            : AttachmentPreviewDialog(
                controller: w,
                metadata: widget.metadata,
                authorized: () => authorized,
                onClose: () {
                  if (dialogContext.mounted &&
                      previewRoute?.isCurrent == true) {
                    previewRoute!.navigator?.pop();
                  }
                },
                onDownload: download,
              ),
      );
      await Navigator.of(context, rootNavigator: true).push(previewRoute!);
      previewRoute = null;
      return;
    }
    if (!isImage) {
      await download();
      return;
    }
    if (image == null) await loadImage();
    if (!mounted || !authorized || image == null) return;
    previewRoute = DialogRoute<void>(
      context: context,
      builder: (dialogContext) => RaftAttachmentLightbox(
        title: name,
        titleBold: true,
        onClose: () {
          final route = previewRoute;
          if (route?.isActive == true) route!.navigator?.removeRoute(route);
        },
        footer: RaftTextButton(
          label: 'Download original',
          glyph: RaftGlyph.download,
          onPressed: authorized ? download : null,
          variant: RaftControlVariant.ghost,
        ),
        child: Center(
          child: InteractiveViewer(
            child: Image.memory(
              image!,
              key: ValueKey('attachment-image-${widget.metadata['id']}'),
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Text(
                'Preview unavailable. Download the original file.',
              ),
            ),
          ),
        ),
      ),
    );
    await Navigator.of(context, rootNavigator: true).push(previewRoute!);
    previewRoute = null;
  }

  @override
  Widget build(BuildContext context) => RaftAttachmentCard(
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
        : Image.memory(
            image!,
            fit: widget.imageFit,
            errorBuilder: (_, _, _) => const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Preview unavailable. Download the original file.'),
            ),
          ),
  );
}
