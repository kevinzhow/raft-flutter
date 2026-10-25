// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `taskStatusSoft`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `status` axis of `taskStatusSoft`.
enum RaftTaskStatusSoftRecipeStatus {
  todo('todo'),
  inProgress('in-progress'),
  inReview('in-review'),
  done('done'),
  closed('closed');

  const RaftTaskStatusSoftRecipeStatus(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftTaskStatusSoftRecipe].
class RaftTaskStatusSoftRecipeStyle {
  const RaftTaskStatusSoftRecipeStyle({required this.base});

  /// Slot `base`.
  final RaftSlotStyle base;

  Map<String, RaftSlotStyle> get slots => {'base': base};
}

/// raft-ui recipe `taskStatusSoft` (`src/components/tasks/task-status.recipe.ts`, index.mjs:18091).
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftTaskStatusSoftRecipe {
  static const String recipeName = 'taskStatusSoft';
  static const List<String> slotNames = ['base'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis(
      'status',
      ['todo', 'in-progress', 'in-review', 'done', 'closed'],
      null,
      true,
    ),
  ];

  static RaftTaskStatusSoftRecipeStyle resolve({
    RaftTaskStatusSoftRecipeStatus? status,
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
    return RaftTaskStatusSoftRecipeStyle(base: s[0]);
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
    [862],
    [858],
    [860],
    [856],
    [854],
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
