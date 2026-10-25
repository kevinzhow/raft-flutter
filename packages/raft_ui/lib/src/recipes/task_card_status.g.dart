// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `taskCardStatus`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftTaskCardStatusRecipe].
class RaftTaskCardStatusRecipeStyle {
  const RaftTaskCardStatusRecipeStyle({required this.base});

  /// Slot `base`.
  final RaftSlotStyle base;

  Map<String, RaftSlotStyle> get slots => {'base': base};
}

/// raft-ui recipe `taskCardStatus` (`src/components/task-card/task-card-status.recipe.ts`, index.mjs:18428).
///
/// Used by: TaskCardStatus.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftTaskCardStatusRecipe {
  static const String recipeName = 'taskCardStatus';
  static const List<String> slotNames = ['base'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftTaskCardStatusRecipeStyle resolve({
    required RaftRecipeTheme theme,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [theme.name],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftTaskCardStatusRecipeStyle(base: s[0]);
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
      2320,
      2597,
      2902,
      3085,
      2331,
      1721,
      3116,
      1625,
      2672,
      1608,
      1612,
      1206,
      1203,
      1205,
      1204,
      2608,
      878,
      916,
      2779,
      2803,
      2956,
      2352,
      1717,
      3024,
      211,
      423,
      426,
      425,
      451,
      57,
      58,
      398,
      2271,
      1663,
      1672,
      1671,
      1666,
    ],
    [
      2597,
      2902,
      3085,
      1721,
      1625,
      2672,
      1608,
      1612,
      1206,
      1203,
      1205,
      1204,
      1644,
      1961,
      2331,
      2852,
      876,
      930,
      2690,
      2363,
      2172,
      294,
      298,
      287,
      3116,
      2273,
      607,
      1663,
      1672,
      1671,
      1673,
      1677,
      1690,
      1685,
      1688,
      1718,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0],
    [1],
  ];
}
