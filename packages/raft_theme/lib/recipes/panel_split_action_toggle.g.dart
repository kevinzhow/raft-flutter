// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `panelSplitActionToggle`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftPanelSplitActionToggleRecipe].
class RaftPanelSplitActionToggleRecipeStyle {
  const RaftPanelSplitActionToggleRecipeStyle({required this.base});

  /// Slot `base`.
  final RaftSlotStyle base;

  Map<String, RaftSlotStyle> get slots => {'base': base};
}

/// raft-ui recipe `panelSplitActionToggle` (`dist/components/panel/panel-split-action.recipe.mjs`, index.mjs:26413).
///
/// Used by: PanelSplitActionToggle.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftPanelSplitActionToggleRecipe {
  static const String recipeName = 'panelSplitActionToggle';
  static const List<String> slotNames = ['base'];
  static const List<RaftRecipeAxis> axes = [];

  static RaftPanelSplitActionToggleRecipeStyle resolve({
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
    return RaftPanelSplitActionToggleRecipeStyle(base: s[0]);
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
      2723,
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
      2114,
      2453,
      941,
      963,
      2412,
      2401,
      2071,
      723,
      705,
      2598,
      1439,
      356,
      543,
      1185,
      1188,
      1465,
      2591,
      1449,
      1179,
      1187,
      1184,
      1289,
      1288,
      1294,
      1292,
      1293,
      1286,
      2345,
      2465,
      730,
      1442,
      792,
      1295,
      878,
      1588,
      1785,
      697,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0],
  ];
}
