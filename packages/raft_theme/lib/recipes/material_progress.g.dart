// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `materialProgress`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftMaterialProgressRecipe].
class RaftMaterialProgressRecipeStyle {
  const RaftMaterialProgressRecipeStyle({
    required this.root,
    required this.determinate,
    required this.arc,
    required this.arrow,
    required this.indeterminate,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `determinate`.
  final RaftSlotStyle determinate;

  /// Slot `arc`.
  final RaftSlotStyle arc;

  /// Slot `arrow`.
  final RaftSlotStyle arrow;

  /// Slot `indeterminate`.
  final RaftSlotStyle indeterminate;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'determinate': determinate,
    'arc': arc,
    'arrow': arrow,
    'indeterminate': indeterminate,
  };
}

/// raft-ui recipe `materialProgress` (`dist/components/pull-to-refresh/pull-to-refresh-material-progress.mjs`, index.mjs:28620).
///
/// Used by: PullToRefreshIndicator.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftMaterialProgressRecipe {
  static const String recipeName = 'materialProgress';
  static const List<String> slotNames = [
    'root',
    'determinate',
    'arc',
    'arrow',
    'indeterminate',
  ];
  static const List<RaftRecipeAxis> axes = [];

  static RaftMaterialProgressRecipeStyle resolve({
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftMaterialProgressRecipeStyle(
      root: s[0],
      determinate: s[1],
      arc: s[2],
      arrow: s[3],
      indeterminate: s[4],
    );
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(
    Map<String, String?> props, {
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [for (final a in axes) props[a.name]],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [2509, 2499, 2253, 2610],
    [2676, 1366, 1376, 2138, 2231, 1151],
    [1390, 2546, 688],
    [1389],
    [1390, 2546, 689],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4],
  ];
}
