// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `panelAction`.
// ignore_for_file: type=lint

import '../recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftPanelActionRecipe].
class RaftPanelActionRecipeStyle {
  const RaftPanelActionRecipeStyle({required this.base});

  /// Slot `base`.
  final RaftSlotStyle base;

  Map<String, RaftSlotStyle> get slots => {'base': base};
}

/// raft-ui recipe `panelAction` (`src/components/panel/panel-action.recipe.ts`, index.mjs:16576).
///
/// Used by: PanelAction.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftPanelActionRecipe {
  static const String recipeName = 'panelAction';
  static const List<String> slotNames = ['base'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftPanelActionRecipeStyle resolve({
    required RaftRecipeTheme theme,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [theme.name],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftPanelActionRecipeStyle(base: s[0]);
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
      2804,
      2320,
      3166,
      2902,
      2331,
      2336,
      2680,
      1716,
      2946,
      2868,
      2672,
      3124,
      1625,
      294,
      298,
      1722,
      3074,
      3172,
      1614,
      1610,
      1618,
      2849,
      878,
      892,
      868,
      2777,
      2801,
      2994,
      2897,
      2191,
      2256,
      2287,
      1663,
      1671,
      1666,
      300,
      603,
      614,
      611,
      1616,
    ],
    [
      2804,
      2320,
      3166,
      2902,
      2331,
      2336,
      2680,
      1716,
      2946,
      2868,
      2672,
      3124,
      1625,
      294,
      298,
      1722,
      3074,
      3172,
      1614,
      1610,
      1618,
      2848,
      877,
      863,
      2779,
      2794,
      2233,
      2299,
      1678,
      1691,
      301,
      3015,
      2894,
      593,
      613,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0],
    [1],
  ];
}
