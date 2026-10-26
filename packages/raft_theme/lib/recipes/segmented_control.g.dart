// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `segmentedControl`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftSegmentedControlRecipe].
class RaftSegmentedControlRecipeStyle {
  const RaftSegmentedControlRecipeStyle({
    required this.root,
    required this.item,
    required this.label,
    required this.count,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `item`.
  final RaftSlotStyle item;

  /// Slot `label`.
  final RaftSlotStyle label;

  /// Slot `count`.
  final RaftSlotStyle count;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'item': item,
    'label': label,
    'count': count,
  };
}

/// raft-ui recipe `segmentedControl` (`src/components/segmented-control/segmented-control.tsx`, index.mjs:6163).
///
/// Used by: SegmentedControl, SegmentedControlCount, SegmentedControlItem, SegmentedControlLabel.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftSegmentedControlRecipe {
  static const String recipeName = 'segmentedControl';
  static const List<String> slotNames = ['root', 'item', 'label', 'count'];
  static const List<RaftRecipeAxis> axes = [];

  static RaftSegmentedControlRecipeStyle resolve({
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
    return RaftSegmentedControlRecipeStyle(
      root: s[0],
      item: s[1],
      label: s[2],
      count: s[3],
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
    [1304, 1422, 1318, 1923, 969, 1019, 1698, 581, 1596],
    [
      1304,
      1481,
      1736,
      1318,
      1021,
      1573,
      935,
      275,
      277,
      1187,
      1323,
      1706,
      622,
      641,
      615,
      1656,
      1015,
      1809,
      1016,
      1823,
      265,
      1271,
      810,
      808,
      814,
      821,
      817,
      818,
      815,
      816,
      807,
      995,
      831,
      836,
      832,
    ],
    [1893],
    [1013, 1835, 1014],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3],
  ];
}
