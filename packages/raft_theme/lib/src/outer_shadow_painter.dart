import 'package:flutter/rendering.dart';

/// Paints outer box-shadows clipped to the outside of the border box (CSS
/// semantics); use behind a translucent box.
class RaftOuterShadowPainter extends CustomPainter {
  const RaftOuterShadowPainter(
    this.shadows,
    this.radius, {
    this.circle = false,
    this.cssGeometry = false,
  });
  final List<BoxShadow> shadows;
  final BorderRadius radius;
  final bool circle;

  /// Draw sharp ring layers as one shape-minus-box path (the Raft look).
  final bool cssGeometry;

  @override
  void paint(Canvas canvas, Size size) {
    if (shadows.isEmpty) return;
    final rect = Offset.zero & size;
    final box = circle
        ? RRect.fromRectAndRadius(rect, Radius.circular(size.shortestSide / 2))
        : radius.toRRect(rect).scaleRadii();
    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(rect.inflate(1e4))
      ..addRRect(box);
    final boxPath = Path()..addRRect(box);
    for (final s in shadows) {
      final shape = box.shift(s.offset).inflate(s.spreadRadius);
      if (cssGeometry && s.blurRadius <= 0) {
        // A sharp layer (`ring-1`, the focus ring) is the shape minus the box,
        // drawn as one anti-aliased path. Clipping it to the outside of the
        // box as well anti-aliases the curve twice and thins the stroke along
        // the corner arcs.
        canvas.drawPath(
          Path.combine(
            PathOperation.difference,
            Path()..addRRect(shape),
            boxPath,
          ),
          s.toPaint(),
        );
        continue;
      }
      canvas
        ..save()
        ..clipPath(outside)
        ..drawRRect(shape, s.toPaint())
        ..restore();
    }
  }

  @override
  bool shouldRepaint(RaftOuterShadowPainter old) =>
      old.shadows != shadows ||
      old.radius != radius ||
      old.circle != circle ||
      old.cssGeometry != cssGeometry;
}
