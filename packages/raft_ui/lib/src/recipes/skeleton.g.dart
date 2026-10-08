// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `skeleton`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `variant` axis of `skeleton` (default `block`).
enum RaftSkeletonRecipeVariant {
  line('line'),
  block('block'),
  circle('circle');

  const RaftSkeletonRecipeVariant(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftSkeletonRecipe].
class RaftSkeletonRecipeStyle {
  const RaftSkeletonRecipeStyle({required this.root});

  /// Slot `root`.
  final RaftSlotStyle root;

  Map<String, RaftSlotStyle> get slots => {'root': root};
}

/// raft-ui recipe `skeleton` (`src/components/skeleton/skeleton.tsx`, index.mjs:14299).
///
/// Used by: Skeleton.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftSkeletonRecipe {
  static const String recipeName = 'skeleton';
  static const List<String> slotNames = ['root'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
    RaftRecipeAxis('variant', ['line', 'block', 'circle'], 'block', false),
  ];

  static RaftSkeletonRecipeStyle resolve({required RaftRecipeTheme theme, RaftSkeletonRecipeVariant? variant, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name, variant?.css], states, tokens);
    return RaftSkeletonRecipeStyle(root: s[0]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [641, 2716, 1373, 1370, 1958],
    [641, 2716, 1373, 1370],
    [641, 2716, 1373, 1370, 2815, 815],
    [641, 2716, 1374, 1372, 1371, 1369, 1958],
    [641, 2716, 1374, 1372, 1371, 1369],
    [641, 2716, 1374, 1372, 1371, 1369, 2815, 808],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0], [1], [2], [3], [4], [5],
  ];
}
