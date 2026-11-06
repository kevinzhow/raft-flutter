import 'package:flutter/rendering.dart';

/// GTK logical coordinates, rather than document CSS or physical pixels.
/// Unsupported transforms and clips hide the native view instead of letting
/// native painting or pointer input escape the Flutter content rectangle.
class SystemWebViewLayout {
  const SystemWebViewLayout(
    this.frame,
    this.clip, {
    this.paintOccluded = false,
    Rect? viewFrame,
  }) : viewFrame = viewFrame ?? frame;
  static const hidden = SystemWebViewLayout(Rect.zero, Rect.zero);
  final Rect frame, clip;

  /// Original Flutter view coordinates for SDK queries; never sent to GTK.
  final Rect viewFrame;

  /// Keep the mapped GTK input surface while Flutter paints a passive overlay
  /// over the private report snapshot. Interactive overlays still hide it.
  final bool paintOccluded;
  bool get visible => !frame.isEmpty && !clip.isEmpty;
  Map<String, Object> get data => {
    'frame': [frame.left, frame.top, frame.width, frame.height],
    'clip': [clip.left, clip.top, clip.width, clip.height],
    'paintOccluded': paintOccluded,
  };

  /// A rectangular GTK child may sit below a rounded Flutter ancestor only
  /// when its entire original frame fits the actual RRect's safe inner box.
  /// This accepts no curved edge, custom shape, rotation or perspective.
  static Rect? roundedClipForFrame({
    required Rect frameInClip,
    required RRect clip,
    required Matrix4 clipToView,
  }) {
    if (!frameInClip.isFinite ||
        frameInClip.isEmpty ||
        !clip.outerRect.isFinite ||
        clip.outerRect.isEmpty ||
        [
          clip.tlRadiusX,
          clip.tlRadiusY,
          clip.trRadiusX,
          clip.trRadiusY,
          clip.blRadiusX,
          clip.blRadiusY,
          clip.brRadiusX,
          clip.brRadiusY,
        ].any((v) => !v.isFinite || v < 0))
      return null;
    const identity = <double>[1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1];
    for (var i = 0; i < 16; i++) {
      final value = clipToView.storage[i];
      if (!value.isFinite ||
          (i != 12 && i != 13 && (value - identity[i]).abs() > 1e-7))
        return null;
    }
    final safe = clip.scaleRadii().safeInnerRect;
    if (safe.isEmpty ||
        frameInClip.left < safe.left ||
        frameInClip.top < safe.top ||
        frameInClip.right > safe.right ||
        frameInClip.bottom > safe.bottom)
      return null;
    return clip.outerRect.shift(
      Offset(clipToView.storage[12], clipToView.storage[13]),
    );
  }

  static SystemWebViewLayout resolve({
    required Rect local,
    required Matrix4 transform,
    required Rect viewport,
    required Iterable<Rect> clips,
    required double scale,
    bool Function(Rect viewLogicalBounds)? isOccluded,
    bool Function(Rect viewLogicalBounds)? isPaintOccluded,
  }) {
    if (!local.isFinite || local.isEmpty || !scale.isFinite || scale <= 0) {
      return hidden;
    }
    // The native GTK widget can represent translations. A bounding box is not
    // sufficient for rotations, perspective, mirroring, or Flutter scaling.
    const identity = <double>[1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1];
    for (var i = 0; i < 16; i++) {
      final value = transform.storage[i];
      if (!value.isFinite ||
          (i != 12 && i != 13 && (value - identity[i]).abs() > 1e-7)) {
        return hidden;
      }
    }
    final frame = local.shift(
      Offset(transform.storage[12], transform.storage[13]),
    );
    var clip = frame.intersect(viewport);
    for (final value in clips) {
      if (!value.isFinite) return hidden;
      clip = clip.intersect(value);
    }
    if (clip.isEmpty) return hidden;
    final blocked = isOccluded?.call(frame) ?? false;
    Rect convert(Rect r) => Rect.fromLTWH(
      r.left * scale,
      r.top * scale,
      r.width * scale,
      r.height * scale,
    );
    final result = SystemWebViewLayout(
      convert(frame),
      blocked ? Rect.zero : convert(clip),
      paintOccluded: !blocked && (isPaintOccluded?.call(frame) ?? false),
      viewFrame: frame,
    );
    if ([result.frame, result.clip].any(
      (r) => [r.left, r.top, r.right, r.bottom].any((n) => n.abs() > 1000000),
    )) {
      return hidden;
    }
    return result;
  }

  @override
  bool operator ==(Object other) =>
      other is SystemWebViewLayout &&
      other.frame == frame &&
      other.clip == clip &&
      other.paintOccluded == paintOccluded &&
      other.viewFrame == viewFrame;
  @override
  int get hashCode => Object.hash(frame, clip, paintOccluded, viewFrame);
}
