// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `textSelectionToolbar`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftTextSelectionToolbarRecipe].
class RaftTextSelectionToolbarRecipeStyle {
  const RaftTextSelectionToolbarRecipeStyle({
    required this.toolbar,
    required this.button,
    required this.separator,
  });

  /// Slot `toolbar`.
  final RaftSlotStyle toolbar;

  /// Slot `button`.
  final RaftSlotStyle button;

  /// Slot `separator`.
  final RaftSlotStyle separator;

  Map<String, RaftSlotStyle> get slots => {
    'toolbar': toolbar,
    'button': button,
    'separator': separator,
  };
}

/// raft-ui recipe `textSelectionToolbar` (`dist/components/text-selection-toolbar/text-selection-toolbar.recipe.mjs`, index.mjs:3215).
///
/// Used by: TextSelectionToolbar, TextSelectionToolbarButton, TextSelectionToolbarSeparator.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftTextSelectionToolbarRecipe {
  static const String recipeName = 'textSelectionToolbar';
  static const List<String> slotNames = ['toolbar', 'button', 'separator'];
  static const List<RaftRecipeAxis> axes = [];

  static RaftTextSelectionToolbarRecipeStyle resolve({
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
    return RaftTextSelectionToolbarRecipeStyle(
      toolbar: s[0],
      button: s[1],
      separator: s[2],
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
      1400,
      2116,
      1864,
      2483,
      1464,
      2253,
      2462,
      2261,
      2591,
      1449,
      915,
      2445,
      2449,
      2447,
      2496,
    ],
    [
      1400,
      2499,
      1864,
      1465,
      2247,
      2675,
      1659,
      2461,
      2042,
      2077,
      2402,
      2729,
      2598,
      1785,
      697,
      1439,
      478,
      474,
      492,
    ],
    [2727, 2499, 1656, 918],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2],
  ];
}
