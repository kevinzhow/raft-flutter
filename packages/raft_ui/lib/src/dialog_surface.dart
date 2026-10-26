import 'package:flutter/widgets.dart';

import 'recipe_surface.dart';
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
    return RaftRecipeBox(
      style: raftDialogSlot(
        t,
        surfaceStyle ??
            RaftDialogSurfaceRecipe.resolve(
              states: t.recipeStates(),
              tokens: t.recipeTokens,
            ).root,
        'content',
      ),
      tokens: t.recipeTokens,
      clip: true,
      child: child,
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
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: RaftRecipeBox(style: style, tokens: t.recipeTokens),
          ),
        ),
        child,
      ],
    );
  }
}
