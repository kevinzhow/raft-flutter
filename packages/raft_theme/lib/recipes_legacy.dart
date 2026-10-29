/// The frozen raft-ui 0.5.52 recipe set that the Elegant and Brutal looks paint
/// with.
///
/// raft-ui 0.6.0 removed the per-recipe `theme` (`brutal` | `elegant`) axis
/// ("Raft is the only look"), so `tool/recipes/run` now generates only the Raft
/// set (`package:raft_theme/recipes.dart`, raft-ui 0.7.0). Elegant and Brutal
/// are frozen looks whose pixels must not change, so the 0.5.52 output of the
/// generator is kept here verbatim:
///
/// * `lib/recipes/legacy/*.g.dart` are the files `tool/recipes/run` produced at
///   0.5.52 (git `63939edec`), byte for byte except for the one relative import
///   of `recipe_runtime.dart`. They carry the old `theme:` argument and are
///   never regenerated or edited; the "GENERATED" headers inside them describe
///   the origin, not a command that still applies.
/// * The class names are unchanged (`RaftBadgeRecipe`, ...). Both sets are
///   libraries of their own, so a file that needs both imports this one with a
///   prefix. raft_ui does that once, in `lib/src/recipes/` (`recipe_router`),
///   which picks the set from the active theme pack; components keep calling
///   `RaftXRecipe.resolve(theme: ...)`.
///
/// Which pack uses which set is decided in one place, [RaftThemePackRecipes] in
/// `recipes/pack_tokens.dart`: the built-in `elegant` and `brutal` packs use this
/// set, every other pack (Raft and user packs that extend it) uses the Raft set.
library;

export 'recipes/legacy/recipes.g.dart';
