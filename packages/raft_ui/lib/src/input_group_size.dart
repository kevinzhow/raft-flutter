// The `size` axis of raft-ui `inputGroup`. The recipe's default is `lg`, the
// forms' 44px; FitToolbarSearch is `md` (32px, 34px with a mouse from 768px).
import 'package:raft_theme/recipes/input_group.g.dart' as raft;

import 'recipes/input_group.g.dart';
import 'recipes/recipe_runtime.dart';

export 'package:raft_theme/recipes/input_group.g.dart'
    show RaftInputGroupRecipeSize;

RaftInputGroupRecipeStyle resolveSizedInputGroup({
  required raft.RaftInputGroupRecipeSize size,
  required RaftInputGroupRecipeAlign align,
  required RaftInputGroupRecipeVariant variant,
  required RaftRecipeStates states,
  RaftTokenResolver? tokens,
}) => raft.RaftInputGroupRecipe.resolve(
  size: size,
  align: align,
  variant: variant,
  states: states,
  tokens: tokens,
);
