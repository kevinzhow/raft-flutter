import 'package:flutter/rendering.dart';

/// GTK logical coordinates, rather than document CSS or physical pixels.
/// Unsupported transforms and clips hide the native view instead of letting
/// native painting or pointer input escape the Flutter content rectangle.
class SystemWebViewLayout {
  const SystemWebViewLayout(this.frame, this.clip);
  static const hidden = SystemWebViewLayout(Rect.zero, Rect.zero);
  final Rect frame, clip;
  bool get visible => !frame.isEmpty && !clip.isEmpty;
  Map<String, Object> get data => {
    'frame': [frame.left, frame.top, frame.width, frame.height],
    'clip': [clip.left, clip.top, clip.width, clip.height],
  };

  static SystemWebViewLayout resolve({
    required Rect local,
    required Matrix4 transform,
    required Rect viewport,
    required Iterable<Rect> clips,
    required double scale,
    bool Function(Rect viewLogicalBounds)? isOccluded,
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
    if (clip.isEmpty || isOccluded?.call(frame) == true) return hidden;
    Rect convert(Rect r) => Rect.fromLTWH(
      r.left * scale,
      r.top * scale,
      r.width * scale,
      r.height * scale,
    );
    final result = SystemWebViewLayout(convert(frame), convert(clip));
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
      other.clip == clip;
  @override
  int get hashCode => Object.hash(frame, clip);
}
