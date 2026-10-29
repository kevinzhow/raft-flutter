import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'video_frame_probe_mpv.dart';

/// What one probe of a video yields: its first picture and its real shape.
@immutable
class VideoFrameInfo {
  const VideoFrameInfo({
    required this.width,
    required this.height,
    this.rotation = 0,
    this.duration = Duration.zero,
    this.jpeg,
  });

  /// The displayed size in pixels (the stored size with [rotation] applied).
  final int width, height;

  /// The rotation the container asks for, in degrees (0, 90, 180, 270). Already
  /// folded into [width], [height] and [jpeg]; kept for the record.
  final int rotation;
  final Duration duration;

  /// The first picture, JPEG, the longest edge at most `maxEdge` pixels, upright.
  /// Null when only the shape could be read.
  final Uint8List? jpeg;

  bool get valid => width > 0 && height > 0;
}

/// The real shape of a video: what a card lays itself out with, and what is
/// remembered (in memory and next to the poster on disk) so the second view
/// of a card has its final box in the first frame.
@immutable
class VideoShape {
  const VideoShape({
    required this.width,
    required this.height,
    this.rotation = 0,
    this.duration = Duration.zero,
  });

  factory VideoShape.of(VideoFrameInfo info) => VideoShape(
    width: info.width,
    height: info.height,
    rotation: info.rotation,
    duration: info.duration,
  );

  /// The displayed size in pixels (rotation applied).
  final int width, height;
  final int rotation;
  final Duration duration;

  double get aspect => width / height;
  bool get valid => width > 0 && height > 0;

  Uint8List toBytes() => Uint8List.fromList(
    utf8.encode(
      jsonEncode({
        'w': width,
        'h': height,
        'r': rotation,
        'd': duration.inMilliseconds,
      }),
    ),
  );

  /// Null for anything that is not a valid stored shape.
  static VideoShape? fromBytes(Uint8List bytes) {
    try {
      final json = jsonDecode(utf8.decode(bytes));
      if (json is! Map) return null;
      final width = json['w'], height = json['h'];
      if (width is! int || height is! int || width <= 0 || height <= 0) {
        return null;
      }
      final rotation = json['r'], duration = json['d'];
      return VideoShape(
        width: width,
        height: height,
        rotation: rotation is int ? rotation : 0,
        // ds-allow: the length of the video, not a motion duration
        duration: Duration(milliseconds: duration is int && duration > 0 ? duration : 0),
      );
    } on Object {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is VideoShape &&
      width == other.width &&
      height == other.height &&
      rotation == other.rotation &&
      duration == other.duration;
  @override
  int get hashCode => Object.hash(width, height, rotation, duration);
}

/// Why a probe produced nothing.
enum VideoFrameFailure {
  /// The host answered 401, 403 or 410: the signature expired. Sign again.
  expired,

  /// The probe was cancelled (the card scrolled away).
  cancelled,

  /// Anything else: no network, an undecodable file, a codec the platform lacks,
  /// the byte or time budget spent.
  failed,
}

class VideoFrameException implements Exception {
  const VideoFrameException(this.kind, [this.message]);
  final VideoFrameFailure kind;
  final String? message;
  @override
  String toString() => 'VideoFrameException($kind${message == null ? '' : ': $message'})';
}

/// Reads the first picture and the shape of a video from its URL without
/// downloading it: the platform reads only the byte ranges it needs (the
/// container header and the first key frame) and gives up past [maxBytes].
///
/// Android: `MediaMetadataRetriever`. iOS and macOS: `AVURLAsset` with
/// `AVAssetImageGenerator`. Windows and Linux: a one-off muted libmpv player
/// (`video_frame_probe_mpv.dart`). [id] names the request for [cancel].
abstract interface class VideoFrameProbe {
  /// Throws a [VideoFrameException].
  Future<VideoFrameInfo> probe({
    required String id,
    required Uri url,
    Map<String, String> headers = const {},
    int maxEdge = 640,
    Duration timeout = const Duration(seconds: 20),
    int maxBytes = 16 * 1024 * 1024,
  });

  /// Stops the probe named [id] (a no-op when it already ended).
  Future<void> cancel(String id);

  /// The probe of this platform, or null where there is none (web).
  static VideoFrameProbe? get platform {
    final override = debugOverride;
    if (override != null) return override();
    if (kIsWeb) return null;
    return _platform ??= switch (defaultTargetPlatform) {
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.macOS => const ChannelVideoFrameProbe(),
      TargetPlatform.windows || TargetPlatform.linux => MpvVideoFrameProbe(),
      TargetPlatform.fuchsia => null,
    };
  }

  static VideoFrameProbe? _platform;

  /// Test seam: the probe handed to every card without an explicit one.
  @visibleForTesting
  static VideoFrameProbe? Function()? debugOverride;
}

/// The Android / iOS / macOS bridge, channel `app.raft/video-frame`:
///
/// * `probe` `{id, url, headers, maxEdge, timeoutMs, maxBytes}` returns
///   `{jpeg: Uint8List?, width, height, rotation, durationMs}`; fails with a
///   `PlatformException` whose code is `expired`, `cancelled` or `failed`.
/// * `cancel` `{id}`.
class ChannelVideoFrameProbe implements VideoFrameProbe {
  const ChannelVideoFrameProbe();
  static const channel = MethodChannel('app.raft/video-frame');

  @override
  Future<VideoFrameInfo> probe({
    required String id,
    required Uri url,
    Map<String, String> headers = const {},
    int maxEdge = 640,
    Duration timeout = const Duration(seconds: 20),
    int maxBytes = 16 * 1024 * 1024,
  }) async {
    try {
      final result = await channel.invokeMapMethod<String, Object?>('probe', {
        'id': id,
        'url': url.toString(),
        'headers': headers,
        'maxEdge': maxEdge,
        'timeoutMs': timeout.inMilliseconds,
        'maxBytes': maxBytes,
      });
      final width = (result?['width'] as num?)?.toInt() ?? 0;
      final height = (result?['height'] as num?)?.toInt() ?? 0;
      if (result == null || width <= 0 || height <= 0) {
        throw const VideoFrameException(VideoFrameFailure.failed, 'no size');
      }
      return VideoFrameInfo(
        width: width,
        height: height,
        rotation: (result['rotation'] as num?)?.toInt() ?? 0,
        // ds-allow: the length of the video, not a motion duration
        duration: Duration(
          milliseconds: (result['durationMs'] as num?)?.toInt() ?? 0,
        ),
        jpeg: result['jpeg'] as Uint8List?,
      );
    } on PlatformException catch (error) {
      throw VideoFrameException(switch (error.code) {
        'expired' => VideoFrameFailure.expired,
        'cancelled' => VideoFrameFailure.cancelled,
        _ => VideoFrameFailure.failed,
      }, error.code);
    } on MissingPluginException {
      throw const VideoFrameException(VideoFrameFailure.failed, 'unsupported');
    }
  }

  @override
  Future<void> cancel(String id) async {
    try {
      await channel.invokeMethod<void>('cancel', {'id': id});
    } on PlatformException {
      // best effort
    } on MissingPluginException {
      // best effort
    }
  }
}
