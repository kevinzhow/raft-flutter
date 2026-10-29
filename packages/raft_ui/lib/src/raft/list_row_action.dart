import 'package:flutter/material.dart';

import '../design_primitives.dart';
import '../recipe_surface.dart';
import '../recipes/recipe_router.dart';
import '../theme.dart';
import '../recipes/recipes.g.dart';
import 'button_color_transition.dart';

/// The input and hover/press layer of ListRow, for an existing composed row or
/// thumbnail that supplies its own layout. Nested actions keep their gestures.
class RaftListRowAction extends StatelessWidget {
  const RaftListRowAction({
    super.key,
    required this.child,
    this.onPressed,
    this.focusNode,
    this.selected,
    this.semanticLabel,
    this.decorate = true,
    this.onTapDown,
    this.onTapCancel,
    this.onLongPress,
    this.onSecondaryTapDown,
  });
  final Widget child;
  final VoidCallback? onPressed;
  final FocusNode? focusNode;
  final bool? selected;
  final bool decorate;
  final String? semanticLabel;
  final GestureTapDownCallback? onTapDown, onSecondaryTapDown;
  final GestureTapCancelCallback? onTapCancel;
  final GestureLongPressCallback? onLongPress;

  @override
  Widget build(BuildContext context) => RaftInteractive(
    onPressed: onPressed,
    focusNode: focusNode,
    selected: selected,
    semanticLabel: semanticLabel,
    semanticContainer: true,
    expandTouchTarget: false,
    onTapDown: onTapDown,
    onTapCancel: onTapCancel,
    onLongPress: onLongPress,
    onSecondaryTapDown: onSecondaryTapDown,
    builder: (context, state) {
      if (!decorate) return child;
      final tokens = RaftTokens.of(context);
      if (!usesLegacyRecipes(tokens.recipeTokens)) {
        final recipe = RaftListRowRecipe.resolve(
          variant: RaftListRowRecipeVariant.entry,
          interactive: state.enabled,
          states: tokens.recipeStates(
            hovered: state.hovered,
            pressed: state.pressed,
            focusVisible: state.focusVisible,
            disabled: !state.enabled,
            extra: [if (selected == true) 'data-selected=true'],
          ),
          tokens: tokens.recipeTokens,
        ).root;
        final paintOnly = recipe.copyWith(
          properties: {
            for (final entry in recipe.properties.entries)
              if (entry.key.startsWith('--') ||
                  entry.key.startsWith('background-') ||
                  entry.key.startsWith('outline-') ||
                  entry.key.startsWith('transition-') ||
                  entry.key == 'box-shadow')
                entry.key: entry.value,
          },
        );
        return RaftButtonColorTransition(
          style: paintOnly,
          tokens: tokens.recipeTokens,
          builder: (context, style) => RaftRecipeBox(
            style: style,
            tokens: tokens.recipeTokens,
            applyText: false,
            applyOpacity: false,
            applyTransform: false,
            child: child,
          ),
        );
      }
      final theme = Theme.of(context);
      final fill = state.pressed
          ? theme.highlightColor
          : state.focusVisible
          ? theme.focusColor
          : state.hovered
          ? theme.hoverColor
          : Colors.transparent;
      return ColoredBox(color: fill, child: child);
    },
  );
}
