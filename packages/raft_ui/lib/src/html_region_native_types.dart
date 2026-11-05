import 'dart:typed_data';

import 'package:flutter/widgets.dart';

/// Optional native paint/input capability. The regular region controller stays
/// unchanged for Flutter-composited Windows and mobile previews.
abstract interface class RaftHtmlNativeRegionController {
  Stream<RaftHtmlNativeRegionInput> get nativeRegionInputs;
  void updateNativeRegionOverlay(RaftHtmlNativeRegionOverlay frame);
}

enum RaftHtmlNativeRegionPhase { down, move, up, cancel, scroll }

/// A real host pointer event, never an uploaded page's message. Position/delta
/// are normalized to [viewport], which must match the original complete pane.
@immutable
class RaftHtmlNativeRegionInput {
  const RaftHtmlNativeRegionInput({
    required this.generation,
    required this.sequence,
    required this.phase,
    required this.position,
    required this.viewport,
    this.delta = Offset.zero,
  });
  final int generation, sequence;
  final RaftHtmlNativeRegionPhase phase;
  final Offset position, delta;
  final Size viewport;
}

/// One marker from the canonical region recipe. Native code draws these values
/// verbatim; it does not resolve theme tokens, timing, dash lengths or colors.
@immutable
class RaftHtmlNativeRegionMarker {
  const RaftHtmlNativeRegionMarker({
    required this.rect,
    required this.fill,
    required this.border,
    required this.strokeWidth,
    required this.radius,
    required this.dashed,
    required this.borderSegments,
    required this.progress,
  });
  final Rect rect;
  final Color fill, border;
  final double strokeWidth, radius, progress;
  final bool dashed;
  final List<Rect> borderSegments;
}

/// Raster of the existing hint widget, including theme, locale, text scaling
/// and shadow. Native decoders must enforce both byte and decoded-pixel bounds.
@immutable
class RaftHtmlNativeRegionHint {
  const RaftHtmlNativeRegionHint({
    required this.png,
    required this.logicalSize,
    required this.logicalOffset,
  });
  static const maximumBytes = 1024 * 1024;
  static const maximumPixels = 4 * 1024 * 1024;
  final Uint8List png;
  final Size logicalSize;
  final Offset logicalOffset;
}

/// SDK-issued generation and sequence fence every frame and pointer event.
/// Empty markers/hint with capture disabled retire the old overlay immediately.
@immutable
class RaftHtmlNativeRegionOverlay {
  const RaftHtmlNativeRegionOverlay({
    required this.generation,
    required this.sequence,
    required this.viewport,
    required this.captureEnabled,
    this.markers = const [],
    this.hint,
  });
  final int generation, sequence;
  final Size viewport;
  final bool captureEnabled;
  final List<RaftHtmlNativeRegionMarker> markers;
  final RaftHtmlNativeRegionHint? hint;
}
