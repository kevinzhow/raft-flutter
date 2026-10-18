import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/source_channel_files_store.dart';
import '../data/workspace_controller.dart';
import '../platform/attachment_files.dart';
import 'attachment_html_preview.dart';
import 'attachment_preview_gate.dart';
import 'attachment_preview_dialog.dart';

/// Optional adapter to the controller-owned bounded image lease repository.
/// The host owns its authority-retention/cancellation policy; this surface holds
/// one lease only while a thumbnail or image preview is visible.
class SourceChannelImageLease {
  const SourceChannelImageLease({
    required this.provider,
    required this.release,
  });
  final ImageProvider provider;
  final Future<void> Function() release;
}

typedef SourceChannelImageAcquire =
    Future<SourceChannelImageLease?> Function(
      SourceChannelFileEntry file,
      bool Function() authorized,
      SourceChannelImageRendition rendition,
    );

/// Synchronous counterpart of [SourceChannelImageAcquire]: a lease on an image
/// the host already holds decoded, or null. Lets a recycled or revisited row
/// paint its thumbnail in the first frame.
typedef SourceChannelImagePeek =
    SourceChannelImageLease? Function(
      SourceChannelFileEntry file,
      bool Function() authorized,
      SourceChannelImageRendition rendition,
    );

enum SourceChannelImageRendition { thumbnail, original }

/// Reuses existing platform save/preview surfaces; list ownership replaces the
/// message-row visibility predicate, never the current principal/channel fence.
class SourceChannelFilesActions {
  SourceChannelFilesActions({
    required this.controller,
    required this.authorized,
    required this.context,
    this.acquireImage,
    AttachmentFiles? files,
  }) : files = files ?? AttachmentFiles();
  final WorkspaceController controller;
  final bool Function(SourceChannelFileEntry) authorized;
  final BuildContext Function() context;
  final AttachmentFiles files;
  final SourceChannelImageAcquire? acquireImage;
  final _transfers = <CancelToken, SourceChannelFileEntry>{};
  final _routes = <ModalRoute<void>, SourceChannelFileEntry>{};
  bool _disposed = false;
  bool current(SourceChannelFileEntry file) => !_disposed && authorized(file);
  void sync() {
    for (final item in _transfers.entries.toList()) {
      if (!current(item.value)) {
        item.key.cancel();
        _transfers.remove(item.key);
      }
    }
    for (final item in _routes.entries.toList()) {
      if (!current(item.value)) {
        _routes.remove(item.key);
        // Own only this route; never pop a newer route during revocation.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (item.key.isActive) item.key.navigator?.removeRoute(item.key);
        });
      }
    }
  }

  void dispose() {
    _disposed = true;
    sync();
  }

  Future<String?> resolve(
    SourceChannelFileEntry file, {
    bool download = false,
  }) async {
    if (!current(file)) return null;
    final value = await controller.attachmentMedia.url(
      file.id,
      disposition: download ? 'attachment' : null,
      channelId: file.channelId,
    );
    if (!current(file)) return null;
    AttachmentFiles.attachmentUri(value); // HTTP(S), no user-info.
    return value; // Capability is confined to the active action.
  }

  Future<void> download(SourceChannelFileEntry file) async {
    if (!current(file)) return;
    final cancel = CancelToken();
    _transfers[cancel] = file;
    try {
      final url = await resolve(file, download: true);
      if (url == null || cancel.isCancelled || !current(file)) return;
      await files.save(
        url: url,
        filename: file.filename,
        mimeType: file.mimeType,
        cancel: cancel,
        authorized: () => current(file),
        onProgress: (_, _) {
          if (!current(file)) cancel.cancel();
        },
      );
    } catch (_) {
      if (!cancel.isCancelled && current(file)) {
        _error('Download failed. Try again.');
      }
    } finally {
      _transfers.remove(cancel);
    }
  }

  void _error(String message) {
    final c = context();
    if (!_disposed && c.mounted) {
      showRaftToast(c, message);
    }
  }

  Future<void> preview(SourceChannelFileEntry file) async {
    if (!current(file)) return;
    final mime = file.mimeType.toLowerCase().split(';').first.trim();
    final raster = mime.startsWith('image/') && mime != 'image/svg+xml';
    final svgRaster =
        mime == 'image/svg+xml' && file.metadata['thumbnailUrl'] is String;
    final html =
        mime == 'text/html' ||
        RegExp(r'\.html?$', caseSensitive: false).hasMatch(file.filename);
    final kind = attachmentPreviewKind(file.metadata);
    try {
      if (!raster && !svgRaster && (html || kind != null)) {
        // Same mounted gate/error boundary as AttachmentView.openCurrent: a
        // gate this device has seen opens the preview at once (re-read behind
        // it); only a gate never seen is read while the preview is on screen.
        final known = knownAttachmentPreviewGate(controller);
        final gate = readAttachmentPreviewGate(controller);
        if (known == false) {
          final decided = await gate;
          if (!current(file) || decided == AttachmentPreviewGate.unauthorized) {
            return;
          }
          if (decided == AttachmentPreviewGate.disabled) {
            await download(file);
            return;
          }
        }
        if (!current(file)) return;
        late ModalRoute<void> route;
        final page = RaftAdaptiveWorkspace.compactOf(context());
        // The page on a compact window (back button, swipe back), like the
        // chat's attachments; the dialog on a wide one.
        route = attachmentPreviewRoute(
          context(),
          page,
          (_) => html
              ? HtmlAttachmentPreviewDialog(
                  page: page,
                  controller: controller,
                  metadata: file.metadata,
                  authorized: () => current(file),
                  onClose: () => _close(route),
                  onDownload: () => download(file),
                )
              : AttachmentPreviewDialog(
                  page: page,
                  controller: controller,
                  metadata: file.metadata,
                  authorized: () => current(file),
                  onClose: () => _close(route),
                  onDownload: () => download(file),
                ),
        );
        if (known == null) {
          unawaited(
            gate.then((decided) {
              if (decided == AttachmentPreviewGate.enabled || !route.isActive) {
                return;
              }
              _close(route);
              if (decided == AttachmentPreviewGate.disabled && current(file)) {
                unawaited(download(file));
              }
            }),
          );
        }
        await _show(route, file);
        return;
      }
      if (raster || svgRaster) {
        if (file.sizeBytes > 50 * 1024 * 1024) {
          await download(file);
          return;
        }
        // The lightbox opens at once; the original fills it when it arrives.
        late DialogRoute<void> route;
        final imageKey = GlobalKey();
        final width = (file.metadata['width'] as num?)?.toDouble();
        final height = (file.metadata['height'] as num?)?.toDouble();
        route = RaftFullBleedDialogRoute<void>(
          context: context(),
          builder: (_) => RaftAttachmentLightbox(
            title: file.filename,
            titleBold: true,
            onClose: () => _close(route),
            footer: RaftTextButton(
              label: raftText(context(), 'Download original'),
              glyph: RaftGlyph.download,
              onPressed: () => download(file),
            ),
            child: _FileLightboxImage(
              imageKey: imageKey,
              onClose: () => _close(route),
              size: width != null && height != null && width > 0 && height > 0
                  ? Size(width, height)
                  : null,
              load: (cancel) => _loadImage(file, cancel, svgRaster),
            ),
          ),
        );
        await _show(route, file);
        return;
      }
      // Original non-previewable fallback opens one ephemeral signed URL after
      // explicit row activation. External browser/application is the OS boundary.
      final url = await resolve(file);
      if (url != null && current(file)) {
        await launchUrl(
          AttachmentFiles.attachmentUri(url),
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (_) {
      if (current(file)) {
        _error('Preview unavailable. Download the original file.');
      }
    }
  }

  Future<_LoadedFileImage?> _loadImage(
    SourceChannelFileEntry file,
    CancelToken cancel,
    bool svgRaster,
  ) async {
    if (acquireImage != null) {
      final lease = await acquireImage!(
        file,
        () => current(file),
        SourceChannelImageRendition.original,
      );
      if (lease == null) return null;
      if (!current(file) || cancel.isCancelled) {
        await lease.release();
        return null;
      }
      return _LoadedFileImage(
        image: (key) =>
            // ignore: raft_lints/avoid_raw_image_decode -- The provider comes from an AttachmentImageRepository lease: already decoded at the target size and shared with the message bubble.
            Image(image: lease.provider, key: key, fit: BoxFit.contain),
        release: lease.release,
      );
    }
    _transfers[cancel] = file;
    Uint8List? image;
    try {
      final url = svgRaster
          ? file.metadata['thumbnailUrl'] as String
          : await resolve(file);
      if (url == null || !current(file) || cancel.isCancelled) return null;
      image = await files.image(url, cancel: cancel);
      final bytes = image;
      if (!current(file) ||
          cancel.isCancelled ||
          bytes.length > 50 * 1024 * 1024) {
        await raftEvictMemoryImage(bytes);
        return null;
      }
      return _LoadedFileImage(
        image: (key) => RaftSizedImage.memory(
          bytes,
          key: key,
          fit: BoxFit.contain,
          zoom: raftZoomableImageScale,
          evictOnDispose: true,
          errorBuilder: (_, _, _) => Text(
            raftText(
              context(),
              'Preview unavailable. Download the original file.',
            ),
          ),
        ),
        release: () => raftEvictMemoryImage(bytes),
      );
    } finally {
      _transfers.remove(cancel);
    }
  }

  Future<void> _show(
    ModalRoute<void> route,
    SourceChannelFileEntry file,
  ) async {
    if (!current(file) || !context().mounted) return;
    _routes[route] = file;
    try {
      await Navigator.of(context(), rootNavigator: true).push(route);
    } finally {
      _routes.remove(route);
    }
  }

  void _close(ModalRoute<void> route) {
    if (route.isCurrent) route.navigator?.removeRoute(route);
  }
}

/// A decoded Files image and how to give it back.
class _LoadedFileImage {
  const _LoadedFileImage({required this.image, required this.release});
  final Widget Function(Key key) image;
  final Future<void> Function() release;
}

/// The Files lightbox stage: on screen from the first frame with a stand-in in
/// the image's aspect ratio, replaced in place by the image when it is ready.
/// Closing the lightbox cancels a load still in flight and gives the image back.
class _FileLightboxImage extends StatefulWidget {
  const _FileLightboxImage({
    required this.imageKey,
    required this.onClose,
    required this.load,
    this.size,
  });
  final GlobalKey imageKey;
  final VoidCallback onClose;
  final Size? size;
  final Future<_LoadedFileImage?> Function(CancelToken cancel) load;
  @override
  State<_FileLightboxImage> createState() => _FileLightboxImageState();
}

class _FileLightboxImageState extends State<_FileLightboxImage> {
  final cancel = CancelToken();
  _LoadedFileImage? loaded;
  bool failed = false, disposed = false;

  @override
  void initState() {
    super.initState();
    unawaited(run());
  }

  Future<void> run() async {
    try {
      final value = await widget.load(cancel);
      if (disposed) {
        await value?.release();
        return;
      }
      if (value == null) {
        widget.onClose();
        return;
      }
      setState(() => loaded = value);
    } catch (_) {
      if (!disposed) setState(() => failed = true);
    }
  }

  @override
  void dispose() {
    disposed = true;
    cancel.cancel();
    final held = loaded;
    loaded = null;
    if (held != null) unawaited(held.release());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = loaded;
    if (image != null) {
      return RaftLightboxStageTap(
        imageKey: widget.imageKey,
        onClose: widget.onClose,
        child: Center(
          child: InteractiveViewer(child: image.image(widget.imageKey)),
        ),
      );
    }
    if (failed) {
      return Center(
        child: Text(
          raftText(context, 'Preview unavailable. Download the original file.'),
        ),
      );
    }
    final size = widget.size;
    return Center(
      child: AspectRatio(
        aspectRatio: size == null ? 4 / 3 : size.width / size.height,
        child: const RaftTransferPlaceholder(),
      ),
    );
  }
}
