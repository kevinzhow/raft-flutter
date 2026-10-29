import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'attachment_player.dart';
import 'video_player_attachment_player.dart';

/// Which engine plays attachments on a platform.
enum AttachmentBackend {
  /// The platform's own player through `video_player`: ExoPlayer on Android,
  /// AVPlayer on iOS and macOS. HDR, hardware decoding and codec support come
  /// from the system, and no libmpv/FFmpeg is bundled.
  system,

  /// media_kit with a bundled libmpv/FFmpeg. Windows Media Foundation needs
  /// the optional HEVC extension and stock Linux GStreamer lacks H.264/HEVC,
  /// so the desktop platforms without a dependable system player bring their
  /// own decoders.
  mediaKit,
}

AttachmentBackend attachmentBackendFor(TargetPlatform platform) =>
    switch (platform) {
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.macOS => AttachmentBackend.system,
      TargetPlatform.windows ||
      TargetPlatform.linux ||
      TargetPlatform.fuchsia => AttachmentBackend.mediaKit,
    };

/// The player for one attachment on [platform] (the running platform by
/// default). media_kit is only touched when the platform uses it.
///
/// [hdr] asks for the surface that keeps HDR (the full-screen viewer only,
/// never a card in a list): the native view (`SurfaceView` on Android,
/// `AVPlayerLayer` on iOS and macOS) instead of the Flutter texture, which
/// both plugins tone-map to SDR. media_kit platforms ignore it.
AttachmentPlayer createAttachmentPlayer({
  bool video = true,
  Size maxVideoSize = const Size(1920, 1080),
  bool transparentVideo = false,
  bool hdr = false,
  TargetPlatform? platform,
  @visibleForTesting AttachmentPlayer Function()? debugMediaKit,
}) => switch (attachmentBackendFor(platform ?? defaultTargetPlatform)) {
  AttachmentBackend.system => VideoPlayerAttachmentPlayer(
    transparentVideo: transparentVideo,
    platformView: hdr,
    hasPicture: video,
  ),
  AttachmentBackend.mediaKit =>
    debugMediaKit?.call() ??
        NativeAttachmentPlayer(
          video: video,
          maxVideoSize: maxVideoSize,
          transparentVideo: transparentVideo,
        ),
};
