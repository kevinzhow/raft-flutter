// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `tasksPanel`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftTasksPanelRecipe].
class RaftTasksPanelRecipeStyle {
  const RaftTasksPanelRecipeStyle({
    required this.root,
    required this.toolbar,
    required this.toolbarGroup,
    required this.toolbarNewTask,
    required this.toolbarFilters,
    required this.toolbarView,
    required this.toolbarLabel,
    required this.viewport,
    required this.empty,
  });

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

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'toolbar': toolbar,
    'toolbarGroup': toolbarGroup,
    'toolbarNewTask': toolbarNewTask,
    'toolbarFilters': toolbarFilters,
    'toolbarView': toolbarView,
    'toolbarLabel': toolbarLabel,
    'viewport': viewport,
    'empty': empty,
  };
}

/// raft-ui recipe `tasksPanel` (`dist/components/tasks/tasks-panel.recipe.mjs`, index.mjs:23417).
///
/// Used by: TasksPanelEmpty, TasksPanelRoot, TasksPanelToolbar, TasksPanelToolbarFilters, TasksPanelToolbarGroup, TasksPanelToolbarLabel, TasksPanelToolbarNewTask, TasksPanelToolbarView, TasksPanelViewport.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftTasksPanelRecipe {
  static const String recipeName = 'tasksPanel';
  static const List<String> slotNames = [
    'root',
    'toolbar',
    'toolbarGroup',
    'toolbarNewTask',
    'toolbarFilters',
    'toolbarView',
    'toolbarLabel',
    'viewport',
    'empty',
  ];
  static const List<RaftRecipeAxis> axes = [];

  static RaftTasksPanelRecipeStyle resolve({
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
    return RaftTasksPanelRecipeStyle(
      root: s[0],
      toolbar: s[1],
      toolbarGroup: s[2],
      toolbarNewTask: s[3],
      toolbarFilters: s[4],
      toolbarView: s[5],
      toolbarLabel: s[6],
      viewport: s[7],
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
    [198, 1400, 2098, 2116, 1401, 1404, 910, 2598],
    [
      1489,
      2499,
      1495,
      1864,
      1466,
      247,
      248,
      249,
      250,
      2096,
      942,
      954,
      910,
      2396,
      2419,
      2013,
      214,
    ],
    [1400, 1408, 1864, 1466],
    [988, 2476, 1872, 1400, 1408, 1864, 1466],
    [983, 2477, 2116, 2225, 2226, 251, 1400, 1408, 1864, 1466],
    [989, 2476, 1871, 1400, 1408, 1864, 1466],
    [
      1847,
      1864,
      477,
      474,
      325,
      1661,
      2042,
      1465,
      2463,
      2402,
      933,
      1851,
      1855,
      1456,
      2597,
      1457,
      2603,
      2729,
    ],
    [2098, 1401, 2265, 2282, 910, 2396, 214],
    [1400, 1678, 1404, 1864, 1869],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8],
  ];
}
