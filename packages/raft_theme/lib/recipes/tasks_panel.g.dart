// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `tasksPanel`.
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

/// raft-ui recipe `tasksPanel` (`src/components/tasks/tasks-panel.recipe.ts`, index.mjs:15421).
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
    [965, 1465, 1481, 966, 967, 595, 1818],
    [
      1039,
      1736,
      1043,
      1318,
      1022,
      1437,
      1439,
      1452,
      1453,
      1469,
      623,
      634,
      595,
      1659,
      1669,
      1390,
    ],
    [965, 971, 1318, 1022],
    [657, 1717, 1326, 965, 971, 1318, 1022],
    [653, 1718, 1481, 1551, 1552, 1457, 965, 971, 1318, 1022],
    [658, 1717, 1325, 965, 971, 1318, 1022],
    [
      1304,
      1318,
      279,
      277,
      158,
      1187,
      1021,
      1706,
      1655,
      615,
      1308,
      1311,
      1015,
      1817,
      1016,
      1823,
      1928,
    ],
    [1465, 966, 1577, 1585, 1593, 1606, 595, 1659, 1390],
    [965, 1197, 967, 1318, 1323],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8],
  ];
}
