import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'recipe_surface.dart';
import 'recipes/app_rail.g.dart';
import 'recipes/status.g.dart';
import 'recipes/recipe_runtime.dart';
import 'theme.dart';

/// Source AppRailItemAttention: an 8px Status plus Elegant icon tint/mask.
/// The caller owns whether attention is present and whether the active entry
/// suppresses it. It is independent of the numeric AppRailItemBadge slot.
class RaftRailAttention extends StatelessWidget {
  const RaftRailAttention({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final rail = RaftAppRailRecipe.resolve(
      theme: t.recipeTheme,
      states: t.recipeStates(extra: const ['data-variant=primary']),
      tokens: t.recipeTokens,
    );
    final status = RaftStatusRecipe.resolve(
      theme: t.recipeTheme,
      size: RaftStatusRecipeSize.sm,
      variant: t.brutal
          ? RaftStatusRecipeVariant.accent
          : RaftStatusRecipeVariant.primary,
      attention: true,
      states: t.recipeStates(),
      tokens: t.recipeTokens,
    ).root;
    final mergedIndicator = RaftSlotStyle(
      {...status.properties, ...rail.itemIndicator.properties},
      {...status.targets, ...rail.itemIndicator.targets},
      [...status.classes, ...rail.itemIndicator.classes],
      t.recipeTokens,
    );
    final indicator = _linearIndicator(mergedIndicator, t.recipeTokens);
    final mask = rail.itemAttentionMask;
    final gradient = mask['mask-image'];
    final tint = mask.foreground(t.recipeTokens);
    return IgnorePointer(
      child: ExcludeSemantics(
        child: Stack(
          clipBehavior: Clip.none,
          fit: StackFit.expand,
          children: [
            if (!t.brutal && gradient is CssFunction && tint != null)
              ShaderMask(
                key: const ValueKey('rail-attention-mask'),
                blendMode: BlendMode.dstIn,
                shaderCallback: (bounds) => _radialMask(gradient, bounds),
                child: Stack(
                  fit: StackFit.expand,
                  clipBehavior: Clip.none,
                  children: [
                    if (_shadow(mask, t.recipeTokens) case final shadow?)
                      Transform.translate(
                        offset: shadow.$3,
                        child: ImageFiltered(
                          imageFilter: ui.ImageFilter.blur(
                            sigmaX: shadow.$2,
                            sigmaY: shadow.$2,
                          ),
                          child: IconTheme.merge(
                            data: IconThemeData(color: shadow.$1),
                            child: child,
                          ),
                        ),
                      ),
                    IconTheme.merge(
                      data: IconThemeData(color: tint),
                      child: child,
                    ),
                  ],
                ),
              ),
            Positioned(
              right: rail.itemIndicator.length('right') ?? 0,
              top: rail.itemIndicator.length('top') ?? 0,
              child: RaftRecipeBox(
                key: const ValueKey('rail-attention-indicator'),
                style: indicator,
                tokens: t.recipeTokens,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

ui.Shader _radialMask(CssFunction gradient, Rect bounds) {
  final origin = (gradient.args.first as CssSeq).items;
  final cx = (origin[2] as CssNum).value / 100;
  final cy = (origin[3] as CssNum).value / 100;
  final radius = math.sqrt(
    math.pow(math.max(cx, 1 - cx) * bounds.width, 2) +
        math.pow(math.max(cy, 1 - cy) * bounds.height, 2),
  );
  final colors = <Color>[], stops = <double>[];
  for (final value in gradient.args.skip(1)) {
    final stop = (value as CssSeq).items;
    final literal = stop.first as CssColor;
    // A mask consumes CSS alpha, not the source-over colour paint fit.
    final explicitAlpha = RegExp(r'/\s*([\d.]+)')
        .firstMatch(literal.source ?? '');
    final alpha = explicitAlpha == null
        ? (literal.argb >> 24) / 255
        : double.parse(explicitAlpha.group(1)!);
    colors.add(Color.fromRGBO(0, 0, 0, alpha.toDouble()));
    stops.add((stop.last as CssNum).value / 100);
  }
  return RadialGradient(
    center: Alignment(cx * 2 - 1, cy * 2 - 1),
    radius: radius / (bounds.shortestSide / 2),
    colors: colors,
    stops: stops,
  ).createShader(bounds);
}

(Color, double, Offset)? _shadow(
  RaftSlotStyle style,
  RaftTokenResolver tokens,
) {
  final value = style['--tw-drop-shadow-size'];
  if (value is! CssFunction || value.name != 'drop-shadow') return null;
  final values = (value.args.single as CssSeq).items;
  final color = values.last is CssVar
      ? (values.last as CssVar).fallback
      : values.last;
  final ref = RaftColorRef.fromCss(color);
  if (ref == null) return null;
  return (
    ref.resolve(tokens),
    (values[2] as CssNum).value,
    Offset((values[0] as CssNum).value, (values[1] as CssNum).value),
  );
}

// The shared runtime currently handles oklab/oklch mixes. This Source slot uses
// linear sRGB; project its generated expression locally without changing the
// colour engine for unrelated controls.
RaftSlotStyle _linearIndicator(RaftSlotStyle style, RaftTokenResolver tokens) {
  final mix = style.backgroundColor;
  if (mix is! RaftMixedColor || mix.space != 'srgb-linear') return style;
  final a = mix.a.resolve(tokens), b = mix.b.resolve(tokens);
  final pa = mix.pa ?? (mix.pb == null ? .5 : 1 - mix.pb!);
  final pb = mix.pb ?? (mix.pa == null ? .5 : 1 - mix.pa!);
  final sum = pa + pb;
  final aa = a.a * pa / sum, ab = b.a * pb / sum;
  final alpha = aa + ab;
  double linear(double value) => value <= .04045
      ? value / 12.92
      : math.pow((value + .055) / 1.055, 2.4).toDouble();
  double channel(double x, double y) {
    final value = (linear(x) * aa + linear(y) * ab) / alpha;
    return value <= .0031308
        ? value * 12.92
        : 1.055 * math.pow(value, 1 / 2.4) - .055;
  }

  final color = Color.from(
    alpha: alpha * math.min(sum, 1),
    red: channel(a.r, b.r),
    green: channel(a.g, b.g),
    blue: channel(a.b, b.b),
  );
  return RaftSlotStyle(
    {...style.properties, 'background-color': CssColor(color.toARGB32())},
    style.targets,
    style.classes,
    tokens,
  );
}
