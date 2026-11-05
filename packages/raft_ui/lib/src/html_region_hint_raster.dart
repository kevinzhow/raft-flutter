import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'html_region_native_types.dart';

/// Captures the existing HUD without changing its layout or repaint recipe.
/// Overflow only preserves the canonical shadow outside the widget's box.
class RaftHtmlHintRasterBoundary extends SingleChildRenderObjectWidget {
  const RaftHtmlHintRasterBoundary({
    super.key,
    required this.shadows,
    required super.child,
  });
  final List<BoxShadow> shadows;
  EdgeInsets get overflow {
    var bounds = Rect.zero;
    for (final shadow in shadows) {
      final spread = math.max(0.0, shadow.spreadRadius + shadow.blurSigma * 3);
      bounds = bounds.expandToInclude(
        Rect.fromLTWH(
          shadow.offset.dx - spread,
          shadow.offset.dy - spread,
          spread * 2,
          spread * 2,
        ),
      );
    }
    return EdgeInsets.fromLTRB(
      -bounds.left,
      -bounds.top,
      bounds.right,
      bounds.bottom,
    );
  }

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _HintRasterBoundary(overflow);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant _HintRasterBoundary renderObject,
  ) {
    if (renderObject.overflow != overflow) {
      renderObject.overflow = overflow;
      renderObject.markNeedsPaint();
    }
  }
}

class _HintRasterBoundary extends RenderRepaintBoundary {
  _HintRasterBoundary(this.overflow);
  EdgeInsets overflow;
  @override
  Rect get paintBounds => Rect.fromLTRB(
    -overflow.left,
    -overflow.top,
    size.width + overflow.right,
    size.height + overflow.bottom,
  );
  ui.Image capture(double ratio) =>
      (layer! as OffsetLayer).toImageSync(paintBounds, pixelRatio: ratio);
}

Future<RaftHtmlNativeRegionHint?> raftCaptureHtmlRegionHint(
  GlobalKey hint,
  GlobalKey pane,
) async {
  final context = hint.currentContext;
  final box = context?.findRenderObject(),
      parent = pane.currentContext?.findRenderObject();
  if (context == null ||
      box is! _HintRasterBoundary ||
      parent is! RenderBox ||
      !box.hasSize ||
      box.debugNeedsPaint)
    return null;
  final bounds = box.paintBounds;
  if (!bounds.isFinite || bounds.isEmpty) return null;
  var ratio = math.min(
    View.of(context).devicePixelRatio,
    math.min(
      8192 / math.max(bounds.width, bounds.height),
      math.sqrt(
        RaftHtmlNativeRegionHint.maximumPixels / (bounds.width * bounds.height),
      ),
    ),
  );
  if (!ratio.isFinite || ratio <= 0) return null;
  while ((bounds.width * ratio).ceil() * (bounds.height * ratio).ceil() >
      RaftHtmlNativeRegionHint.maximumPixels) {
    ratio *= .99;
  }
  final offset =
      box.localToGlobal(Offset.zero, ancestor: parent) + bounds.topLeft;
  final image = box.capture(ratio);
  Future<ByteData?> encoded;
  try {
    // The engine retains its own image reference when encoding starts. Release
    // this Dart handle immediately, including when the preview retires while
    // PNG encoding is still pending.
    encoded = image.toByteData(format: ui.ImageByteFormat.png);
  } finally {
    image.dispose();
  }
  final data = await encoded;
  if (data == null ||
      data.lengthInBytes > RaftHtmlNativeRegionHint.maximumBytes)
    return null;
  return RaftHtmlNativeRegionHint(
    png: Uint8List.fromList(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    ),
    logicalSize: bounds.size,
    logicalOffset: offset,
  );
}
