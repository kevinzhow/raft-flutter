// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `taskListSection`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftTaskListSectionRecipe].
class RaftTaskListSectionRecipeStyle {
  const RaftTaskListSectionRecipeStyle({required this.root, required this.trigger, required this.heading, required this.badge, required this.count, required this.chevron, required this.panel, required this.items, required this.empty});

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

  Map<String, RaftSlotStyle> get slots => {'root': root, 'trigger': trigger, 'heading': heading, 'badge': badge, 'count': count, 'chevron': chevron, 'panel': panel, 'items': items, 'empty': empty};
}

/// raft-ui recipe `taskListSection` (`src/components/task-list/task-list-section.recipe.ts`, index.mjs:18782).
///
/// Used by: TaskSection, TaskSectionBadge, TaskSectionChevron, TaskSectionCount, TaskSectionEmpty, TaskSectionHeading, TaskSectionItems, TaskSectionPanel, TaskSectionTrigger.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftTaskListSectionRecipe {
  static const String recipeName = 'taskListSection';
  static const List<String> slotNames = ['root', 'trigger', 'heading', 'badge', 'count', 'chevron', 'panel', 'items', 'empty'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftTaskListSectionRecipeStyle resolve({required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name], states, tokens);
    return RaftTaskListSectionRecipeStyle(root: s[0], trigger: s[1], heading: s[2], badge: s[3], count: s[4], chevron: s[5], panel: s[6], items: s[7], empty: s[8]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [2904],
    [1726, 1620, 3127, 3044, 2312, 2316, 1700, 3003, 2649, 1583, 1639, 1648, 1647, 1642],
    [1620, 2574, 2312, 1698],
    [2751, 2761, 2918, 2301, 2312, 1696, 864, 900, 1687, 1684, 3096, 2987, 428, 427, 453],
    [3032, 2333, 1689, 2992],
    [2301, 2867, 145, 2312, 3087, 430, 1846, 2593, 2992, 1907],
    [1463],
    [2902],
    [2753, 2770, 866, 886, 901, 3017, 2335, 2990],
    [2904, 2807, 740, 2672, 2865, 993],
    [1726, 1620, 3127, 3044, 2312, 2316, 1700, 3003, 2649, 1583, 2818, 2696, 2727, 1639, 1648, 1647, 1649, 1653, 1666, 1662, 1663, 1065, 1693],
    [1620, 2574, 2312, 1697],
    [2301, 2312, 1697, 2747, 2760, 1691, 3032, 2333, 1688, 2981, 430, 427],
    [3032, 2333, 1691, 1688, 2911, 2984],
    [2301, 2867, 145, 2312, 3087, 430, 1846, 2593, 2978, 1907],
    [2902, 401],
    [2753, 2770, 2817, 864, 886, 896, 795, 2924, 2334, 2984],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8], [9, 10, 11, 12, 13, 14, 6, 15, 16],
  ];
}
