// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `taskLoading`.
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

/// raft-ui recipe `taskLoading` (`src/components/tasks/task-loading.recipe.ts`, index.mjs:19231).
///
/// Used by: TaskLoadingList, TaskLoadingRow.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftTaskLoadingRecipe {
  static const String recipeName = 'taskLoading';
  static const List<String> slotNames = ['list', 'row'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftTaskLoadingRecipeStyle resolve({required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name], states, tokens);
    return RaftTaskLoadingRecipeStyle(list: s[0], row: s[1]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [1620, 1622, 1698],
    [1620, 2574, 1622, 1697, 2672, 2822, 866, 902],
    [1620, 2574, 1622, 1697, 2672, 2817, 864, 896, 825, 2863, 1009],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1], [0, 2],
  ];
}
