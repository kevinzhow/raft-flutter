// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `radioGroup`.
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

/// raft-ui recipe `radioGroup` (`dist/components/radio-group/radio-group.mjs`, index.mjs:9010).
///
/// Used by: RadioGroup, RadioGroupIndicator, RadioGroupItem.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftRadioGroupRecipe {
  static const String recipeName = 'radioGroup';
  static const List<String> slotNames = ['root', 'item', 'indicator', 'dot'];
  static const List<RaftRecipeAxis> axes = [];

  static RaftRadioGroupRecipeStyle resolve({
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
    [1489, 2725, 1466, 1174, 1175, 1176, 1456, 313],
    [
      2433,
      1847,
      2499,
      2650,
      1864,
      1869,
      2466,
      2247,
      1181,
      723,
      713,
      715,
      729,
      2322,
      683,
      682,
      2519,
      941,
      955,
      911,
      2598,
      1439,
      1180,
      1178,
      1187,
    ],
    [2346, 1400, 2538, 1864, 1869],
    [937, 2466, 891, 2513],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3],
  ];
}
