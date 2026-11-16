// The `size` axis of raft-ui `inputGroup` for the Raft look. The generated
// router (recipes/input_group.g.dart) does not route it (the recipe's default
// is `lg`, the forms' 44px); FitToolbarSearch is `md` (32px, 34px with a
// mouse from 768px).
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
}) {
  final s = raft.RaftInputGroupRecipe.resolve(
    size: size,
    align: raft.RaftInputGroupRecipeAlign.values.firstWhere(
      (e) => e.css == align.css,
    ),
    variant: raft.RaftInputGroupRecipeVariant.values.firstWhere(
      (e) => e.css == variant.css,
    ),
    states: states,
    tokens: tokens,
  );
  return RaftInputGroupRecipeStyle(
    root: s.root,
    addon: s.addon,
    text: s.text,
    control: s.control,
  );
}
