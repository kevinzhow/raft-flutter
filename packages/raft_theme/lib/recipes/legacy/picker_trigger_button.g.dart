// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `pickerTriggerButton`.
// ignore_for_file: type=lint

import '../recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftPickerTriggerButtonRecipe].
class RaftPickerTriggerButtonRecipeStyle {
  const RaftPickerTriggerButtonRecipeStyle({required this.base});

  /// Slot `base`.
  final RaftSlotStyle base;

  Map<String, RaftSlotStyle> get slots => {'base': base};
}

/// raft-ui recipe `pickerTriggerButton` (`src/components/picker-trigger-button/picker-trigger-button.tsx`, index.mjs:7163).
///
/// Used by: PickerTriggerButton.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftPickerTriggerButtonRecipe {
  static const String recipeName = 'pickerTriggerButton';
  static const List<String> slotNames = ['base'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftPickerTriggerButtonRecipeStyle resolve({
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
    return RaftPickerTriggerButtonRecipeStyle(base: s[0]);
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
      1968,
      2902,
      2331,
      2336,
      1723,
      2781,
      2792,
      3073,
      3172,
      2868,
      2849,
      2669,
      2673,
      2675,
      3125,
      1625,
      1673,
      1614,
      1618,
      1610,
      2141,
      2136,
      423,
      425,
      415,
      75,
      878,
      887,
      868,
      2894,
      1716,
      1709,
      2986,
      2306,
      2260,
      2256,
      2286,
      615,
      616,
      608,
      1565,
      1557,
      352,
      83,
      82,
      353,
      354,
      355,
    ],
    [
      2804,
      2320,
      2902,
      2331,
      2336,
      1723,
      3172,
      2868,
      2669,
      2673,
      2675,
      3125,
      1625,
      1673,
      1614,
      1618,
      1610,
      2141,
      2136,
      423,
      425,
      415,
      75,
      1966,
      2678,
      2848,
      877,
      830,
      2780,
      2789,
      1716,
      3073,
      1713,
      3087,
      3021,
      649,
      2884,
      1165,
      724,
      694,
      716,
      737,
      726,
      696,
      2240,
      604,
      1003,
      1120,
      1676,
      1689,
      1685,
      1687,
      1524,
      1532,
      1527,
      1528,
      1530,
      367,
      348,
      346,
      347,
      351,
      349,
      350,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0],
    [1],
  ];
}
