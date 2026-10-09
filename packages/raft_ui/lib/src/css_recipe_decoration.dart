import 'package:flutter/painting.dart';

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
  });

  factory RaftRecipeDecoration.from(BoxDecoration d) => RaftRecipeDecoration(
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
    return value == null ? null : RaftRecipeDecoration.from(value);
  }

  @override
  BoxDecoration? lerpTo(Decoration? b, double t) {
    final value = super.lerpTo(b, t);
    return value == null ? null : RaftRecipeDecoration.from(value);
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

  @override
  Path getClipPath(Rect rect, TextDirection direction) =>
      forBox(rect, direction).getClipPath(rect, direction);
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
  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    if (painter == null ||
        size != configuration.size ||
        direction != configuration.textDirection) {
      painter?.dispose();
      size = configuration.size;
      direction = configuration.textDirection;
      painter = decoration
          .forBox(Offset.zero & size!, direction)
          .createBoxPainter(onChanged);
    }
    painter!.paint(canvas, offset, configuration);
  }

  @override
  void dispose() {
    painter?.dispose();
    super.dispose();
  }
}
