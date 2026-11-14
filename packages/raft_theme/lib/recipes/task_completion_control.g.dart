// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `taskCompletionControl`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftTaskCompletionControlRecipe].
class RaftTaskCompletionControlRecipeStyle {
  const RaftTaskCompletionControlRecipeStyle({
    required this.root,
    required this.indicator,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `indicator`.
  final RaftSlotStyle indicator;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'indicator': indicator,
  };
}

/// raft-ui recipe `taskCompletionControl` (`dist/components/task-completion-control/task-completion-control.mjs`, index.mjs:29205).
///
/// Used by: TaskCompletionControl.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftTaskCompletionControlRecipe {
  static const String recipeName = 'taskCompletionControl';
  static const List<String> slotNames = ['root', 'indicator'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('preview', ['true', 'false'], null, true),
  ];

  static RaftTaskCompletionControlRecipeStyle resolve({
    bool? preview,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [preview?.toString()],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftTaskCompletionControlRecipeStyle(root: s[0], indicator: s[1]);
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
      2433,
      1847,
      2519,
      2499,
      2650,
      1864,
      1869,
      2247,
      997,
      2466,
      1181,
      723,
      702,
      729,
      2319,
      1439,
    ],
    [2346],
    [
      2433,
      1847,
      2519,
      2499,
      2650,
      1864,
      1869,
      2247,
      997,
      2466,
      1181,
      723,
      702,
      729,
      2319,
      1439,
      1777,
    ],
    [2346, 1592],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1],
    [2, 3],
    [0, 1],
  ];
}
