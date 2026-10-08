// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `radioGroup`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftRadioGroupRecipe].
class RaftRadioGroupRecipeStyle {
  const RaftRadioGroupRecipeStyle({required this.root, required this.item, required this.indicator, required this.dot});

  /// Slot `root`.
  final RaftSlotStyle root;
  /// Slot `item`.
  final RaftSlotStyle item;
  /// Slot `indicator`.
  final RaftSlotStyle indicator;
  /// Slot `dot`.
  final RaftSlotStyle dot;

  Map<String, RaftSlotStyle> get slots => {'root': root, 'item': item, 'indicator': indicator, 'dot': dot};
}

/// raft-ui recipe `radioGroup` (`src/components/radio-group/radio-group.tsx`, index.mjs:7565).
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

  static RaftRadioGroupRecipeStyle resolve({required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name], states, tokens);
    return RaftRadioGroupRecipeStyle(root: s[0], item: s[1], indicator: s[2], dot: s[3]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [1717, 3127, 1698, 1433, 1434, 1435, 1691, 276],
    [2775, 2301, 2867, 3044, 2312, 2317, 2815, 2649, 1442, 613, 611, 612, 618, 2880, 866, 900, 825, 2976, 2225, 1414, 1441, 1438, 1454, 1443, 1415, 1653, 1659, 1662, 1663],
    [2716, 1620, 2890, 2312, 2317],
    [862, 2815, 790, 2870],
    [1717, 3127, 1433, 1434, 1435, 1699],
    [2775, 2301, 2867, 3044, 2312, 2317, 2815, 2649, 1442, 613, 611, 612, 618, 2879, 825, 2979, 2852, 1120, 1122, 2222, 1413, 1431, 1033, 1042, 1424, 1039, 1438, 1454, 1448, 1443, 1415, 1419, 1417, 599, 1436, 2587, 1653, 1659, 1662, 1663],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3], [4, 5, 2, 3],
  ];
}
