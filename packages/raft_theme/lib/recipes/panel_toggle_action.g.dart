// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `panelToggleAction`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftPanelToggleActionRecipe].
class RaftPanelToggleActionRecipeStyle {
  const RaftPanelToggleActionRecipeStyle({required this.base});

  /// Slot `base`.
  final RaftSlotStyle base;

  Map<String, RaftSlotStyle> get slots => {'base': base};
}

/// raft-ui recipe `panelToggleAction` (`src/components/panel/panel-action.recipe.ts`, index.mjs:13706).
///
/// Used by: PanelToggleAction.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftPanelToggleActionRecipe {
  static const String recipeName = 'panelToggleAction';
  static const List<String> slotNames = ['base'];
  static const List<RaftRecipeAxis> axes = [];

  static RaftPanelToggleActionRecipeStyle resolve({
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
    return RaftPanelToggleActionRecipeStyle(base: s[0]);
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
      1682,
      1305,
      1927,
      1740,
      1319,
      1324,
      1584,
      1016,
      1783,
      1727,
      1577,
      1892,
      941,
      173,
      177,
      1174,
      1485,
      1710,
      622,
      641,
      615,
      1658,
      1666,
      1451,
      1459,
      1463,
      1438,
      1437,
      1822,
      1272,
      427,
      996,
      185,
      1436,
      834,
      837,
      1022,
      1821,
      1008,
      829,
      836,
      833,
      891,
      890,
      897,
      895,
      896,
      888,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0],
  ];
}
