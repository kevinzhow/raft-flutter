// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `tasksPanel`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftTasksPanelRecipe].
class RaftTasksPanelRecipeStyle {
  const RaftTasksPanelRecipeStyle({required this.root, required this.toolbar, required this.toolbarGroup, required this.toolbarNewTask, required this.toolbarFilters, required this.toolbarView, required this.toolbarLabel, required this.viewport, required this.empty});

  /// Slot `root`.
  final RaftSlotStyle root;
  /// Slot `toolbar`.
  final RaftSlotStyle toolbar;
  /// Slot `toolbarGroup`.
  final RaftSlotStyle toolbarGroup;
  /// Slot `toolbarNewTask`.
  final RaftSlotStyle toolbarNewTask;
  /// Slot `toolbarFilters`.
  final RaftSlotStyle toolbarFilters;
  /// Slot `toolbarView`.
  final RaftSlotStyle toolbarView;
  /// Slot `toolbarLabel`.
  final RaftSlotStyle toolbarLabel;
  /// Slot `viewport`.
  final RaftSlotStyle viewport;
  /// Slot `empty`.
  final RaftSlotStyle empty;

  Map<String, RaftSlotStyle> get slots => {'root': root, 'toolbar': toolbar, 'toolbarGroup': toolbarGroup, 'toolbarNewTask': toolbarNewTask, 'toolbarFilters': toolbarFilters, 'toolbarView': toolbarView, 'toolbarLabel': toolbarLabel, 'viewport': viewport, 'empty': empty};
}

/// raft-ui recipe `tasksPanel` (`src/components/tasks/tasks-panel.recipe.ts`, index.mjs:19063).
///
/// Used by: TasksPanelEmpty, TasksPanelRoot, TasksPanelToolbar, TasksPanelToolbarFilters, TasksPanelToolbarGroup, TasksPanelToolbarLabel, TasksPanelToolbarNewTask, TasksPanelToolbarView, TasksPanelViewport.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftTasksPanelRecipe {
  static const String recipeName = 'tasksPanel';
  static const List<String> slotNames = ['root', 'toolbar', 'toolbarGroup', 'toolbarNewTask', 'toolbarFilters', 'toolbarView', 'toolbarLabel', 'viewport', 'empty'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftTasksPanelRecipeStyle resolve({required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name], states, tokens);
    return RaftTasksPanelRecipeStyle(root: s[0], toolbar: s[1], toolbarGroup: s[2], toolbarNewTask: s[3], toolbarFilters: s[4], toolbarView: s[5], toolbarLabel: s[6], viewport: s[7], empty: s[8]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [1620, 2560, 2574, 1621, 1622, 825, 1002],
    [1717, 2867, 1722, 2312, 1698, 2755, 2767, 2513, 2518, 2534, 2536, 875, 900, 825],
    [1620, 1626, 2312, 1698],
    [936, 2826, 2320, 1620, 1626, 2312, 1698],
    [934, 2827, 2574, 2624, 2625, 2540, 1620, 1626, 2312, 1698],
    [937, 2826, 2319, 1620, 1626, 2312, 1698],
    [2301, 2312, 3032, 2333, 430, 427, 286, 1698, 866, 896, 825, 2753, 2763, 1687, 1684, 2995],
    [2560, 1621, 2654, 2664, 2673, 2689, 825],
    [1620, 1978, 1622, 2312, 2317],
    [1717, 2867, 1722, 2312, 1698, 2767, 2513, 2518, 2534, 2536, 873, 896, 825, 2758, 2440, 2443, 1002],
    [937, 2826, 2319, 1620, 1626, 2312, 1698, 399],
    [2301, 2312, 3032, 2333, 430, 427, 286, 1697, 2822, 864, 916, 850, 2752, 2773, 2850, 1691, 1688, 2981],
    [2560, 1621, 2654, 2664, 2673, 2689, 825, 2758, 2440, 2443, 1002],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8], [0, 9, 2, 3, 4, 10, 11, 12, 8],
  ];
}
