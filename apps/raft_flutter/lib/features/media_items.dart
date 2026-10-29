import 'dart:ui' show Size;

/// What a page of the media browser shows.
enum MediaKind { image, video }

/// One page of the media browser: an image or (behind the P3 flag) a video of
/// the opening message. The browser pages through these in message order;
/// everything else (audio, PDF, documents) keeps opening in the preview
/// dialog.
class MediaItem {
  const MediaItem({required this.kind, required this.metadata, this.duration});

  const MediaItem.image(Map<String, dynamic> metadata)
    : this(kind: MediaKind.image, metadata: metadata);

  const MediaItem.video(Map<String, dynamic> metadata, {Duration? duration})
    : this(kind: MediaKind.video, metadata: metadata, duration: duration);

  final MediaKind kind;

  /// The attachment record as the message carries it.
  final Map<String, dynamic> metadata;

  /// Known video length (from the player), when there is one.
  final Duration? duration;

  String get id => '${metadata['id']}';
  String get filename => '${metadata['filename'] ?? 'Attachment'}';
  bool get isVideo => kind == MediaKind.video;
  int? get sizeBytes => (metadata['sizeBytes'] as num?)?.toInt();

  /// The declared pixel size, when valid.
  Size? get pixelSize {
    final width = (metadata['width'] as num?)?.toDouble();
    final height = (metadata['height'] as num?)?.toDouble();
    return width != null &&
            height != null &&
            width > 0 &&
            height > 0 &&
            width.isFinite &&
            height.isFinite
        ? Size(width, height)
        : null;
  }
}

/// The message an item came from: who sent it, when, and what they wrote.
/// Shown as the `sender · time` sub-line and the phone caption.
class MediaMessageInfo {
  const MediaMessageInfo({this.sender, this.time, this.text});

  final String? sender;

  /// The send time as the viewer's time preferences format it.
  final String? time;

  /// The message text (the caption); null or blank means none.
  final String? text;

  /// The caption: the message text, trimmed; null when there is none.
  String? get caption {
    final value = text?.trim();
    return value == null || value.isEmpty ? null : value;
  }
}
