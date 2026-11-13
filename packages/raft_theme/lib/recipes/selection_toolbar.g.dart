// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `selectionToolbar`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftSelectionToolbarRecipe].
class RaftSelectionToolbarRecipeStyle {
  const RaftSelectionToolbarRecipeStyle({
    required this.dock,
    required this.root,
    required this.count,
    required this.countValue,
    required this.hint,
    required this.actions,
    required this.action,
    required this.actionLabel,
    required this.actionChevron,
    required this.more,
    required this.close,
  });

  /// Slot `dock`.
  final RaftSlotStyle dock;

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `count`.
  final RaftSlotStyle count;

  /// Slot `countValue`.
  final RaftSlotStyle countValue;

  /// Slot `hint`.
  final RaftSlotStyle hint;

  /// Slot `actions`.
  final RaftSlotStyle actions;

  /// Slot `action`.
  final RaftSlotStyle action;

  /// Slot `actionLabel`.
  final RaftSlotStyle actionLabel;

  /// Slot `actionChevron`.
  final RaftSlotStyle actionChevron;

  /// Slot `more`.
  final RaftSlotStyle more;

  /// Slot `close`.
  final RaftSlotStyle close;

  Map<String, RaftSlotStyle> get slots => {
    'dock': dock,
    'root': root,
    'count': count,
    'countValue': countValue,
    'hint': hint,
    'actions': actions,
    'action': action,
    'actionLabel': actionLabel,
    'actionChevron': actionChevron,
    'more': more,
    'close': close,
  };
}

/// raft-ui recipe `selectionToolbar` (`dist/components/selection-toolbar/selection-toolbar.recipe.mjs`, index.mjs:27020).
///
/// Used by: SelectionToolbar, SelectionToolbarAction, SelectionToolbarActions, SelectionToolbarClose, SelectionToolbarCount, SelectionToolbarCountValue, SelectionToolbarDock, SelectionToolbarHint, SelectionToolbarMore.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftSelectionToolbarRecipe {
  static const String recipeName = 'selectionToolbar';
  static const List<String> slotNames = [
    'dock',
    'root',
    'count',
    'countValue',
    'hint',
    'actions',
    'action',
    'actionLabel',
    'actionChevron',
    'more',
    'close',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('menu', ['true', 'false'], null, true),
  ];

  static RaftSelectionToolbarRecipeStyle resolve({
    bool? menu,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [menu?.toString()],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftSelectionToolbarRecipeStyle(
      dock: s[0],
      root: s[1],
      count: s[2],
      countValue: s[3],
      hint: s[4],
      actions: s[5],
      action: s[6],
      actionLabel: s[7],
      actionChevron: s[8],
      more: s[9],
      close: s[10],
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
    [2346, 691, 1858, 965, 2744, 1400, 1869, 2406, 2280, 161],
    [
      2724,
      1462,
      2038,
      1635,
      2395,
      2412,
      2462,
      915,
      2445,
      2449,
      2496,
      9,
      2008,
      92,
      95,
    ],
    [2499, 2353, 2298, 2070, 2729, 2587, 1449, 2598, 2556],
    [1454],
    [2499, 2355, 2729, 2588, 2600, 1215],
    [1462, 2038],
    [
      459,
      2501,
      1869,
      2397,
      740,
      2453,
      2077,
      2087,
      2063,
      2061,
      2034,
      2033,
      1217,
    ],
    [2539, 2055, 2045],
    [172, 1776, 2515, 2032, 2044],
    [1776, 1223, 459, 2501, 2397, 740, 2453, 2077, 2084],
    [2501, 740, 2453, 2077],
    [
      459,
      2501,
      1869,
      2397,
      740,
      2453,
      2077,
      2087,
      2061,
      2034,
      2033,
      1217,
      2062,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
    [0, 1, 2, 3, 4, 5, 11, 7, 8, 9, 10],
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
  ];
}
