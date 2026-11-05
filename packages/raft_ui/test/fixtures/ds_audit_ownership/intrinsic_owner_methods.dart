// Intrinsic framework hooks are class-owned; unrelated helpers remain owners.
import 'package:flutter/widgets.dart' as fw;
import 'package:flutter/rendering.dart' as render;

class IntrinsicStatefulMarker extends fw.StatefulWidget {
  const IntrinsicStatefulMarker({super.key});
  @override
  _IntrinsicState createState() => _IntrinsicState();
}

class _IntrinsicState extends fw.State<IntrinsicStatefulMarker> {
  @override
  fw.Widget build(fw.BuildContext context) => const fw.SizedBox.shrink();
}

class RenderMarker extends fw.LeafRenderObjectWidget {
  const RenderMarker({super.key});
  @override
  fw.RenderObject createRenderObject(fw.BuildContext context) => _RealRender();
}

class _RealRender extends render.RenderProxyBox {}

class _RealPainter extends fw.CustomPainter {
  const _RealPainter();
  @override
  void paint(fw.Canvas canvas, fw.Size size) {}
  @override
  bool shouldRepaint(covariant _RealPainter oldDelegate) => false;
}

class _DelegatingPainter extends fw.CustomPainter {
  @override
  void paint(fw.Canvas canvas, fw.Size size) {
    const _RealPainter().paint(canvas, size);
  }

  Object helper() => const _RealPainter();
  void nested() {
    void drawLocal() => const _RealPainter();
    drawLocal();
  }

  @override
  bool shouldRepaint(covariant _DelegatingPainter oldDelegate) => false;
}

class _DelegatingBoxPainter extends fw.BoxPainter {
  @override
  void paint(
    fw.Canvas canvas,
    fw.Offset offset,
    fw.ImageConfiguration configuration,
  ) {
    const _RealPainter().paint(canvas, configuration.size ?? fw.Size.zero);
  }
}

class _DelegatingRender extends render.RenderProxyBox {
  @override
  void paint(render.PaintingContext context, fw.Offset offset) {
    const _RealPainter().paint(context.canvas, size);
  }
}

// Matching method names without a resolved framework superclass are not hooks.
class UnrelatedHooks {
  Object createState() => const _RealPainter();
  Object createRenderObject() => _RealRender();
  Object paint() => const _RealPainter();
}
