// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `taskListSection`.
// ignore_for_file: type=lint

import '../recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftTaskListSectionRecipe].
class RaftTaskListSectionRecipeStyle {
  const RaftTaskListSectionRecipeStyle({
    required this.root,
    required this.trigger,
    required this.heading,
    required this.badge,
    required this.count,
    required this.chevron,
    required this.panel,
    required this.items,
    required this.empty,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `trigger`.
  final RaftSlotStyle trigger;

  /// Slot `heading`.
  final RaftSlotStyle heading;

  /// Slot `badge`.
  final RaftSlotStyle badge;

  /// Slot `count`.
  final RaftSlotStyle count;

  /// Slot `chevron`.
  final RaftSlotStyle chevron;

  /// Slot `panel`.
  final RaftSlotStyle panel;

  /// Slot `items`.
  final RaftSlotStyle items;

  /// Slot `empty`.
  final RaftSlotStyle empty;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'trigger': trigger,
    'heading': heading,
    'badge': badge,
    'count': count,
    'chevron': chevron,
    'panel': panel,
    'items': items,
    'empty': empty,
  };
}

/// raft-ui recipe `taskListSection` (`src/components/task-list/task-list-section.recipe.ts`, index.mjs:18916).
///
/// Used by: TaskSection, TaskSectionBadge, TaskSectionChevron, TaskSectionCount, TaskSectionEmpty, TaskSectionHeading, TaskSectionItems, TaskSectionPanel, TaskSectionTrigger.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftTaskListSectionRecipe {
  static const String recipeName = 'taskListSection';
  static const List<String> slotNames = [
    'root',
    'trigger',
    'heading',
    'badge',
    'count',
    'chevron',
    'panel',
    'items',
    'empty',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftTaskListSectionRecipeStyle resolve({
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
    return RaftTaskListSectionRecipeStyle(
      root: s[0],
      trigger: s[1],
      heading: s[2],
      badge: s[3],
      count: s[4],
      chevron: s[5],
      panel: s[6],
      items: s[7],
      empty: s[8],
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
    [2939],
    [
      1751,
      1644,
      3168,
      3085,
      2331,
      2335,
      1725,
      3040,
      2672,
      1607,
      1663,
      1672,
      1671,
      1666,
    ],
    [1644, 2597, 2331, 1723],
    [
      2779,
      2790,
      2956,
      2320,
      2331,
      1721,
      876,
      916,
      1712,
      1709,
      3137,
      3024,
      426,
      425,
      451,
    ],
    [3073, 2352, 1714, 3029],
    [2320, 2902, 145, 2331, 3128, 428, 1872, 2616, 3029, 1908],
    [1485],
    [2937],
    [2781, 2799, 878, 902, 917, 3053, 2354, 3027],
    [2939, 2837, 746, 2695, 2899, 1013],
    [
      1751,
      1644,
      3168,
      3085,
      2331,
      2335,
      1725,
      3040,
      2672,
      1607,
      2848,
      2719,
      2752,
      1663,
      1672,
      1671,
      1673,
      1677,
      1690,
      1686,
      1687,
      1085,
      1718,
    ],
    [1644, 2597, 2331, 1722],
    [2320, 2331, 1722, 2775, 2789, 1716, 3073, 2352, 1713, 3018, 428, 425],
    [3073, 2352, 1716, 1713, 2946, 3021],
    [2320, 2902, 145, 2331, 3128, 428, 1872, 2616, 3015, 1908],
    [2937, 399],
    [2781, 2799, 2847, 876, 902, 912, 801, 2962, 2353, 3021],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8],
    [9, 10, 11, 12, 13, 14, 6, 15, 16],
  ];
}
