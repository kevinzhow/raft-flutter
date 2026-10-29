// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `taskDnd`.
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

/// raft-ui recipe `taskDnd` (`src/components/task-dnd/task-dnd.recipe.ts`, index.mjs:15025).
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
    [1161, 1682, 662, 1870, 428, 1577, 686, 685, 677, 682, 1709, 996],
    [1160, 1630, 1941, 45],
    [1265, 1929, 1740, 1169, 1709, 622, 626, 635, 615, 689],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2],
  ];
}
