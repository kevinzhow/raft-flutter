// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `panelSplitActionMenu`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftPanelSplitActionMenuRecipe].
class RaftPanelSplitActionMenuRecipeStyle {
  const RaftPanelSplitActionMenuRecipeStyle({required this.base});

  /// Slot `base`.
  final RaftSlotStyle base;

  Map<String, RaftSlotStyle> get slots => {'base': base};
}

/// raft-ui recipe `panelSplitActionMenu` (`dist/components/panel/panel-split-action.recipe.mjs`, index.mjs:26417).
///
/// Used by: PanelSplitActionMenu.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftPanelSplitActionMenuRecipe {
  static const String recipeName = 'panelSplitActionMenu';
  static const List<String> slotNames = ['base'];
  static const List<RaftRecipeAxis> axes = [];

  static RaftPanelSplitActionMenuRecipeStyle resolve({
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
    return RaftPanelSplitActionMenuRecipeStyle(base: s[0]);
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
      2433,
      1847,
      2499,
      1864,
      1869,
      2253,
      1456,
      2556,
      2483,
      2247,
      2674,
      1365,
      344,
      348,
      1630,
      2453,
      941,
      963,
      2412,
      2071,
      723,
      705,
      2598,
      1439,
      543,
      2729,
      1360,
      1364,
      1465,
      2591,
      1449,
      1349,
      1363,
      1356,
      788,
      787,
      791,
      789,
      790,
      786,
      2345,
      2116,
      2469,
      2397,
      2706,
      2094,
      2085,
      2049,
      755,
      736,
      2024,
      1442,
      650,
      649,
      879,
      1588,
      1785,
      697,
      1277,
      352,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0],
  ];
}
