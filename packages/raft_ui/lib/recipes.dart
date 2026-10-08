/// Generated raft-ui component recipes: every tailwind-variants recipe of
/// raft-ui, evaluated with tailwind-merge and compiled by Tailwind v4, as
/// resolved style data. Regenerate with `tool/recipes/run`; tables per
/// component are in docs/component-recipes.md.
///
/// ```dart
/// final tokens = /* RaftTokenResolver bound to the token ThemeExtension */;
/// final style = RaftButtonRecipe.resolve(
///   theme: RaftRecipeTheme.elegant,
///   variant: RaftButtonRecipeVariant.primary,
///   size: RaftButtonRecipeSize.md,
///   states: RaftRecipeStates({
///     if (hovered) RaftRecipeStates.hover,
///     if (pressed) RaftRecipeStates.active,
///     if (focused) RaftRecipeStates.focusVisible,
///     if (!enabled) RaftRecipeStates.disabled,
///     if (isElegantDark) RaftRecipeStates.dark,
///   }),
///   tokens: tokens,
/// );
/// final root = style.root;
/// Opacity(
///   opacity: root.opacity ?? 1,
///   child: Transform.scale(
///     scale: root.scale ?? 1,
///     child: Container(
///       height: root.height,
///       padding: root.padding,
///       decoration: root.decoration(tokens),
///       child: DefaultTextStyle.merge(style: root.textStyle(tokens), child: label),
///     ),
///   ),
/// );
/// ```
library;

export 'src/recipes/recipe_runtime.dart';
export 'src/recipes/recipes.g.dart';
