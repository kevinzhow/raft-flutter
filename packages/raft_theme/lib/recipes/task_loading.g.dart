// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `taskLoading`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftTaskLoadingRecipe].
class RaftTaskLoadingRecipeStyle {
  const RaftTaskLoadingRecipeStyle({required this.list, required this.row});

  /// Slot `list`.
  final RaftSlotStyle list;

  /// Slot `row`.
  final RaftSlotStyle row;

  Map<String, RaftSlotStyle> get slots => {'list': list, 'row': row};
}

/// raft-ui recipe `taskLoading` (`dist/components/tasks/task-loading.recipe.mjs`, index.mjs:23563).
///
/// Used by: TaskLoadingList, TaskLoadingRow.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftTaskLoadingRecipe {
  static const String recipeName = 'taskLoading';
  static const List<String> slotNames = ['list', 'row'];
  static const List<RaftRecipeAxis> axes = [];

  static RaftTaskLoadingRecipeStyle resolve({
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
    return RaftTaskLoadingRecipeStyle(list: s[0], row: s[1]);
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
    [1400, 1404, 1466],
    [1400, 2116, 1404, 2264, 1466, 2462, 939, 953, 911, 2497],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1],
  ];
}
