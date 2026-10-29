// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `taskDnd`.
// ignore_for_file: type=lint

import '../recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftTaskDndRecipe].
class RaftTaskDndRecipeStyle {
  const RaftTaskDndRecipeStyle({
    required this.draggable,
    required this.overlay,
    required this.placeholder,
  });

  /// Slot `draggable`.
  final RaftSlotStyle draggable;

  /// Slot `overlay`.
  final RaftSlotStyle overlay;

  /// Slot `placeholder`.
  final RaftSlotStyle placeholder;

  Map<String, RaftSlotStyle> get slots => {
    'draggable': draggable,
    'overlay': overlay,
    'placeholder': placeholder,
  };
}

/// raft-ui recipe `taskDnd` (`src/components/task-dnd/task-dnd.recipe.ts`, index.mjs:18648).
///
/// Used by: TaskDragOverlay, TaskDraggable, TaskDropPlaceholder.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftTaskDndRecipe {
  static const String recipeName = 'taskDnd';
  static const List<String> slotNames = ['draggable', 'overlay', 'placeholder'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftTaskDndRecipeStyle resolve({
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
    return RaftTaskDndRecipeStyle(
      draggable: s[0],
      overlay: s[1],
      placeholder: s[2],
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
    [
      1939,
      2804,
      961,
      3086,
      600,
      2672,
      1235,
      1234,
      1215,
      1226,
      1663,
      1672,
      1671,
      1666,
      1233,
    ],
    [1938, 2739, 3180, 2655, 59],
    [2189, 3168, 2902, 1947, 878, 902, 916, 844, 1238],
    [
      1939,
      2804,
      961,
      3086,
      600,
      2672,
      1235,
      1234,
      1215,
      1226,
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
    [1938, 2739],
    [2189, 3168, 2902, 1947, 2847, 876, 902, 912, 745, 1238],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2],
    [3, 4, 5],
  ];
}
