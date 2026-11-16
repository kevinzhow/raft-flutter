import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// raft-ui `--mi-header-mask`: while the hover toolbar shows, the header fades
/// out under it, `linear-gradient(to left, transparent toolbarW+8,
/// black toolbarW+20)`. [toolbarWidth] null leaves the header unmasked and
/// costs no layer; the widget stays mounted either way, so the header's state
/// survives the toolbar coming and going.
class RaftMessageHeaderMask extends SingleChildRenderObjectWidget {
  const RaftMessageHeaderMask({super.key, this.toolbarWidth, super.child});

  /// The toolbar's width, or null when it is not shown.
  final double? toolbarWidth;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderHeaderMask(toolbarWidth);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderHeaderMask renderObject,
  ) => renderObject.toolbarWidth = toolbarWidth;
}

class _RenderHeaderMask extends RenderProxyBox {
  _RenderHeaderMask(this._toolbarWidth);
  double? _toolbarWidth;
  final _handle = LayerHandle<ShaderMaskLayer>();

  set toolbarWidth(double? value) {
    if (value == _toolbarWidth) return;
    final compositingChanged = (value == null) != (_toolbarWidth == null);
    _toolbarWidth = value;
    if (compositingChanged) markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => _toolbarWidth != null && child != null;

  @override
  void paint(PaintingContext context, Offset offset) {
    final width = _toolbarWidth;
    if (child == null) return;
    if (width == null) {
      _handle.layer = null;
      super.paint(context, offset);
      return;
    }
    final fade = width + 20;
    final shader = ui.Gradient.linear(
      Offset(size.width, 0),
      Offset(size.width - fade, 0),
      const [Color(0x00000000), Color(0x00000000), Color(0xFF000000)],
      [0, (width + 8) / fade, 1],
    );
    final layer = (_handle.layer ??= ShaderMaskLayer(
      shader: shader,
      maskRect: offset & size,
      blendMode: BlendMode.dstIn,
    ));
    layer
      ..shader = shader
      ..maskRect = offset & size
      ..blendMode = BlendMode.dstIn;
    context.pushLayer(layer, super.paint, offset);
  }

  @override
  void dispose() {
    _handle.layer = null;
    super.dispose();
  }
}
