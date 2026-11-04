import 'package:flutter/rendering.dart';

/// Paints outer box-shadows clipped to the outside of the border box (CSS
/// semantics); use behind a translucent box.
class RaftOuterShadowPainter extends CustomPainter {
  const RaftOuterShadowPainter(
    this.shadows,
    this.radius, {
    this.circle = false,
    this.cssGeometry = false,
    this.opaqueBackdrop,
    this.compositeOnOpaque,
    this.devicePixelRatio = 1,
    this.pixelAligned,
  });
  final List<BoxShadow> shadows;
  final BorderRadius radius;
  final bool circle;

  /// Draw sharp ring layers as one shape-minus-box path (the Raft look).
  final bool cssGeometry;

  /// Optional CSS byte composition for foundation sharp rings over a known
  /// opaque surface. The component supplies its existing compositor; this
  /// geometry layer does not define color arithmetic or choose theme tokens.
  final Color? opaqueBackdrop;
  final Color Function(Color, Color)? compositeOnOpaque;
  final double devicePixelRatio;
  final bool Function()? pixelAligned;

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
    _paintSharpStraightBands(canvas, box);
  }

  void _paintSharpStraightBands(Canvas canvas, RRect box) {
    final composite = compositeOnOpaque;
    final backdrop = opaqueBackdrop;
    final dpr = devicePixelRatio;
    if (!cssGeometry ||
        circle ||
        composite == null ||
        backdrop?.a != 1 ||
        !dpr.isFinite ||
        dpr <= 0 ||
        dpr != dpr.roundToDouble())
      return;
    if (pixelAligned?.call() != true) return;
    final visible = shadows.where((s) => s.color.a > 0).toList();
    if (visible.isEmpty ||
        visible.any(
          (s) =>
              s.blurRadius != 0 ||
              s.offset != Offset.zero ||
              s.spreadRadius <= 0,
        ))
      return;
    // A transformed/fractionally placed surface has a different coverage
    // problem. Keep the original complete vector path for those surfaces.
    final matrix = canvas.getTransform();
    for (var i = 0; i < 16; i++) {
      if (i == 12 || i == 13) continue;
      if (matrix[i] != (i % 5 == 0 ? 1 : 0)) return;
    }
    bool aligned(double v) => (v * dpr - (v * dpr).round()).abs() < 1e-7;
    if (!aligned(matrix[12]) ||
        !aligned(matrix[13]) ||
        !aligned(box.width) ||
        !aligned(box.height))
      return;
    final extent = visible
        .map((s) => s.spreadRadius * dpr)
        .reduce((a, b) => a > b ? a : b)
        .ceil();
    if (extent > 16) return;
    double ceilPixel(double v) => (v * dpr).ceil() / dpr;
    double floorPixel(double v) => (v * dpr).floor() / dpr;
    for (var band = 0; band < extent; band++) {
      var color = backdrop!;
      // Each long straight physical pixel has exact area coverage from the
      // specified spread: 1.5 CSS px gives [1,.5] at DPR1, [1,1,1] at DPR2.
      // Blink's mask scales the 8-bit source alpha with truncation. Compose
      // every covering layer in its existing back-to-front paint order.
      for (final s in visible) {
        final coverage = (s.spreadRadius * dpr - band).clamp(0.0, 1.0);
        final alpha = ((s.color.a * 255).round() * coverage).floor();
        color = composite(s.color.withValues(alpha: alpha / 255), color);
      }
      final paint = Paint()
        ..color = color
        ..isAntiAlias = false;
      final inner = band / dpr, outer = (band + 1) / dpr;
      // Rounded arcs retain the original vector coverage. Only complete
      // straight pixel bands between their tangent points are recomposited.
      canvas.drawRect(
        Rect.fromLTRB(
          ceilPixel(box.left + box.tlRadiusX),
          box.top - outer,
          floorPixel(box.right - box.trRadiusX),
          box.top - inner,
        ),
        paint,
      );
      canvas.drawRect(
        Rect.fromLTRB(
          ceilPixel(box.left + box.blRadiusX),
          box.bottom + inner,
          floorPixel(box.right - box.brRadiusX),
          box.bottom + outer,
        ),
        paint,
      );
      canvas.drawRect(
        Rect.fromLTRB(
          box.left - outer,
          ceilPixel(box.top + box.tlRadiusY),
          box.left - inner,
          floorPixel(box.bottom - box.blRadiusY),
        ),
        paint,
      );
      canvas.drawRect(
        Rect.fromLTRB(
          box.right + inner,
          ceilPixel(box.top + box.trRadiusY),
          box.right + outer,
          floorPixel(box.bottom - box.brRadiusY),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(RaftOuterShadowPainter old) =>
      old.shadows != shadows ||
      old.radius != radius ||
      old.circle != circle ||
      old.cssGeometry != cssGeometry ||
      old.opaqueBackdrop != opaqueBackdrop ||
      old.compositeOnOpaque != compositeOnOpaque ||
      old.devicePixelRatio != devicePixelRatio;
}
