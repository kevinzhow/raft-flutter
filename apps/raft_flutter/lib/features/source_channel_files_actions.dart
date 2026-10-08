import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/source_channel_files_store.dart';
import '../data/workspace_controller.dart';
import '../platform/attachment_files.dart';
import 'attachment_html_preview.dart';
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

typedef SourceChannelImageAcquire = Future<SourceChannelImageLease?> Function(
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
  final _routes = <DialogRoute<void>, SourceChannelFileEntry>{};
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
    final data = await controller.client.get(
      '/attachments/${Uri.encodeComponent(file.id)}/url',
      query: download ? {'disposition': 'attachment'} : null,
    );
    if (!current(file)) return null;
    if (data is! Map || data['url'] is! String) {
      throw const FormatException('Invalid attachment response.');
    }
    final value = data['url'] as String;
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
      ScaffoldMessenger.maybeOf(c)
          ?.showSnackBar(SnackBar(content: Text(raftText(c, message))));
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
        // Same mounted gate/error boundary as AttachmentView.openCurrent.
        var enabled = true;
        try {
          final gate = await controller.client.get(
            '/messages/attachment-preview/enabled',
          );
          if (!current(file)) return;
          enabled = gate is Map && gate['enabled'] == true;
        } on RaftApiException catch (error) {
          if (!current(file) || [401, 403].contains(error.status)) return;
        } catch (_) {
          if (!current(file)) return;
        }
        if (!enabled) {
          await download(file);
          return;
        }
        if (!current(file)) return;
        late DialogRoute<void> route;
        route = DialogRoute<void>(
          context: context(),
          builder: (_) => html
              ? HtmlAttachmentPreviewDialog(
                  controller: controller,
                  metadata: file.metadata,
                  authorized: () => current(file),
                  onClose: () => _close(route),
                  onDownload: () => download(file),
                )
              : AttachmentPreviewDialog(
                  controller: controller,
                  metadata: file.metadata,
                  authorized: () => current(file),
                  onClose: () => _close(route),
                  onDownload: () => download(file),
                ),
        );
        await _show(route, file);
        return;
      }
      if (raster || svgRaster) {
        if (file.sizeBytes > 50 * 1024 * 1024) {
          await download(file);
          return;
        }
        if (acquireImage != null) {
          final lease = await acquireImage!(
            file,
            () => current(file),
            SourceChannelImageRendition.original,
          );
          if (lease == null) return;
          try {
            if (!current(file)) return;
            late DialogRoute<void> route;
            route = DialogRoute<void>(
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
                child: Center(
                  child: InteractiveViewer(
                    child: Image(image: lease.provider, fit: BoxFit.contain),
                  ),
                ),
              ),
            );
            await _show(route, file);
          } finally {
            await lease.release();
          }
          return;
        }
        final cancel = CancelToken();
        _transfers[cancel] = file;
        Uint8List? image;
        MemoryImage? provider;
        try {
          final url = svgRaster
              ? file.metadata['thumbnailUrl'] as String
              : await resolve(file);
          if (url == null || !current(file) || cancel.isCancelled) return;
          image = await files.image(url, cancel: cancel);
          if (!current(file) ||
              cancel.isCancelled ||
              image.length > 50 * 1024 * 1024) {
            return;
          }
          provider = MemoryImage(image);
          late DialogRoute<void> route;
          route = DialogRoute<void>(
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
              child: Center(
                child: InteractiveViewer(
                  child: Image(
                    image: provider!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Text(
                      raftText(
                        context(),
                        'Preview unavailable. Download the original file.',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await _show(route, file);
        } finally {
          _transfers.remove(cancel);
          if (provider != null) await provider.evict();
          image = null;
        }
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

  Future<void> _show(
    DialogRoute<void> route,
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

  void _close(DialogRoute<void> route) {
    if (route.isCurrent) route.navigator?.removeRoute(route);
  }
}
