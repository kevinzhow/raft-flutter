// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `panelActionBase`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftPanelActionBaseRecipe].
class RaftPanelActionBaseRecipeStyle {
  const RaftPanelActionBaseRecipeStyle({required this.base});

  /// Slot `base`.
  final RaftSlotStyle base;

  Map<String, RaftSlotStyle> get slots => {'base': base};
}

/// raft-ui recipe `panelActionBase` (`src/components/panel/panel-action.recipe.ts`, index.mjs:13683).
///
/// Used by: PanelAction, PanelToggleAction.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftPanelActionBaseRecipe {
  static const String recipeName = 'panelActionBase';
  static const List<String> slotNames = ['base'];
  static const List<RaftRecipeAxis> axes = [];

  static RaftPanelActionBaseRecipeStyle resolve({
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
    return RaftPanelActionBaseRecipeStyle(base: s[0]);
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
      1680,
      1305,
      1924,
      1738,
      1319,
      1324,
      1582,
      1016,
      1346,
      1781,
      1725,
      1575,
      1890,
      941,
      173,
      177,
      1174,
      1484,
      1708,
      622,
      641,
      615,
      1656,
      1664,
      1450,
      1458,
      1462,
      1437,
      1436,
      1820,
      1272,
      427,
      996,
      185,
      1435,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0],
  ];
}
