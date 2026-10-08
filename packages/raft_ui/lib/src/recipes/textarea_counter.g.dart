// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `textareaCounter`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftTextareaCounterRecipe].
class RaftTextareaCounterRecipeStyle {
  const RaftTextareaCounterRecipeStyle({required this.root});

  /// Slot `root`.
  final RaftSlotStyle root;

  Map<String, RaftSlotStyle> get slots => {'root': root};
}

/// raft-ui recipe `textareaCounter` (`src/components/textarea/textarea.tsx`, index.mjs:7966).
///
/// Used by: TextareaCounter.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftTextareaCounterRecipe {
  static const String recipeName = 'textareaCounter';
  static const List<String> slotNames = ['root'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
    RaftRecipeAxis('overLimit', ['true', 'false'], 'false', false),
  ];

  static RaftTextareaCounterRecipeStyle resolve({required RaftRecipeTheme theme, bool? overLimit, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name, overLimit?.toString()], states, tokens);
    return RaftTextareaCounterRecipeStyle(root: s[0]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [1689, 3032, 2911, 1744, 1843, 2972],
    [1689, 3032, 2911, 2992, 1744, 1843],
    [1689, 2911, 2920, 2344, 3061, 1605, 1613, 1745, 1843, 2972],
    [1689, 2911, 2920, 2344, 2986, 3061, 1605, 1613, 1745, 1843],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0], [1], [2], [3],
  ];
}
