import 'package:flutter/widgets.dart';

import 'recipe_surface.dart';
import 'recipe_background_scope.dart';
import 'dialog_slots.dart';
import 'recipes/dialog.g.dart';
import 'recipes/dialog_surface.g.dart';
import 'recipes/recipe_router.dart' show usesLegacyRecipes;
import 'recipes/recipe_runtime.dart';
import 'theme.dart';

/// The published DialogSurface: paint and clipping only. The dialog family
/// owns content and placement. Frozen-look compositions keep their existing
/// renderers; this source component is used by the Raft look.
class RaftDialogSurface extends StatelessWidget {
  const RaftDialogSurface({super.key, required this.child, this.surfaceStyle});

  final Widget child;
  final RaftSlotStyle? surfaceStyle;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final style = raftDialogSlot(
      t,
      surfaceStyle ??
          RaftDialogSurfaceRecipe.resolve(
            states: t.recipeStates(),
            tokens: t.recipeTokens,
          ).root,
      'content',
    );
    return RaftRecipeBox(
      style: style,
      tokens: t.recipeTokens,
      clip: true,
      child: RaftRecipeBackgroundScope(
        style: style,
        tokens: t.recipeTokens,
        child: child,
      ),
    );
  }
}

/// Set by a dialog route that opened over another dialog or modal. Its scrim
/// is then `layer-backdrop-nested` (the dialog recipe's `nested` axis).
class RaftDialogNested extends InheritedWidget {
  const RaftDialogNested({super.key, required super.child});

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RaftDialogNested>() != null;

  @override
  bool updateShouldNotify(RaftDialogNested oldWidget) => false;
}

/// The shared dialog scrim, without an animation or pointer interception. The
/// route underneath remains responsible for backdrop dismissal and focus.
/// [nested] defaults to the [RaftDialogNested] scope of the route above.
class RaftDialogBackdrop extends StatelessWidget {
  const RaftDialogBackdrop({super.key, required this.child, this.nested});

  final Widget child;
  final bool? nested;

  /// The scrim slot, `nested` or not: the router has no `nested` axis for the
  /// frozen looks, so those keep the plain overlay.
  static RaftSlotStyle overlayOf(BuildContext context, {bool? nested}) {
    final t = RaftTokens.of(context);
    if ((nested ?? RaftDialogNested.of(context)) &&
        !usesLegacyRecipes(t.recipeTokens)) {
      return RaftDialogRecipe.resolveProps(
        {'theme': t.recipeTheme.name, 'nested': 'true'},
        states: t.recipeStates(),
        tokens: t.recipeTokens,
      )['overlay']!;
    }
    return RaftDialogRecipe.resolve(
      theme: t.recipeTheme,
      states: t.recipeStates(),
      tokens: t.recipeTokens,
    ).overlay;
  }

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final style = overlayOf(context, nested: nested);
    // A backdrop can also be embedded in a vertically scrolling host. Avoid
    // forcing an infinite height there while still filling bounded routes.
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        fit: constraints.hasBoundedWidth && constraints.hasBoundedHeight
            ? StackFit.expand
            : StackFit.passthrough,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: RaftRecipeBox(style: style, tokens: t.recipeTokens),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
