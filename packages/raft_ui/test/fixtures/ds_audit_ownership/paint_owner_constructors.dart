// Resolved constructor ownership; names alone are never framework evidence.
import 'package:flutter/widgets.dart' as fw;
import 'package:flutter/rendering.dart' as render;

class CustomPainter {
  const CustomPainter();
}

Object unrelatedConstruction() => const CustomPainter();

class CanonicalPaintWidget extends fw.StatelessWidget {
  const CanonicalPaintWidget({super.key});
  @override
  fw.Widget build(fw.BuildContext context) => fw.CustomPaint(
    painter: const _RealPainter(),
    foregroundPainter: const _RealPainter.named(),
  );
}

class AnnotationOnlyPaintWidget extends fw.StatelessWidget {
  const AnnotationOnlyPaintWidget({super.key, this.marker});
  final _RealPainter? marker;
  @override
  fw.Widget build(fw.BuildContext context) => const fw.SizedBox.shrink();
}

class _RealPainter extends fw.CustomPainter {
  const _RealPainter();
  const _RealPainter.named();
  @override
  void paint(fw.Canvas canvas, fw.Size size) {}
  @override
  bool shouldRepaint(covariant _RealPainter oldDelegate) => false;
}

class StatefulMarker extends fw.StatefulWidget {
  const StatefulMarker({super.key});
  @override
  fw.State<StatefulMarker> createState() => _PaintState();
}

class _PaintState extends fw.State<StatefulMarker> {
  @override
  fw.Widget build(fw.BuildContext context) => const fw.SizedBox.shrink();
}

class RenderMarker extends fw.LeafRenderObjectWidget {
  const RenderMarker({super.key});
  @override
  fw.RenderObject createRenderObject(fw.BuildContext context) => _RealRender();
}

class _RealRender extends render.RenderProxyBox {}
