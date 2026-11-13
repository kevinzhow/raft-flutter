// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `input`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftInputRecipe].
class RaftInputRecipeStyle {
  const RaftInputRecipeStyle({required this.root});

  /// Slot `root`.
  final RaftSlotStyle root;

  Map<String, RaftSlotStyle> get slots => {'root': root};
}

/// raft-ui recipe `input` (`dist/components/input/input.recipe.mjs`, index.mjs:7506).
///
/// Used by: Input.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftInputRecipe {
  static const String recipeName = 'input';
  static const List<String> slotNames = ['root'];
  static const List<RaftRecipeAxis> axes = [];

  static const List<RaftRecipePackBinding> _packBindings = [
    RaftRecipePackBinding(
      'root',
      'border-top-left-radius',
      RaftRecipeTokenKind.number,
      'radius.control',
    ),
    RaftRecipePackBinding(
      'root',
      'border-top-right-radius',
      RaftRecipeTokenKind.number,
      'radius.control',
    ),
    RaftRecipePackBinding(
      'root',
      'border-bottom-left-radius',
      RaftRecipeTokenKind.number,
      'radius.control',
    ),
    RaftRecipePackBinding(
      'root',
      'border-bottom-right-radius',
      RaftRecipeTokenKind.number,
      'radius.control',
    ),
  ];

  static RaftInputRecipeStyle resolve({
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
      bindings: _packBindings,
    );
    return RaftInputRecipeStyle(root: s[0]);
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
      bindings: _packBindings,
    );
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [
      1674,
      2725,
      2403,
      2412,
      1452,
      2596,
      1451,
      2247,
      2454,
      941,
      952,
      911,
      2598,
      2311,
      2497,
      2677,
      1373,
      1376,
      1439,
      1252,
      1353,
      1350,
      1347,
      1363,
      1359,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0],
  ];
}
