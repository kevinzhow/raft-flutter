import 'package:flutter/widgets.dart';

class RaftDashedRoundedPainter extends CustomPainter {
  const RaftDashedRoundedPainter({
    required this.color,
    required this.width,
    required this.radius,
  });
  final Color color;
  final double width, radius;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..style = PaintingStyle.stroke;
    final rect = Rect.fromLTWH(
      0,
      0,
      size.width,
      size.height,
    ).deflate(width / 2);
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(radius - width / 2)),
      );
    final dash = width * 3;
    for (final metric in path.computeMetrics()) {
      final count = (metric.length / (dash * 2)).round().clamp(1, 100000);
      final step = metric.length / count;
      for (var i = 0; i < count; i++) {
        canvas.drawPath(metric.extractPath(i * step, i * step + dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(RaftDashedRoundedPainter old) =>
      old.color != color || old.width != width || old.radius != radius;
}
