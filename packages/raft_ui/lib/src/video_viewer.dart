// Web `VideoPreviewBody` (attachmentPreviewSurfaces.tsx): the viewer's black
// stage with 16 px around a video that keeps its own size (never enlarged),
// shrinks to fit, wears the `border-line-muted` (brutal `border-2 border-black`)
// frame, and carries the browser's control panel. Here the panel is the same
// control language as the message card ([RaftVideoOverlay]).
import 'package:flutter/material.dart';

import 'attachment_lightbox.dart' show RaftLightboxStageInset;
import 'theme.dart';
import 'video_controls.dart';

class RaftVideoViewer extends StatefulWidget {
  const RaftVideoViewer({
    super.key,
    required this.video,
    required this.filename,
    this.videoSize,
    this.playing = false,
    this.buffering = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.volume = 100,
    this.touch,
    this.onTogglePlay,
    this.onSeek,
    this.onVolume,
    this.onDownload,
    this.immersive = false,
    this.onSurfaceTap,
    this.controlsInset = 0,
    this.controlsVisible,
  });

  /// The media browser's phone page: the picture takes the whole stage (no
  /// frame, no full-screen toggle); a tap on it calls [onSurfaceTap] and the
  /// control bar keeps [controlsInset] free below it (the strip).
  final bool immersive;
  final VoidCallback? onSurfaceTap;
  final double controlsInset;

  /// See [RaftVideoOverlay.controlsVisible].
  final bool? controlsVisible;

  /// The decoded video surface.
  final Widget video;
  final String filename;

  /// The video's own pixel size (null until known: the stage is used).
  final Size? videoSize;
  final bool playing, buffering;
  final Duration position, duration;

  /// 0..100.
  final double volume;
  final bool? touch;
  final VoidCallback? onTogglePlay, onDownload;
  final ValueChanged<Duration>? onSeek;
  final ValueChanged<double>? onVolume;

  @override
  State<RaftVideoViewer> createState() => _RaftVideoViewerState();
}

class _RaftVideoViewerState extends State<RaftVideoViewer> {
  /// Full screen of the viewer: the picture takes the whole stage, no frame.
  bool _fullscreen = false;
  bool get fullscreen => widget.immersive || _fullscreen;

  Widget stage(BuildContext context, BoxConstraints constraints) {
    final t = RaftTokens.of(context);
    final rule = t.brutal ? 2.0 : 1.0;
    final frame = t.brutal ? Colors.black : t.colors['line-muted']!;
    final pad = fullscreen ? 0.0 : 16.0;
    final border = fullscreen ? 0.0 : rule;
    // The <video> keeps its intrinsic content size and the frame wraps it
    // (`max-h-full max-w-full` shrinks it to fit, never enlarges).
    final maxW = (constraints.maxWidth - 2 * pad - 2 * border).clamp(0.0, 1e5);
    final maxH = (constraints.maxHeight - 2 * pad - 2 * border).clamp(0.0, 1e5);
    final intrinsic = widget.videoSize;
    var w = maxW, h = maxH;
    if (!fullscreen && intrinsic != null && !intrinsic.isEmpty) {
      final scale = [
        1.0,
        maxW / intrinsic.width,
        maxH / intrinsic.height,
      ].reduce((a, b) => a < b ? a : b);
      w = (intrinsic.width * scale).roundToDouble();
      h = (intrinsic.height * scale).roundToDouble();
    }
    w += 2 * border;
    h += 2 * border;
    return Center(
      child: Container(
        key: const Key('video-viewer-frame'),
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: Colors.black,
          border: fullscreen ? null : Border.all(color: frame, width: rule),
        ),
        child: RaftVideoOverlay(
          filename: widget.filename,
          buffering: widget.buffering,
          playing: widget.playing,
          position: widget.position,
          duration: widget.duration,
          volume: widget.volume,
          touch: widget.touch,
          fullscreen: fullscreen,
          onTogglePlay: widget.onTogglePlay,
          onSeek: widget.onSeek,
          onVolume: widget.onVolume,
          onDownload: widget.onDownload,
          onFullscreen: widget.immersive
              ? null
              : () => setState(() => _fullscreen = !_fullscreen),
          onSurfaceTap: widget.onSurfaceTap,
          controlsInset: widget.controlsInset,
          controlsVisible: widget.controlsVisible,
          child: ColoredBox(color: Colors.black, child: widget.video),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    key: const Key('video-viewer'),
    color: Colors.black,
    // The gallery reserves its thumbnail band on both sides of the centre
    // line. Fit the picture and its controls inside that room, just as images
    // do, so the strip cannot intercept the seek rail or action targets.
    child: Padding(
      padding: EdgeInsets.symmetric(
        vertical: RaftLightboxStageInset.of(context),
      ),
      child: LayoutBuilder(builder: stage),
    ),
  );
}
