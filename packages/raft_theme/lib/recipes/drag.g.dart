// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `drag`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftDragRecipe].
class RaftDragRecipeStyle {
  const RaftDragRecipeStyle({
    required this.lift,
    required this.placeholder,
    required this.hint,
  });

  /// Slot `lift`.
  final RaftSlotStyle lift;

  /// Slot `placeholder`.
  final RaftSlotStyle placeholder;

  /// Slot `hint`.
  final RaftSlotStyle hint;

  Map<String, RaftSlotStyle> get slots => {
    'lift': lift,
    'placeholder': placeholder,
    'hint': hint,
  };
}

/// raft-ui recipe `drag` (`dist/components/drag/drag.recipe.mjs`, index.mjs:16974).
///
/// Used by: DragLift, DragRefusalHint, DropPlaceholder, TaskDropPlaceholder.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftDragRecipe {
  static const String recipeName = 'drag';
  static const List<String> slotNames = ['lift', 'placeholder', 'hint'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('opaque', ['true', 'false'], null, true),
  ];

  static RaftDragRecipeStyle resolve({
    bool? opaque,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [opaque?.toString()],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftDragRecipeStyle(lift: s[0], placeholder: s[1], hint: s[2]);
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
    [2346, 2538, 2463, 915, 2496, 2445, 2449],
    [2346, 975, 2463, 941, 945, 955, 896],
    [
      2346,
      1399,
      2640,
      1895,
      2743,
      1961,
      2461,
      2401,
      2414,
      1456,
      2588,
      914,
      2605,
      2496,
      2445,
      2449,
    ],
    [2346, 975, 2463, 941, 945, 955, 910, 881],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2],
    [0, 3, 2],
    [0, 1, 2],
  ];
}
