// MessageMultiSelectToolbar from raft-ui and SelectModeToolbar from Web.
import 'package:flutter/material.dart';

import 'raft/ui_tokens.dart';
import 'recipe_surface.dart';
import 'recipes/message_multi_select.g.dart';
import 'theme.dart';

class RaftSelectionToolbarRecipe {
  const RaftSelectionToolbarRecipe(this.tokens);
  final RaftTokens tokens;

  RaftMessageMultiSelectRecipeStyle get _slots =>
      RaftMessageMultiSelectRecipe.resolve(tokens: tokens.recipeTokens);

  EdgeInsets get inset => _slots.toolbar.padding;
  double get gap => _slots.toolbar.length('gap') ?? 8;
  double get actionGap => _slots.toolbarActions.length('gap') ?? 4;
  Color get background => tokens.popover;
  BoxDecoration get decoration => _slots.toolbar
      .decoration(tokens.recipeTokens)
      .copyWith(border: Border.all(color: tokens.ui.lineSeam));
  TextStyle get count => tokens.scale(
    tokens.typeSlot('control'),
    weight: FontWeight.w700,
    color: tokens.ui.foreground,
  );
}
