// Paints generated raft-ui recipe slots (`Raft<Name>Recipe.resolve`) with
// Flutter primitives: the box model (border-box size, border, padding),
// background, radius, outer + inset box-shadows, opacity, translate/scale,
// the elegant `::before` sheen and the slot's text style. Primitives in this
// package build on it so every value traces to a recipe or token.
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'recipes/recipe_runtime.dart';
import 'recipes/token_binding.dart';
import 'theme.dart';
import 'tokens/tokens.dart';

extension RaftRecipeBinding on RaftTokens {
  RaftRecipeTheme get recipeTheme =>
      brutal ? RaftRecipeTheme.brutal : RaftRecipeTheme.elegant;

  RaftRecipeTokens get recipeTokens => RaftRecipeTokens(this);

  /// CSS interaction states for a recipe cascade; `dark` follows the theme.
  RaftRecipeStates recipeStates({
    bool hovered = false,
    bool pressed = false,
    bool focusVisible = false,
    bool disabled = false,
    bool ariaDisabled = false,
    bool checked = false,
    Iterable<String> extra = const [],
  }) => RaftRecipeStates({
    if (dark) RaftRecipeStates.dark,
    if (hovered) RaftRecipeStates.hover,
    if (pressed) RaftRecipeStates.active,
    if (focusVisible) ...[
      RaftRecipeStates.focusVisible,
      RaftRecipeStates.focus,
    ],
    if (disabled) RaftRecipeStates.disabled,
    if (ariaDisabled) RaftRecipeStates.ariaDisabled,
    if (checked) RaftRecipeStates.checked,
    ...extra,
  });
}

/// CSS text rendering defaults: half-leading split evenly like a CSS line box.
const TextStyle raftCssText = TextStyle(
  leadingDistribution: TextLeadingDistribution.even,
);

extension RaftSlotPaint on RaftSlotStyle {
  /// Resolved `color` (falls back to [inherited]).
  Color? foreground(RaftTokenResolver tokens, {Color? inherited}) =>
      color?.resolve(tokens, currentColor: inherited) ?? inherited;

  /// Slot text style merged over [base] (CSS inheritance), with CSS leading.
  TextStyle text(RaftTokenResolver tokens, {TextStyle? base}) {
    final inherited = base ?? const TextStyle();
    final own = textStyle(tokens, currentColor: inherited.color);
    var merged = raftCssText.merge(inherited).merge(own);
    // `line-height` in px stays absolute when font-size changes; unitless
    // values (already ratios) and inherited ratios carry over.
    final px = lineHeightPx;
    if (px != null && merged.fontSize != null) {
      merged = merged.copyWith(height: px / merged.fontSize!);
    }
    return merged.copyWith(leadingDistribution: TextLeadingDistribution.even);
  }

  /// Every shadow layer (token layers expanded) as CSS layers in CSS order.
  List<RaftCssShadow> cssShadows(
    RaftTokenResolver tokens, {
    Color? currentColor,
  }) {
    final out = <RaftCssShadow>[];
    for (final layer in boxShadow) {
      switch (layer) {
        case RaftTokenShadow(:final token):
          final resolver = tokens;
          if (resolver is RaftRecipeTokens) {
            out.addAll(_themeShadow(resolver.tokens, token.name).layers);
          } else {
            for (final s in tokens.shadow(token.name).reversed) {
              out.add(
                RaftCssShadow(
                  inset: false,
                  offset: s.offset,
                  blur: s.blurRadius,
                  spread: s.spreadRadius,
                  color: s.color,
                ),
              );
            }
          }
        case RaftLiteralShadow():
          out.add(
            RaftCssShadow(
              inset: layer.inset,
              offset: layer.offset,
              blur: layer.blur,
              spread: layer.spread,
              color: layer.color.resolve(tokens, currentColor: currentColor),
            ),
          );
      }
    }
    return out;
  }
}

RaftShadow _themeShadow(RaftTokens t, String name) {
  final s = t.themeShadows;
  return switch (RaftRecipeTokens.cssName(name)) {
    'theme-shadow-xs' || 'shadow-raft-xs' => s.xs,
    'theme-shadow-sm' || 'shadow-raft-sm' => s.sm,
    'theme-shadow-md' || 'shadow-raft-md' => s.md,
    'theme-shadow-lg' || 'shadow-raft-lg' => s.lg,
    'theme-shadow-xl' || 'shadow-raft-xl' => s.xl,
    final other => throw ArgumentError('Unknown shadow token $other'),
  };
}

/// Flutter [BoxShadow.blurRadius] whose sigma equals the CSS sigma
/// (`blur / 2`); Flutter converts with `r * 0.57735 + 0.5`.
double raftCssBlurRadius(double cssBlur) =>
    cssBlur <= 1 ? cssBlur / 2 : (cssBlur / 2 - .5) / .57735;

/// A box painted from one recipe slot.
///
/// Size follows CSS `box-sizing: border-box` (Tailwind preflight): `height`
/// / `width` include border and padding. [overrides] lets a caller apply
/// Web JSX classes layered on the recipe (e.g. `w-full`).
class RaftRecipeBox extends StatelessWidget {
  const RaftRecipeBox({
    super.key,
    required this.style,
    required this.tokens,
    this.child,
    this.width,
    this.height,
    this.padding,
    this.alignment,
    this.clip = false,
    this.applyText = true,
    this.applyOpacity = true,
    this.applyTransform = true,
    this.decorationOverride,
  });

  final RaftSlotStyle style;
  final RaftTokenResolver tokens;
  final Widget? child;

  /// Overrides for the slot's own width/height/padding.
  final double? width, height;
  final EdgeInsets? padding;
  final AlignmentGeometry? alignment;
  final bool clip;
  final bool applyText, applyOpacity, applyTransform;
  final BoxDecoration Function(BoxDecoration)? decorationOverride;

  @override
  Widget build(BuildContext context) {
    final inherited = DefaultTextStyle.of(context).style;
    final textStyle = style.text(tokens, base: inherited);
    final current = textStyle.color;
    final layers = style.cssShadows(tokens, currentColor: current);
    var decoration = BoxDecoration(
      color: style.backgroundColor?.resolve(tokens, currentColor: current),
      border: style.border(tokens, currentColor: current),
      borderRadius: style.borderRadius,
      boxShadow: [
        for (final l in layers.reversed)
          if (!l.inset)
            BoxShadow(
              color: l.color,
              offset: l.offset,
              blurRadius: raftCssBlurRadius(l.blur),
              spreadRadius: l.spread,
            ),
      ],
    );
    if (decorationOverride != null) decoration = decorationOverride!(decoration);
    // CSS outer box-shadows never paint under the border box (a translucent
    // background must not reveal them), unlike Flutter's BoxDecoration.
    final outerShadows = decoration.boxShadow ?? const <BoxShadow>[];
    decoration = BoxDecoration(
      color: decoration.color,
      border: decoration.border,
      borderRadius: decoration.borderRadius,
      shape: decoration.shape,
    );
    final inset = [for (final l in layers) if (l.inset) l];
    final before = style.before;
    final sheen = before?['background-image'];
    Widget? content = child;
    if (content != null && applyText) {
      content = DefaultTextStyle(
        style: textStyle,
        child: IconTheme.merge(
          data: IconThemeData(color: current),
          child: content,
        ),
      );
    }
    final radius = style.borderRadius ?? BorderRadius.zero;
    final w = width ?? style.width;
    final h = height ?? style.height;
    // A fixed CSS height smaller than padding + content lets the content
    // overflow, centred (flex `align-items: center`), instead of clipping.
    if (content != null && h != null) content = RaftCssOverflowY(child: content);
    Widget box = Container(
      width: w,
      height: h,
      constraints: BoxConstraints(
        minWidth: style.minWidth ?? 0,
        minHeight: style.minHeight ?? 0,
        maxWidth: style.maxWidth ?? double.infinity,
        maxHeight: style.maxHeight ?? double.infinity,
      ),
      alignment: alignment,
      padding: padding ?? style.padding,
      decoration: decoration,
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      foregroundDecoration: inset.isEmpty && sheen == null
          ? null
          : _InsetDecoration(
              inset,
              radius,
              sheen == null ? null : _sheenGradient(sheen),
              decoration.border?.dimensions.resolve(TextDirection.ltr) ??
                  EdgeInsets.zero,
            ),
      child: content,
    );
    if (outerShadows.isNotEmpty) {
      box = CustomPaint(
        painter: RaftOuterShadowPainter(
          outerShadows,
          decoration.borderRadius?.resolve(TextDirection.ltr) ??
              BorderRadius.zero,
          circle: decoration.shape == BoxShape.circle,
        ),
        child: box,
      );
    }
    if (applyTransform) {
      final translate = style.translate ?? Offset.zero;
      final scale = style.scale ?? 1;
      if (translate != Offset.zero || scale != 1) {
        box = Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..translateByDouble(translate.dx, translate.dy, 0, 1)
            ..scaleByDouble(scale, scale, 1, 1),
          child: box,
        );
      }
    }
    final opacity = style.opacity;
    if (applyOpacity && opacity != null && opacity < 1) {
      box = Opacity(opacity: opacity, child: box);
    }
    return box;
  }
}

/// `linear-gradient(in oklab 180deg, oklab(100% 0 0 / 8%) 0%, oklab(0% 0 0 / 0%) 100%)`
/// style sheens on elegant controls (`::before`, inset 0).
Gradient? _sheenGradient(CssValue v) {
  final text = v.toString();
  final alphas = RegExp(r'/\s*([\d.]+)%').allMatches(text).toList();
  if (!text.contains('linear-gradient') || alphas.length < 2) return null;
  final top = double.parse(alphas.first.group(1)!) / 100;
  final light = text.contains('oklab(100%');
  final base = light ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
  return LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [base.withValues(alpha: top), base.withValues(alpha: 0)],
  );
}

class _InsetDecoration extends Decoration {
  const _InsetDecoration(this.layers, this.radius, this.sheen, this.border);
  final List<RaftCssShadow> layers;
  final BorderRadius radius;
  final Gradient? sheen;
  final EdgeInsets border;
  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _InsetPainter(this);
}

class _InsetPainter extends BoxPainter {
  _InsetPainter(this.d);
  final _InsetDecoration d;
  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size!;
    final outer = d.radius.toRRect(offset & size);
    if (d.sheen != null) {
      canvas.drawRRect(
        outer,
        Paint()..shader = d.sheen!.createShader(offset & size),
      );
    }
    // CSS inset shadows paint inside the padding box (inside the border).
    final paddingBox = d.border.deflateRect(offset & size);
    final bw = math.max(d.border.top, d.border.left);
    Radius shrink(Radius r) =>
        Radius.circular(math.max(0, r.x - bw));
    final inner = RRect.fromRectAndCorners(
      paddingBox,
      topLeft: shrink(d.radius.topLeft),
      topRight: shrink(d.radius.topRight),
      bottomLeft: shrink(d.radius.bottomLeft),
      bottomRight: shrink(d.radius.bottomRight),
    );
    for (final l in d.layers.reversed) {
      canvas.save();
      canvas.clipRRect(inner);
      final hole = inner
          .shift(l.offset)
          .deflate(l.spread);
      final path = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(inner.outerRect.inflate(l.blur + l.spread.abs() + 20))
        ..addRRect(hole);
      final paint = Paint()..color = l.color;
      if (l.blur > 0) {
        paint.maskFilter = MaskFilter.blur(BlurStyle.normal, l.blurSigma);
      }
      canvas.drawPath(path, paint);
      canvas.restore();
    }
  }
}

/// Paints outer box-shadows clipped to the outside of the border box (CSS
/// semantics); use behind a translucent box.
class RaftOuterShadowPainter extends CustomPainter {
  const RaftOuterShadowPainter(this.shadows, this.radius, {this.circle = false});
  final List<BoxShadow> shadows;
  final BorderRadius radius;
  final bool circle;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final box = circle
        ? RRect.fromRectAndRadius(rect, Radius.circular(size.shortestSide / 2))
        : radius.toRRect(rect);
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

/// Lays its child out with unbounded height and centres it vertically in
/// the incoming height (CSS unsafe centering of an overflowing flex item);
/// width follows the child like any shrink-wrapping box.
class RaftCssOverflowY extends SingleChildRenderObjectWidget {
  const RaftCssOverflowY({super.key, super.child});
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderCssOverflowY();
}

class _RenderCssOverflowY extends RenderShiftedBox {
  _RenderCssOverflowY() : super(null);

  @override
  void performLayout() {
    final c = constraints;
    final child = this.child;
    if (child == null) {
      size = c.smallest;
      return;
    }
    child.layout(
      BoxConstraints(minWidth: c.minWidth, maxWidth: c.maxWidth),
      parentUsesSize: true,
    );
    size = c.constrain(Size(child.size.width, child.size.height));
    final data = child.parentData! as BoxParentData;
    data.offset = Offset(0, (size.height - child.size.height) / 2);
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      child?.getMinIntrinsicWidth(double.infinity) ?? 0;
  @override
  double computeMaxIntrinsicWidth(double height) =>
      child?.getMaxIntrinsicWidth(double.infinity) ?? 0;
  @override
  double computeMinIntrinsicHeight(double width) =>
      child?.getMinIntrinsicHeight(width) ?? 0;
  @override
  double computeMaxIntrinsicHeight(double width) =>
      child?.getMaxIntrinsicHeight(width) ?? 0;
}
