// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `taskDnd`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftTaskDndRecipe].
class RaftTaskDndRecipeStyle {
  const RaftTaskDndRecipeStyle({required this.draggable, required this.overlay, required this.placeholder});

  /// Slot `draggable`.
  final RaftSlotStyle draggable;
  /// Slot `overlay`.
  final RaftSlotStyle overlay;
  /// Slot `placeholder`.
  final RaftSlotStyle placeholder;

  Map<String, RaftSlotStyle> get slots => {'draggable': draggable, 'overlay': overlay, 'placeholder': placeholder};
}

/// raft-ui recipe `taskDnd` (`src/components/task-dnd/task-dnd.recipe.ts`, index.mjs:18514).
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

  static RaftTaskDndRecipeStyle resolve({required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name], states, tokens);
    return RaftTaskDndRecipeStyle(draggable: s[0], overlay: s[1], placeholder: s[2]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [1937, 2775, 941, 3045, 594, 2649, 1216, 1215, 1196, 1207, 1639, 1648, 1647, 1642, 1214],
    [1936, 2716, 3139, 2632, 59],
    [2174, 3127, 2867, 1945, 866, 886, 900, 840, 1219],
    [1937, 2775, 941, 3045, 594, 2649, 1216, 1215, 1196, 1207, 1639, 1648, 1647, 1649, 1653, 1666, 1662, 1663, 1065, 1693],
    [1936, 2716],
    [2174, 3127, 2867, 1945, 2817, 864, 886, 896, 739, 1219],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2], [3, 4, 5],
  ];
}
