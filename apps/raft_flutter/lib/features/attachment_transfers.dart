// Every BuildContext use after an await is guarded by `_live()` (mounted).
// ignore_for_file: use_build_context_synchronously
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:raft_ui/raft_ui.dart';

import '../data/attachment_image_repository.dart';
import '../data/user_error.dart';
import '../data/workspace_controller.dart';
import '../platform/attachment_files.dart';
import '../platform/native_sharing.dart';
import 'attachment_image_loader.dart';

/// The authority of one operation: [alive] while the owner still shows the
/// same attachment binding, [current] when it is also still authorized.
typedef AttachmentTransferScope = ({
  bool Function() alive,
  bool Function() current,
});

/// Builds the dialog route that shows a download's progress; Cancel calls
/// `onCancel`.
typedef AttachmentProgressRouteBuilder =
    DialogRoute<void> Function({
      required BuildContext context,
      required String name,
      required ValueListenable<double?> progress,
      required VoidCallback onCancel,
    });

/// Save / share / save-to-gallery of one attachment, for the message tile
/// and for every page of the image viewer.
///
/// An attachment this device already holds (the persistent attachment cache)
/// is saved and shared from that copy without any request; a user's saved
/// file is always a separate copy. Only an attachment that is not stored is
/// signed (on demand) and downloaded.
class AttachmentTransfers {
  AttachmentTransfers({
    required this.controller,
    required this.files,
    required this.sharing,
    required this.metadata,
    required this.ownerChannel,
    required this.isImage,
    required this.context,
    required this.scope,
    this.onChanged,
    this.settleOriginal,
    this.progressRoute,
  });
  final WorkspaceController controller;
  final AttachmentFiles files;
  final NativeSharing sharing;
  final Map<String, dynamic> metadata;
  final String ownerChannel;
  final bool isImage;

  /// The context toasts and the progress dialog attach to; null once the
  /// owner is gone.
  final BuildContext? Function() context;

  /// Starts one operation's authority (the owner's binding revision).
  final AttachmentTransferScope Function() scope;
  final VoidCallback? onChanged;

  /// Completes when a load of the original that is already under way (the
  /// viewer page showing it) has finished, so it is not fetched twice.
  final Future<void> Function()? settleOriginal;
  final AttachmentProgressRouteBuilder? progressRoute;

  bool saving = false;

  /// The last explicit download failed; the file card offers a retry.
  bool downloadFailed = false;
  CancelToken cancel = CancelToken();
  DialogRoute<void>? progressDialog;
  SharedFileLease? sharedLease;

  String get name => '${metadata['filename'] ?? 'Attachment'}';
  String get mime => '${metadata['mimeType'] ?? 'application/octet-stream'}';
  bool get isSvg => attachmentIsSvg(metadata);
  AttachmentImageKey get originalKey =>
      attachmentOriginalKey(controller, metadata, ownerChannel);

  void _changed() => onChanged?.call();

  /// The binding ended: stop what is running and drop private copies.
  void abort() {
    cancel.cancel();
    if (progressDialog?.isActive == true) {
      progressDialog!.navigator?.removeRoute(progressDialog!);
    }
    progressDialog = null;
    final lease = sharedLease;
    sharedLease = null;
    if (lease != null) unawaited(lease.dispose());
  }

  /// A new binding starts clean.
  void reset() {
    abort();
    cancel = CancelToken();
    saving = false;
    downloadFailed = false;
  }

  Future<String> _resolve(String disposition) => controller.attachmentMedia.url(
    '${metadata['id']}',
    disposition: disposition,
    channelId: ownerChannel,
  );

  /// The copy of this attachment the cache already holds: the original image
  /// bytes, or the preview file (pinned: release it). Null when there is none.
  Future<({Uint8List? bytes, AttachmentCachedFile? file})?> storedCopy() async {
    final disk = controller.attachmentMedia.diskCache;
    if (disk == null) return null;
    try {
      if (isImage) {
        if (isSvg) return null;
        final bytes = await disk.read(originalKey.source.storeKey);
        return bytes == null ? null : (bytes: bytes, file: null);
      }
      final cached = await disk.openFile(
        controller.attachmentMedia.cacheKey(
          metadata,
          'file',
          channelId: ownerChannel,
        ),
        filename: name,
        expectedBytes: (metadata['sizeBytes'] as num?)?.toInt(),
      );
      return cached == null ? null : (bytes: null, file: cached);
    } catch (_) {
      return null;
    }
  }

  /// The original's bytes: the stored copy, else one on-demand fetch (the
  /// cached signed URL when one is still valid), kept in the cache.
  Future<Uint8List> originalBytes(CancelToken token) async {
    await _settle();
    final copy = await storedCopy();
    if (copy?.bytes != null) return copy!.bytes!;
    final key = originalKey;
    final bytes = await attachmentImageLoader(
      controller: controller,
      files: files,
      metadata: metadata,
      key: key,
    )(token);
    final disk = controller.attachmentMedia.diskCache;
    if (disk != null) {
      try {
        await disk.write(key.source.storeKey, bytes);
      } catch (_) {
        // The copy for the user is complete; the cache just misses one entry.
      }
    }
    return bytes;
  }

  Future<void> _settle() async {
    final wait = settleOriginal;
    if (wait == null) return;
    try {
      await wait();
    } catch (_) {
      // A failed load is retried by the operation itself.
    }
  }

  /// A way to save [storedCopy] through the picker, or null without one.
  Future<Future<String?> Function()?> _reusableCopy(
    bool Function() current,
  ) async {
    await _settle();
    final copy = await storedCopy();
    if (copy == null) return null;
    return () async {
      try {
        final bytes = copy.bytes;
        if (bytes != null) {
          return await files.saveBytes(
            bytes: bytes,
            filename: name,
            mimeType: mime,
            authorized: current,
          );
        }
        return await files.saveFile(
          source: copy.file!.file,
          filename: name,
          mimeType: mime,
          authorized: current,
        );
      } finally {
        copy.file?.release();
      }
    };
  }

  /// The toast context while the owner is still on screen.
  BuildContext? _live() {
    final c = context();
    return c != null && c.mounted ? c : null;
  }

  /// Save through the platform picker (desktop header Download, file cards).
  Future<void> download() async {
    final s = scope();
    final current = s.current;
    if (!current() || saving) return;
    saving = true;
    downloadFailed = false;
    _changed();
    final operationCancel = CancelToken();
    cancel = operationCancel;
    final progress = ValueNotifier<double?>(null);
    var dialogVisible = true;
    var progressOpened = false;
    DialogRoute<void>? operationRoute;
    // Use the platform save picker first; show progress only after it closes.
    try {
      // A copy this device already holds is saved without any request.
      final reuse = await _reusableCopy(current);
      final String? outcome;
      if (reuse != null) {
        outcome = await reuse();
      } else {
        final url = await _resolve('attachment');
        if (!current()) return;
        outcome = await files.save(
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
            final c = _live();
            if (!progressOpened && c != null && progressRoute != null) {
              progressOpened = true;
              operationRoute = progressRoute!(
                context: c,
                name: name,
                progress: progress,
                onCancel: operationCancel.cancel,
              );
              progressDialog = operationRoute;
              Navigator.of(
                c,
                rootNavigator: true,
              ).push(operationRoute!).whenComplete(() => dialogVisible = false);
            }
            progress.value = total > 0 ? received / total : null;
          },
        );
      }
      if (progressOpened && dialogVisible) {
        operationRoute?.navigator?.removeRoute(operationRoute!);
        dialogVisible = false;
      }
      final saved = outcome;
      if (saved != null && current()) {
        final c = _live();
        if (c != null) {
          showRaftToast(
            c,
            raftFormat(c, 'Saved {name}', {'name': name}),
            tone: RaftToastRecipeTone.success,
            actionLabel: 'Open',
            onAction: () async {
              try {
                await files.open(saved, mime);
              } catch (_) {
                final again = _live();
                if (again != null) {
                  showRaftToast(again, 'No application can open this file.');
                }
              }
            },
          );
        }
      }
    } catch (error) {
      if (current() && !operationCancel.isCancelled) {
        downloadFailed = true;
        _changed();
        final c = _live();
        if (c != null) {
          showRaftToast(
            c,
            userErrorText(
              error,
              fallback: 'Download failed. Try again.',
              where: 'attachment download',
            ),
          );
        }
      }
    } finally {
      if (s.alive()) {
        saving = false;
        _changed();
      }
      if (progressOpened && operationRoute?.isActive == true) {
        operationRoute!.navigator?.removeRoute(operationRoute!);
      }
      if (identical(progressDialog, operationRoute)) progressDialog = null;
      // The dialog builder may still be mounted for its closing animation.
      Future<void>.delayed(const Duration(seconds: 1), progress.dispose);
    }
  }

  /// The system share sheet with a private copy of the original.
  Future<void> share() async {
    final s = scope();
    final current = s.current;
    if (!current() || saving || !sharing.supported) return;
    saving = true;
    _changed();
    final operationCancel = CancelToken();
    cancel = operationCancel;
    try {
      await _settle();
      final copy = await storedCopy();
      final SharedFileLease? prepared;
      if (copy != null) {
        // This device already holds the file: share a private copy of it.
        if (sharedLease != null) await sharedLease!.dispose();
        try {
          prepared = copy.bytes != null
              ? await sharing.prepareBytes(
                  copy.bytes!,
                  filename: name,
                  authorized: current,
                )
              : await sharing.prepareFile(
                  copy.file!.file,
                  filename: name,
                  authorized: current,
                );
        } finally {
          copy.file?.release();
        }
      } else {
        final url = await _resolve('attachment');
        if (!current()) return;
        if (sharedLease != null) await sharedLease!.dispose();
        prepared = await sharing.prepareAttachment(
          url: url,
          filename: name,
          cancel: operationCancel,
          authorized: current,
          onProgress: (_, _) {
            if (!current()) operationCancel.cancel();
          },
        );
      }
      if (prepared == null) return;
      if (!current()) {
        await prepared.dispose();
        return;
      }
      sharedLease = prepared;
      await sharing.shareFile(prepared, mime);
    } catch (error) {
      if (current() && !operationCancel.isCancelled) {
        final c = _live();
        if (c != null) {
          showRaftToast(
            c,
            userErrorText(
              error,
              fallback: 'The attachment could not be shared.',
              where: 'attachment share',
            ),
          );
        }
      }
    } finally {
      if (s.alive()) {
        saving = false;
        _changed();
      }
    }
  }

  /// Saves the original image into the photo library (phone long-press).
  Future<void> saveToGallery() async {
    final s = scope();
    final current = s.current;
    if (!current() || saving || !isImage || isSvg || !files.gallerySupported) {
      return;
    }
    saving = true;
    _changed();
    final operationCancel = CancelToken();
    cancel = operationCancel;
    try {
      final bytes = await originalBytes(operationCancel);
      if (!current()) return;
      final saved = await files.saveToGallery(
        bytes: bytes,
        filename: name,
        mimeType: mime,
        authorized: current,
      );
      if (saved != null && current()) {
        final c = _live();
        if (c != null) {
          if (AttachmentFiles.galleryLabel == 'Save to Photos') {
            showRaftToast(
              c,
              'Saved to Photos.',
              tone: RaftToastRecipeTone.success,
            );
          } else {
            showRaftToast(
              c,
              'Saved to Gallery.',
              tone: RaftToastRecipeTone.success,
            );
          }
        }
      }
    } catch (error) {
      if (current() && !operationCancel.isCancelled) {
        final c = _live();
        if (c != null) {
          showRaftToast(
            c,
            userErrorText(
              error,
              fallback: 'The image could not be saved.',
              where: 'attachment gallery save',
            ),
          );
        }
      }
    } finally {
      if (s.alive()) {
        saving = false;
        _changed();
      }
    }
  }
}
