import 'package:flutter/widgets.dart';

import 'recipe_surface.dart';
import 'recipe_background_scope.dart';
import 'dialog_slots.dart';
import 'recipes/dialog.g.dart';
import 'recipes/dialog_surface.g.dart';
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

/// The shared dialog scrim, without an animation or pointer interception. The
/// route underneath remains responsible for backdrop dismissal and focus.
class RaftDialogBackdrop extends StatelessWidget {
  const RaftDialogBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    final style = RaftDialogRecipe.resolve(
      theme: t.recipeTheme,
      states: t.recipeStates(),
      tokens: t.recipeTokens,
    ).overlay;
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
