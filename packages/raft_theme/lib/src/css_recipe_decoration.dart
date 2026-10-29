import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'outer_shadow_painter.dart';

/// Reduces CSS corner radii against the actual border box in double precision.
/// Tailwind `rounded-full` resolves to Chrome's max float; passing it to Skia
/// before this CSS overlap reduction overflows float arithmetic.
BorderRadius raftCssRadiusForBox(
  BorderRadiusGeometry radius,
  Rect box,
  TextDirection? direction,
) {
  final r = radius.resolve(direction).toRRect(box).scaleRadii();
  return BorderRadius.only(
    topLeft: Radius.elliptical(r.tlRadiusX, r.tlRadiusY),
    topRight: Radius.elliptical(r.trRadiusX, r.trRadiusY),
    bottomLeft: Radius.elliptical(r.blRadiusX, r.blRadiusY),
    bottomRight: Radius.elliptical(r.brRadiusX, r.brRadiusY),
  );
}

/// Recipe decoration whose paint, clip and hit geometry follows CSS radius
/// overlap reduction at the actual size, including caller size overrides.
class RaftRecipeDecoration extends BoxDecoration {
  const RaftRecipeDecoration({
    super.color,
    super.image,
    super.border,
    super.borderRadius,
    super.boxShadow,
    super.gradient,
    super.backgroundBlendMode,
    super.shape,
    this.cssGeometry = false,
  });

  /// The Raft look's CSS geometry (raft-ui 0.7.0): `overflow: hidden` clips to the
  /// padding box, and sharp ring layers are one anti-aliased path. Off for the
  /// frozen Elegant and Brutal looks, whose pixels do not change.
  final bool cssGeometry;

  factory RaftRecipeDecoration.from(BoxDecoration d, {bool? cssGeometry}) =>
      RaftRecipeDecoration(
        cssGeometry:
            cssGeometry ?? (d is RaftRecipeDecoration && d.cssGeometry),
        color: d.color,
        image: d.image,
        border: d.border,
        borderRadius: d.borderRadius,
        boxShadow: d.boxShadow,
        gradient: d.gradient,
        backgroundBlendMode: d.backgroundBlendMode,
        shape: d.shape,
      );

  @override
  BoxDecoration? lerpFrom(Decoration? a, double t) {
    final value = super.lerpFrom(a, t);
    return value == null
        ? null
        : RaftRecipeDecoration.from(value, cssGeometry: cssGeometry);
  }

  @override
  BoxDecoration? lerpTo(Decoration? b, double t) {
    final value = super.lerpTo(b, t);
    return value == null
        ? null
        : RaftRecipeDecoration.from(value, cssGeometry: cssGeometry);
  }

  @override
  BoxDecoration copyWith({
    Color? color,
    DecorationImage? image,
    BoxBorder? border,
    BorderRadiusGeometry? borderRadius,
    List<BoxShadow>? boxShadow,
    Gradient? gradient,
    BlendMode? backgroundBlendMode,
    BoxShape? shape,
  }) => RaftRecipeDecoration.from(
    cssGeometry: cssGeometry,
    super.copyWith(
      color: color,
      image: image,
      border: border,
      borderRadius: borderRadius,
      boxShadow: boxShadow,
      gradient: gradient,
      backgroundBlendMode: backgroundBlendMode,
      shape: shape,
    ),
  );

  BoxDecoration forBox(Rect box, TextDirection? direction) => BoxDecoration(
    color: color,
    image: image,
    border: border,
    borderRadius: borderRadius == null
        ? null
        : raftCssRadiusForBox(borderRadius!, box, direction),
    boxShadow: boxShadow,
    gradient: gradient,
    backgroundBlendMode: backgroundBlendMode,
    shape: shape,
  );

  /// CSS `overflow: hidden` clips to the padding box: the border box inset by
  /// the border, each corner radius reduced by the border on its sides. A clip
  /// to the border box would let a child's fill paint over the border along the
  /// rounded corners (the border looks cut off at the arc).
  @override
  Path getClipPath(Rect rect, TextDirection direction) {
    final box = forBox(rect, direction);
    final radius = box.borderRadius?.resolve(direction);
    final width = border?.dimensions.resolve(direction) ?? EdgeInsets.zero;
    if (!cssGeometry ||
        shape == BoxShape.circle ||
        radius == null ||
        width == EdgeInsets.zero) {
      return box.getClipPath(rect, direction);
    }
    Radius shrink(Radius r, double x, double y) =>
        // ds-allow: the padding-box radius is the border radius minus the border
        Radius.elliptical(math.max(0, r.x - x), math.max(0, r.y - y));
    return Path()..addRRect(
      RRect.fromRectAndCorners(
        width.deflateRect(rect),
        topLeft: shrink(radius.topLeft, width.left, width.top),
        topRight: shrink(radius.topRight, width.right, width.top),
        bottomLeft: shrink(radius.bottomLeft, width.left, width.bottom),
        bottomRight: shrink(radius.bottomRight, width.right, width.bottom),
      ),
    );
  }

  @override
  bool hitTest(Size size, Offset position, {TextDirection? textDirection}) =>
      forBox(
        Offset.zero & size,
        textDirection,
      ).hitTest(size, position, textDirection: textDirection);
  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _RaftRecipePainter(this, onChanged);
}

class _RaftRecipePainter extends BoxPainter {
  _RaftRecipePainter(this.decoration, super.onChanged);
  final RaftRecipeDecoration decoration;
  BoxPainter? painter;
  Size? size;
  TextDirection? direction;
  BorderRadius radius = BorderRadius.zero;
  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    if (painter == null ||
        size != configuration.size ||
        direction != configuration.textDirection) {
      painter?.dispose();
      size = configuration.size;
      direction = configuration.textDirection;
      final box = decoration.forBox(Offset.zero & size!, direction);
      radius = box.borderRadius?.resolve(direction) ?? BorderRadius.zero;
      // CSS outer box-shadows paint only outside the border box. Flutter
      // paints a BoxShadow as a full shape beneath the box, so a translucent
      // or transparent fill would show the shadow through it.
      painter = box.copyWith(boxShadow: const []).createBoxPainter(onChanged);
    }
    final shadows = decoration.boxShadow;
    if (shadows != null && shadows.isNotEmpty) {
      canvas.save();
      canvas.translate(offset.dx, offset.dy);
      RaftOuterShadowPainter(
        shadows,
        radius,
        circle: decoration.shape == BoxShape.circle,
        cssGeometry: decoration.cssGeometry,
      ).paint(canvas, configuration.size!);
      canvas.restore();
    }
    painter!.paint(canvas, offset, configuration);
  }

  @override
  void dispose() {
    painter?.dispose();
    super.dispose();
  }
}
