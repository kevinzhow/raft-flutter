// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `filterChip`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftFilterChipRecipe].
class RaftFilterChipRecipeStyle {
  const RaftFilterChipRecipeStyle({
    required this.root,
    required this.label,
    required this.remove,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `label`.
  final RaftSlotStyle label;

  /// Slot `remove`.
  final RaftSlotStyle remove;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'label': label,
    'remove': remove,
  };
}

/// raft-ui recipe `filterChip` (`dist/components/filter-chip/filter-chip.mjs`, index.mjs:28256).
///
/// Used by: FilterChip, FilterChipLabel, FilterChipRemove.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftFilterChipRecipe {
  static const String recipeName = 'filterChip';
  static const List<String> slotNames = ['root', 'label', 'remove'];
  static const List<RaftRecipeAxis> axes = [];

  static RaftFilterChipRecipeStyle resolve({
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
    return RaftFilterChipRecipeStyle(root: s[0], label: s[1], remove: s[2]);
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
    [
      1847,
      1661,
      2042,
      2116,
      2498,
      1864,
      1465,
      2463,
      907,
      2355,
      2299,
      1456,
      2591,
      1457,
      2598,
      344,
      348,
      326,
      330,
    ],
    [2116, 2681],
    [
      1847,
      2499,
      1864,
      1869,
      2247,
      2675,
      2471,
      2600,
      1785,
      697,
      1421,
      1422,
      351,
      2433,
      2520,
      723,
      729,
      2320,
      2323,
      2324,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2],
  ];
}
