// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `radioGroup`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftRadioGroupRecipe].
class RaftRadioGroupRecipeStyle {
  const RaftRadioGroupRecipeStyle({
    required this.root,
    required this.item,
    required this.indicator,
    required this.dot,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `item`.
  final RaftSlotStyle item;

  /// Slot `indicator`.
  final RaftSlotStyle indicator;

  /// Slot `dot`.
  final RaftSlotStyle dot;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'item': item,
    'indicator': indicator,
    'dot': dot,
  };
}

/// raft-ui recipe `radioGroup` (`src/components/radio-group/radio-group.tsx`, index.mjs:7582).
///
/// Used by: RadioGroup, RadioGroupIndicator, RadioGroupItem.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftRadioGroupRecipe {
  static const String recipeName = 'radioGroup';
  static const List<String> slotNames = ['root', 'item', 'indicator', 'dot'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftRadioGroupRecipeStyle resolve({
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
    return RaftRadioGroupRecipeStyle(
      root: s[0],
      item: s[1],
      indicator: s[2],
      dot: s[3],
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
    [1742, 3168, 1723, 1455, 1456, 1457, 1716, 272],
    [
      2804,
      2320,
      2902,
      3085,
      2331,
      2336,
      2845,
      2672,
      1464,
      619,
      617,
      618,
      624,
      2915,
      878,
      916,
      830,
      3013,
      2244,
      1436,
      1463,
      1460,
      1476,
      1465,
      1437,
      1677,
      1683,
      1686,
      1687,
    ],
    [2739, 1644, 2925, 2331, 2336],
    [874, 2845, 796, 2905],
    [1742, 3168, 1455, 1456, 1457, 1724],
    [
      2804,
      2320,
      2902,
      3085,
      2331,
      2336,
      2845,
      2672,
      1464,
      619,
      617,
      618,
      624,
      2914,
      830,
      3016,
      2886,
      1139,
      1141,
      2241,
      1435,
      1453,
      1053,
      1062,
      1446,
      1059,
      1460,
      1476,
      1470,
      1465,
      1437,
      1441,
      1439,
      605,
      1458,
      2610,
      1677,
      1683,
      1686,
      1687,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3],
    [4, 5, 2, 3],
  ];
}
