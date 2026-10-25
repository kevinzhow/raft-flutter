// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `taskStatus`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `status` axis of `taskStatus`.
enum RaftTaskStatusRecipeStatus {
  todo('todo'),
  inProgress('in-progress'),
  inReview('in-review'),
  done('done'),
  closed('closed');

  const RaftTaskStatusRecipeStatus(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftTaskStatusRecipe].
class RaftTaskStatusRecipeStyle {
  const RaftTaskStatusRecipeStyle({required this.base});

  /// Slot `base`.
  final RaftSlotStyle base;

  Map<String, RaftSlotStyle> get slots => {'base': base};
}

/// raft-ui recipe `taskStatus` (`src/components/tasks/task-status.recipe.ts`, index.mjs:18082).
///
/// Used by: TaskBoardColumnBadge, TaskCardStatus, TaskChip, TaskSectionBadge, TimelineItem.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftTaskStatusRecipe {
  static const String recipeName = 'taskStatus';
  static const List<String> slotNames = ['base'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis(
      'status',
      ['todo', 'in-progress', 'in-review', 'done', 'closed'],
      null,
      true,
    ),
  ];

  static RaftTaskStatusRecipeStyle resolve({
    RaftTaskStatusRecipeStatus? status,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [status?.css],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftTaskStatusRecipeStyle(base: s[0]);
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
    [],
    [861],
    [857],
    [859],
    [855],
    [853],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0],
    [1],
    [2],
    [3],
    [4],
    [5],
  ];
}
