import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/attachment_image_repository.dart';
import '../data/workspace_controller.dart';
import '../platform/attachment_player_sessions.dart' show PlayerSessions;
import '../platform/attachment_stream.dart';
import '../platform/video_frame_probe.dart';

/// The real shape (displayed pixel size) of an image or video attachment.
///
/// A message normally carries `width` and `height`. An upload that did not send
/// them (a CLI upload, a client that does not read the picture) has none; the
/// card then learns the shape from what it decodes anyway (an image's own
/// preview, a video's first frame), remembers it for the session and stores it
/// in the private attachment cache (`image-shape` / `video-shape` entries), so
/// the second view of the row has its final box in the first frame.

/// The message's own size, when valid.
VideoShape? attachmentDeclaredShape(Map<String, dynamic> metadata) {
  final width = (metadata['width'] as num?)?.toDouble();
  final height = (metadata['height'] as num?)?.toDouble();
  if (width == null ||
      height == null ||
      !width.isFinite ||
      !height.isFinite ||
      width <= 0 ||
      height <= 0) {
    return null;
  }
  return VideoShape(width: width.round(), height: height.round());
}

/// The message's size, else the one learnt this session or read from disk.
VideoShape? attachmentShape(
  WorkspaceController w,
  Map<String, dynamic> metadata,
) =>
    attachmentDeclaredShape(metadata) ??
    w.attachmentMedia.playerSessions.shapes[attachmentMediaKey(metadata)];

AttachmentImageStoreKey _shapeKey(
  WorkspaceController w,
  Map<String, dynamic> metadata,
  String kind,
  String channelId,
) => w.attachmentMedia.cacheKey(metadata, kind, channelId: channelId);

/// Reads the stored shape of [metadata] into the session (no-op when there is
/// one). [kind] is `image-shape` or `video-shape`.
Future<void> readStoredShape(
  WorkspaceController w,
  Map<String, dynamic> metadata, {
  required String kind,
  required String channelId,
  required bool Function() authorized,
}) async {
  final disk = w.attachmentMedia.diskCache;
  if (disk == null || attachmentShape(w, metadata) != null) return;
  try {
    final bytes = await disk.read(_shapeKey(w, metadata, kind, channelId));
    if (bytes == null || !authorized()) return;
    final stored = VideoShape.fromBytes(bytes);
    if (stored != null) {
      w.attachmentMedia.playerSessions.rememberShape(attachmentMediaKey(metadata), stored);
    }
  } on Object {
    // Not stored: the shape comes with the first decode.
  }
}

/// Remembers [shape] for [metadata] (and stores it when [persist]).
void learnShape(
  WorkspaceController w,
  Map<String, dynamic> metadata,
  VideoShape shape, {
  required String kind,
  required String channelId,
  bool persist = true,
}) {
  w.attachmentMedia.playerSessions.rememberShape(attachmentMediaKey(metadata), shape);
  final disk = w.attachmentMedia.diskCache;
  if (persist && disk != null) {
    unawaited(
      disk
          .write(_shapeKey(w, metadata, kind, channelId), shape.toBytes())
          .catchError((Object _) {}),
    );
  }
}

/// The image gallery of one message, laid out with each picture's shape: the
/// message's own `width` / `height`, else the one learnt from the picture's
/// decode (or read from the cache), which arrives once and re-lays the row out.
class ShapedImageGallery extends StatelessWidget {
  const ShapedImageGallery({
    super.key,
    required this.sessions,
    required this.images,
    required this.builder,
  });
  final PlayerSessions sessions;
  final List<Map<String, dynamic>> images;
  final Widget Function(List<({double? width, double? height})> dimensions)
  builder;

  List<({double? width, double? height})> get dimensions => [
    for (final a in images)
      () {
        final shape =
            attachmentDeclaredShape(a) ??
            sessions.shapes[attachmentMediaKey(a)];
        return (
          width: shape?.width.toDouble(),
          height: shape?.height.toDouble(),
        );
      }(),
  ];

  @override
  Widget build(BuildContext context) {
    // Only a message with a picture that has no size listens.
    if (images.every((a) => attachmentDeclaredShape(a) != null)) {
      return builder(dimensions);
    }
    return ListenableBuilder(
      listenable: sessions.shapeChanges,
      builder: (context, _) => builder(dimensions),
    );
  }
}
