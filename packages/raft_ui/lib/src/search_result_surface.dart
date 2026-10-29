import 'package:flutter/material.dart';

import 'raft/ui_tokens.dart';

import 'design_primitives.dart';
import 'recipe_surface.dart';
import 'recipes/button_variants.g.dart';
import 'recipes/recipe_runtime.dart';
import 'recipes/search_entity.g.dart';
import 'recipes/search_message.g.dart';
import 'theme.dart';

/// Interactive SearchEntityResult / SearchMessageResult recipe surface.
/// Business identity and navigation stay with the consumer.
class RaftSearchResultSurface extends StatelessWidget {
  const RaftSearchResultSurface({
    super.key,
    required this.child,
    required this.onPressed,
    this.entity = false,
    this.selected = false,
    this.nested = false,
    this.first = false,
  });

  final Widget child;
  final VoidCallback onPressed;
  final bool entity, selected, nested;

  /// First child of a thread card: no divider above it.
  final bool first;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return RaftInteractive(
      onPressed: onPressed,
      selected: selected,
      builder: (context, interaction) {
        final states = t.recipeStates(
          hovered: interaction.hovered,
          pressed: interaction.pressed,
          focusVisible: interaction.focusVisible,
          extra: [
            if (selected) 'data-selected=true',
            if (nested) 'data-nested=true',
          ],
        );
        if (t.option('searchResult.selection', or: 'card') == 'flat') {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: selected
                  ? t.ui['brand-soft']
                  : interaction.hovered
                  ? t.ui.fillPressed
                  : null,
            ),
            foregroundDecoration: interaction.focusVisible
                ? BoxDecoration(
                    border: Border.all(color: t.ui.foreground, width: 2),
                  )
                : null,
            child: child,
          );
        }
        final style = entity
            ? RaftSearchEntityRecipe.resolve(
                theme: t.recipeTheme,
                states: states,
                tokens: t.recipeTokens,
              ).entity
            : RaftSearchMessageRecipe.resolve(
                theme: t.recipeTheme,
                states: states,
                tokens: t.recipeTokens,
                selected: selected,
                nested: nested,
              ).message;
        return RaftRecipeBox(
          // Chromium paints a hairline (`border-[0.5px]`) as 1px.
          style: first
              ? style.withCssUsedBorderWidths().withoutTopBorder()
              : style.withCssUsedBorderWidths(),
          tokens: t.recipeTokens,
          child: child,
        );
      },
    );
  }
}

/// TasksPanel filter Button: sm recipe, with the product's `box-border
/// h-8 min-h-8 gap-2 py-0` overrides. The recipe retains its sm inline padding.
class RaftTaskFilterButton extends StatelessWidget {
  const RaftTaskFilterButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.selected = false,
  });
  final Widget child;
  final VoidCallback? onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final t = RaftTokens.of(context);
    return RaftInteractive(
      onPressed: onPressed,
      selected: selected,
      builder: (context, state) {
        final root = RaftButtonRecipe.resolve(
          theme: t.recipeTheme,
          size: RaftButtonRecipeSize.sm,
          variant: selected
              ? RaftButtonRecipeVariant.primary
              : RaftButtonRecipeVariant.outline,
          states: t.recipeStates(
            hovered: state.hovered,
            pressed: state.pressed,
            focusVisible: state.focusVisible,
            disabled: !state.enabled,
          ),
          tokens: t.recipeTokens,
        ).root;
        final slot = RaftSlotStyle(
          {
            ...root.properties,
            'height': const CssNum(RaftMetrics.buttonMd, 'px'),
            'min-height': const CssNum(RaftMetrics.buttonMd, 'px'),
            'padding-top': const CssNum(0, 'px'),
            'padding-bottom': const CssNum(0, 'px'),
          },
          root.targets,
          root.classes,
          t.recipeTokens,
        );
        return RaftRecipeBox(
          style: slot,
          tokens: t.recipeTokens,
          overflowCenter: true,
          controlLabel: true,
          child: Center(widthFactor: 1, heightFactor: 1, child: child),
        );
      },
    );
  }
}
