// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `textarea`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftTextareaRecipe].
class RaftTextareaRecipeStyle {
  const RaftTextareaRecipeStyle({required this.root});

  /// Slot `root`.
  final RaftSlotStyle root;

  Map<String, RaftSlotStyle> get slots => {'root': root};
}

/// raft-ui recipe `textarea` (`src/components/textarea/textarea.tsx`, index.mjs:7926).
///
/// Used by: Textarea.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftTextareaRecipe {
  static const String recipeName = 'textarea';
  static const List<String> slotNames = ['root'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftTextareaRecipeStyle resolve({required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name], states, tokens);
    return RaftTextareaRecipeStyle(root: s[0]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [862, 3127, 2563, 2777, 2753, 2765, 2975, 1686, 2649, 866, 900, 825, 1687, 2863, 1679, 1499, 1498, 1511, 1509, 1510, 1584, 1588, 1591],
    [862, 3127, 2563, 2777, 2753, 2765, 1687, 2975, 1686, 2649, 2818, 864, 894, 825, 2860, 993, 1124, 1142, 1110, 2976, 3061, 1605, 1613, 1168, 2712, 2264, 1674, 1071, 1652, 1665, 1063, 1066, 1500, 1508, 1503, 1505, 1507, 1584, 1582, 1581, 1593, 1589, 1585, 1501, 1502],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0], [1],
  ];
}
