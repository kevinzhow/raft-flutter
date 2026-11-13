// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `taskDnd`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
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

/// raft-ui recipe `taskDnd` (`dist/components/task-dnd/task-dnd.recipe.mjs`, index.mjs:20977).
///
/// Used by: TaskDragOverlay, TaskDraggable, TaskDropPlaceholder.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftTaskDndRecipe {
  static const String recipeName = 'taskDnd';
  static const List<String> slotNames = ['draggable', 'overlay', 'placeholder'];
  static const List<RaftRecipeAxis> axes = [];

  static RaftTaskDndRecipeStyle resolve({
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
      1625,
      2433,
      1862,
      995,
      2650,
      2483,
      603,
      698,
      2247,
      1018,
      1017,
      1009,
      1014,
      2462,
      1439,
    ],
    [1624, 2346, 2538, 2459],
    [1776, 2725, 2499, 1641, 2462, 1021],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2],
  ];
}
