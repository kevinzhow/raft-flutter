// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
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

/// raft-ui recipe `tasksPanel` (`src/components/tasks/tasks-panel.recipe.ts`, index.mjs:19194).
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
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftTasksPanelRecipeStyle resolve({
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
    [1644, 2583, 2597, 1645, 1646, 830, 1022],
    [
      1742,
      2902,
      1747,
      2331,
      1723,
      2783,
      2796,
      2535,
      2540,
      2557,
      2559,
      891,
      916,
      830,
    ],
    [1644, 1650, 2331, 1723],
    [956, 2859, 2339, 1644, 1650, 2331, 1723],
    [948, 2860, 2597, 2646, 2647, 2563, 1644, 1650, 2331, 1723],
    [957, 2859, 2338, 1644, 1650, 2331, 1723],
    [
      2320,
      2331,
      3073,
      2352,
      428,
      425,
      282,
      1723,
      878,
      912,
      830,
      2781,
      2792,
      1712,
      1709,
      3032,
    ],
    [2583, 1645, 2677, 2687, 2696, 2712, 830],
    [1644, 1980, 1646, 2331, 2336],
    [
      1742,
      2902,
      1747,
      2331,
      1723,
      2796,
      2535,
      2540,
      2557,
      2559,
      889,
      912,
      830,
      2786,
      2460,
      2463,
      1022,
    ],
    [957, 2859, 2338, 1644, 1650, 2331, 1723, 397],
    [
      2320,
      2331,
      3073,
      2352,
      428,
      425,
      282,
      1722,
      2852,
      876,
      930,
      863,
      2780,
      2802,
      2884,
      1716,
      1713,
      3018,
    ],
    [2583, 1645, 2677, 2687, 2696, 2712, 830, 2786, 2460, 2463, 1022],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8],
    [0, 9, 2, 3, 4, 10, 11, 12, 8],
  ];
}
