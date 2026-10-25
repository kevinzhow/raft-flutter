// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
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

/// raft-ui recipe `segmentedControl` (`src/components/segmented-control/segmented-control.tsx`, index.mjs:7774).
///
/// Used by: SegmentedControl, SegmentedControlCount, SegmentedControlItem, SegmentedControlLabel.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftSegmentedControlRecipe {
  static const String recipeName = 'segmentedControl';
  static const List<String> slotNames = ['root', 'item', 'label', 'count'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
    RaftRecipeAxis('disabled', ['true', 'false'], 'false', false),
  ];

  static RaftSegmentedControlRecipeStyle resolve({
    required RaftRecipeTheme theme,
    bool? disabled,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [theme.name, disabled?.toString()],
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
    [2320, 2505, 1650, 2331, 1721, 2651],
    [
      2320,
      2597,
      2902,
      2331,
      1722,
      3073,
      2352,
      2672,
      1614,
      423,
      425,
      414,
      878,
      916,
      830,
      2779,
      2792,
      1717,
      3013,
      2132,
      2113,
      445,
      460,
      2244,
      1436,
      1451,
      1464,
    ],
    [3133],
    [1714, 3073, 2352, 1709, 3031, 1857],
    [2320, 2505, 1650, 2331, 1721],
    [2320, 2505, 1650, 2331, 1722, 2651],
    [
      2320,
      2597,
      2902,
      2331,
      1722,
      3073,
      2352,
      2672,
      1614,
      423,
      425,
      414,
      2852,
      830,
      2780,
      2794,
      1713,
      3013,
      649,
      2133,
      2114,
      2885,
      1078,
      1080,
      1597,
      1079,
      1436,
      1452,
      1442,
      1445,
      1061,
      1057,
      1677,
      1680,
      1685,
      1687,
      1464,
    ],
    [1714, 3073, 2352, 3021, 1858],
    [2320, 2505, 1650, 2331, 1722],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3],
    [4, 1, 2, 3],
    [5, 6, 2, 7],
    [8, 6, 2, 7],
  ];
}
