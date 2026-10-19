import 'package:dio/dio.dart';

import '../data/attachment_image_repository.dart';
import '../data/workspace_controller.dart';
import '../platform/attachment_files.dart';

/// The one place that knows how an attachment image's bytes are fetched, for
/// the list tile and for every page of the image viewer: the server
/// thumbnail from the signature that came with the message, else the
/// original signed on demand (never speculatively).

bool attachmentIsSvg(Map<String, dynamic> metadata) =>
    '${metadata['mimeType'] ?? ''}'.toLowerCase().split(';').first.trim() ==
    'image/svg+xml';

/// Server-generated 320px WebP (Web's inline `thumbnailUrl` source).
String? attachmentThumbnailUrl(Map<String, dynamic> metadata) {
  final value = metadata['thumbnailUrl'];
  return value is String &&
          (value.startsWith('https://') || value.startsWith('http://'))
      ? value
      : null;
}

/// The channel an attachment belongs to for authority and cache scope.
String attachmentOwnerChannel(
  WorkspaceController w,
  Map<String, dynamic> metadata,
  String? messageId,
) =>
    '${metadata['channelId'] ?? (w.messageDomain.presentsReply(messageId) ? w.threadChannelId : w.channel?.id) ?? ''}';

/// Key of the full-resolution original (the thumbnail for an SVG, whose
/// bytes are never decoded).
AttachmentImageKey attachmentOriginalKey(
  WorkspaceController w,
  Map<String, dynamic> metadata,
  String ownerChannel,
) => AttachmentImageKey.fromMetadata(
  scope: w.attachmentImageScope,
  channelId: ownerChannel,
  metadata: metadata,
  rendition:
      attachmentIsSvg(metadata) && attachmentThumbnailUrl(metadata) != null
      ? 'thumbnail'
      : 'original',
);

/// Fetches [key]'s source bytes. Capability URLs live only in this call.
AttachmentImageLoader attachmentImageLoader({
  required WorkspaceController controller,
  required AttachmentFiles files,
  required Map<String, dynamic> metadata,
  required AttachmentImageKey key,
}) {
  final id = metadata['id'];
  final thumbnail = key.rendition == 'thumbnail'
      ? attachmentThumbnailUrl(metadata)
      : null;
  return (cancel) async {
    final channelId = key.channelId;
    if (thumbnail != null) {
      try {
        return await files.image(
          thumbnail,
          cancel: cancel,
          onProgress: cancel.progressSink,
        );
      } on DioException catch (error) {
        // The thumbnail's signature came with the message and has lapsed:
        // sign the original once (batched with the other tiles) rather than
        // showing a broken card.
        // ignore: raft_lints/avoid_caught_exception_text -- Reads the HTTP status to decide whether to re-sign a lapsed thumbnail or URL; no text reaches the UI.
        final status = error.response?.statusCode;
        if (cancel.isCancelled || (status != 401 && status != 403)) rethrow;
      }
    }
    final url = await controller.attachmentMedia.url(
      '$id',
      channelId: channelId,
      coalesce: true,
    );
    if (cancel.isCancelled) throw const StaleAttachmentImage();
    try {
      return await files.image(
        url,
        cancel: cancel,
        onProgress: cancel.progressSink,
      );
    } on DioException catch (error) {
      // A reused URL can outlive the server's view of it (clock skew,
      // early expiry): drop it and sign once more.
      // ignore: raft_lints/avoid_caught_exception_text -- Reads the HTTP status to decide whether to re-sign a lapsed thumbnail or URL; no text reaches the UI.
      final status = error.response?.statusCode;
      if (cancel.isCancelled || (status != 401 && status != 403)) rethrow;
      controller.attachmentMedia.invalidateUrl('$id');
      final fresh = await controller.attachmentMedia.url('$id', channelId: channelId);
      if (cancel.isCancelled) throw const StaleAttachmentImage();
      return files.image(
        fresh,
        cancel: cancel,
        onProgress: cancel.progressSink,
      );
    }
  };
}
