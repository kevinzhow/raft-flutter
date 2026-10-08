// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `taskBoardColumn`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftTaskBoardColumnRecipe].
class RaftTaskBoardColumnRecipeStyle {
  const RaftTaskBoardColumnRecipeStyle({required this.root, required this.trigger, required this.heading, required this.badge, required this.count, required this.chevron, required this.panel, required this.items, required this.empty, required this.emptyIdle, required this.emptyAllowed, required this.emptyBlocked});

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
  /// Slot `emptyIdle`.
  final RaftSlotStyle emptyIdle;
  /// Slot `emptyAllowed`.
  final RaftSlotStyle emptyAllowed;
  /// Slot `emptyBlocked`.
  final RaftSlotStyle emptyBlocked;

  Map<String, RaftSlotStyle> get slots => {'root': root, 'trigger': trigger, 'heading': heading, 'badge': badge, 'count': count, 'chevron': chevron, 'panel': panel, 'items': items, 'empty': empty, 'emptyIdle': emptyIdle, 'emptyAllowed': emptyAllowed, 'emptyBlocked': emptyBlocked};
}

/// raft-ui recipe `taskBoardColumn` (`src/components/task-board/task-board-column.recipe.ts`, index.mjs:18054).
///
/// Used by: TaskBoardColumn, TaskBoardColumnBadge, TaskBoardColumnChevron, TaskBoardColumnCount, TaskBoardColumnEmpty, TaskBoardColumnEmptyAllowed, TaskBoardColumnEmptyBlocked, TaskBoardColumnEmptyIdle, TaskBoardColumnHeading, TaskBoardColumnItems, TaskBoardColumnPanel, TaskBoardColumnTrigger.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftTaskBoardColumnRecipe {
  static const String recipeName = 'taskBoardColumn';
  static const List<String> slotNames = ['root', 'trigger', 'heading', 'badge', 'count', 'chevron', 'panel', 'items', 'empty', 'emptyIdle', 'emptyAllowed', 'emptyBlocked'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftTaskBoardColumnRecipeStyle resolve({required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name], states, tokens);
    return RaftTaskBoardColumnRecipeStyle(root: s[0], trigger: s[1], heading: s[2], badge: s[3], count: s[4], chevron: s[5], panel: s[6], items: s[7], empty: s[8], emptyIdle: s[9], emptyAllowed: s[10], emptyBlocked: s[11]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [1726, 1620, 3116, 2867, 2837, 1622, 2672, 866, 901, 826, 3084, 1220, 1218, 1221, 1223, 1222, 2107, 2106, 2108, 2110, 2109],
    [1726, 1620, 3127, 3044, 2312, 2316, 1700, 3003, 2649, 1300, 1639, 1648, 1647, 1642],
    [1620, 2574, 2312, 1698],
    [2751, 2761, 2918, 2301, 2312, 1696, 864, 900, 1687, 1684, 3096, 2987, 428, 427, 453],
    [3032, 2333, 1689, 2992],
    [2301, 2867, 145, 2312, 3087, 430, 1846, 2593, 2992, 1907],
    [1463],
    [1620, 1622, 1699],
    [2753, 2770, 1734, 866, 886, 901, 3017, 2335, 2990, 1733, 1735, 1737, 1740],
    [1734, 1739],
    [2174, 1732],
    [2174, 1736],
    [1726, 1620, 3116, 2867, 2837, 1622, 2672, 2807, 740, 993, 1217],
    [1726, 1620, 3127, 3044, 2312, 2316, 1700, 3003, 2649, 1300, 2818, 2701, 2718, 1639, 1648, 1647, 1649, 1653, 1666, 1662, 1664, 1065, 1693],
    [1620, 2574, 2312, 1697],
    [2301, 2312, 1697, 2747, 2760, 1691, 3032, 2333, 1688, 2981, 430, 427],
    [3032, 2333, 1691, 1688, 2911, 2984],
    [2301, 2867, 145, 2312, 3087, 430, 1846, 2593, 2978, 1907],
    [2753, 2770, 1734, 2817, 864, 886, 896, 825, 2924, 2334, 2984, 1738, 1740],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], [12, 13, 14, 15, 16, 17, 6, 7, 18, 9, 10, 11],
  ];
}
