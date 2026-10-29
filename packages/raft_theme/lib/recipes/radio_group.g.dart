// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
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

/// raft-ui recipe `radioGroup` (`src/components/radio-group/radio-group.tsx`, index.mjs:6067).
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
    [1040, 1929, 1023, 824, 825, 826, 1016, 149],
    [
      1682,
      1305,
      1740,
      1869,
      1319,
      1324,
      1712,
      1577,
      831,
      442,
      437,
      440,
      450,
      1754,
      622,
      635,
      596,
      1822,
      996,
      830,
      828,
      836,
    ],
    [1630, 965, 1770, 1319, 1324],
    [618, 1712, 578, 1750],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3],
  ];
}
