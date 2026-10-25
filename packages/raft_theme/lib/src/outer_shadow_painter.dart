import 'package:flutter/rendering.dart';

/// Paints outer box-shadows clipped to the outside of the border box (CSS
/// semantics); use behind a translucent box.
class RaftOuterShadowPainter extends CustomPainter {
  const RaftOuterShadowPainter(
    this.shadows,
    this.radius, {
    this.circle = false,
  });
  final List<BoxShadow> shadows;
  final BorderRadius radius;
  final bool circle;

  @override
  void paint(Canvas canvas, Size size) {
    if (shadows.isEmpty) return;
    final rect = Offset.zero & size;
    final box = circle
        ? RRect.fromRectAndRadius(rect, Radius.circular(size.shortestSide / 2))
        : radius.toRRect(rect).scaleRadii();
    canvas.save();
    canvas.clipPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(rect.inflate(1e4))
        ..addRRect(box),
    );
    for (final s in shadows) {
      final shape = box.shift(s.offset).inflate(s.spreadRadius);
      canvas.drawRRect(shape, s.toPaint());
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(RaftOuterShadowPainter old) =>
      old.shadows != shadows || old.radius != radius || old.circle != circle;
}
