import 'package:raft_theme/recipes/authored_utilities.dart';
import 'package:raft_theme/recipes/recipe_runtime.dart';
import 'package:raft_theme/recipes/recipe_utilities.g.dart' as raft;

/// Utility indices of [names] in [utilities]. A name the table never compiled
/// is a bug in the caller (typically a list that mixes the two tables), so it fails loudly in debug builds, naming the offender.
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
/// recipe utility table and engine. Every name must exist there (debug builds
/// assert).
RaftSlotStyle resolveRecipeClasses(
  Iterable<String> names,
  RaftRecipeStates states,
  RaftTokenResolver tokens,
) => raft.raftRecipeEngine.resolveSlot(
  _indices(raft.raftRecipeUtilities, names, 'Raft'),
  states,
  tokens,
);

/// Resolves class names written in this repository (the Web index.css product
/// compositions `.card-brutal` and `.input-brutal`) through the 0.5.52 utility
/// entries kept in `authored_utilities.dart`. The list must be authored entirely
/// in that vocabulary (`bg-layer-panel`, `shadow-raft-md`): never mix in the
/// `classes` of a recipe. Debug builds assert on unknown names.
RaftSlotStyle resolveAuthoredClasses(
  Iterable<String> names,
  RaftRecipeStates states,
  RaftTokenResolver tokens,
) => raftAuthoredEngine.resolveSlot(
  _indices(raftAuthoredUtilities, names, 'authored 0.5.52'),
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
