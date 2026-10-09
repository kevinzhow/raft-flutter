// Source: message/SelectModeToolbar.tsx (26f77ef), not a generic toolbar.
// It consumes the generated raft-ui Button sizes/variants and shared roles.
import 'package:flutter/material.dart';

import 'recipes/button_variants.g.dart';
import 'recipes/recipe_runtime.dart';
import 'theme.dart';
import 'recipe_surface.dart';

class RaftSelectionToolbarRecipe {
  const RaftSelectionToolbarRecipe(this.tokens, {required this.viewportWidth});
  final RaftTokens tokens;
  final double viewportWidth;
  EdgeInsets get inset => const EdgeInsets.all(8);
  double get gap => viewportWidth >= 640 ? 6 : 4;
  Color get background =>
      tokens.colors[tokens.brutal ? 'color-soft-signal' : 'primary-soft']!;
  Color get border =>
      tokens.brutal ? Colors.black : tokens.colors['primary-edge']!;
  double get borderWidth => tokens.brutal ? 2 : 1;
  TextStyle get count => TextStyle(
    fontFamily: tokens.monoFont,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w700,
    color: (tokens.brutal ? Colors.black : tokens.colors['primary-strong']!)
        .withValues(alpha: .7),
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Native intrinsic label measurement follows the actual generated Button
  /// border/padding/icon/gap recipe. No width is pinned to a screenshot case.
  double buttonWidth(
    BuildContext context,
    String label, {
    bool compact = false,
    bool accent = false,
  }) {
    final rt = tokens.recipeTokens;
    final s = RaftButtonRecipe.resolve(
      theme: tokens.recipeTheme,
      variant: accent
          ? RaftButtonRecipeVariant.accent
          : RaftButtonRecipeVariant.outline,
      size: compact ? RaftButtonRecipeSize.iconSm : RaftButtonRecipeSize.sm,
      states: tokens.recipeStates(extra: [RaftRecipeStates.iconInlineStart]),
      tokens: rt,
    ).root;
    if (s.width != null) return s.width!;
    final p = TextPainter(
      text: TextSpan(text: label, style: s.text(rt)),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final icon = s.target("& svg:not([class*='size-'])")?.width ?? 16;
    final width =
        p.width +
        icon +
        (s.columnGap ?? 0) +
        s.padding.horizontal +
        (s
                .border(rt)
                ?.dimensions
                .resolve(Directionality.of(context))
                .horizontal ??
            0);
    p.dispose();
    return width;
  }
}
