// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
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

/// raft-ui recipe `taskCardStatus` (`src/components/task-card/task-card-status.recipe.ts`, index.mjs:18291).
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

  static RaftTaskCardStatusRecipeStyle resolve({required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name], states, tokens);
    return RaftTaskCardStatusRecipeStyle(base: s[0]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [2301, 2574, 2867, 3044, 2312, 1696, 3075, 1601, 2649, 1584, 1588, 1187, 1184, 1186, 1185, 2585, 866, 900, 2751, 2774, 2918, 2333, 1692, 2987, 213, 425, 428, 427, 453, 57, 58, 400, 2252, 1639, 1648, 1647, 1642],
    [2574, 2867, 3044, 1696, 1601, 2649, 1584, 1588, 1187, 1184, 1186, 1185, 1620, 1959, 2312, 2822, 864, 916, 2667, 2344, 2161, 298, 302, 291, 3075, 2254, 601, 1639, 1648, 1647, 1649, 1653, 1666, 1661, 1664, 1693],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0], [1],
  ];
}
