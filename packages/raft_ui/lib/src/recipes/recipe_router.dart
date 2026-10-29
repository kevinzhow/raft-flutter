import 'package:raft_theme/recipes/legacy/recipe_utilities.g.dart' as legacy;
import 'package:raft_theme/recipes/recipe_runtime.dart';
import 'package:raft_theme/recipes/recipe_utilities.g.dart' as raft;

/// Support for the generated recipe router (`tool/recipes/gen_router.mjs`).
///
/// A resolver that does not name a set (none at all, or a test fake) keeps the
/// frozen 0.5.52 set, so nothing that predates the Raft set changes by accident.
/// The set of a real theme comes from `RaftThemePackRecipes.recipeSet`.
bool usesLegacyRecipes(RaftTokenResolver? tokens) =>
    tokens == null || tokens.recipeSet == RaftRecipeSet.legacy;

/// The Raft enum value with CSS name [css], or null when the Raft recipe has no
/// such value (the axis then takes its default).
T? routeAxis<T>(String? css, List<T> values, String Function(T) cssOf) {
  if (css == null) return null;
  for (final value in values) {
    if (cssOf(value) == css) return value;
  }
  return null;
}

/// A slot the Raft recipe does not define: no declarations at all.
RaftSlotStyle absentSlot(RaftTokenResolver? tokens) =>
    RaftSlotStyle(const {}, const {}, const [], tokens);

/// [raft] plus an empty slot for every legacy slot name it lacks.
Map<String, RaftSlotStyle> withLegacySlots(
  Map<String, RaftSlotStyle> raft,
  List<String> legacySlots,
  RaftTokenResolver? tokens,
) => {for (final name in legacySlots) name: absentSlot(tokens), ...raft};

/// Utility indices of [names] in [utilities]. A name the table never compiled
/// is a bug in the caller (typically a list that mixes names of two recipe
/// sets), so it fails loudly in debug builds, naming the offender.
List<int> _indices(
  List<RaftUtility> utilities,
  Iterable<String> names,
  String table,
) {
  final out = <int>[];
  for (final name in names) {
    final i = utilities.indexWhere((u) => u.name == name);
    assert(i >= 0, 'Class "$name" is not in the $table utility table.');
    if (i >= 0) out.add(i);
  }
  return out;
}

/// Resolves class names (as listed in a resolved slot's `classes`) through the
/// utility table and engine of the recipe set [tokens] paints with. Every name
/// must exist there: pass names of one set only (debug builds assert).
RaftSlotStyle resolveRecipeClasses(
  Iterable<String> names,
  RaftRecipeStates states,
  RaftTokenResolver tokens,
) {
  final legacySet = usesLegacyRecipes(tokens);
  return (legacySet ? legacy.raftRecipeEngine : raft.raftRecipeEngine)
      .resolveSlot(
        _indices(
          legacySet ? legacy.raftRecipeUtilities : raft.raftRecipeUtilities,
          names,
          legacySet ? 'frozen 0.5.52' : 'Raft',
        ),
        states,
        tokens,
      );
}

/// Resolves class names written in this repository (product compositions such as
/// `.card-brutal`) through the 0.5.52 utility table, in every look. The list
/// must be authored entirely in the 0.5.52 vocabulary (`bg-layer-panel`,
/// `shadow-raft-md`): never mix in the `classes` of a routed recipe, which come
/// from the Raft set in the Raft look. Debug builds assert on unknown names.
RaftSlotStyle resolveAuthoredClasses(
  Iterable<String> names,
  RaftRecipeStates states,
  RaftTokenResolver tokens,
) => legacy.raftRecipeEngine.resolveSlot(
  _indices(legacy.raftRecipeUtilities, names, 'frozen 0.5.52'),
  states,
  tokens,
);

/// The Card recipe's classes re-skinned as a floating surface in the Raft set:
/// the Popover content treatment of raft-ui 0.7.0 (`bg-layer-popover
/// shadow-float ring-1 ring-line-seam`, no border) instead of the card's
/// hairline, fill and `shadow-none`.
List<String> raftPopoverSurfaceClasses(Iterable<String> cardClasses) => [
  ...cardClasses.where(
    (name) => !const {
      'border',
      'border-line-hairline',
      'bg-layer-card',
      'shadow-none',
    }.contains(name),
  ),
  'bg-layer-popover',
  'shadow-float',
  'ring-1',
  'ring-line-seam',
];
