// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
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

/// raft-ui recipe `skeleton` (`src/components/skeleton/skeleton.tsx`, index.mjs:12213).
///
/// Used by: Skeleton.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftSkeletonRecipe {
  static const String recipeName = 'skeleton';
  static const List<String> slotNames = ['root'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('variant', ['line', 'block', 'circle'], 'block', false),
  ];

  static RaftSkeletonRecipeStyle resolve({
    RaftSkeletonRecipeVariant? variant,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [variant?.css],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftSkeletonRecipeStyle(root: s[0]);
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
    [473, 1500, 1628, 789, 788, 787, 786, 1180],
    [473, 1500, 1628, 789, 788, 787, 786],
    [473, 1500, 1628, 789, 788, 787, 786, 1714, 581],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0],
    [1],
    [2],
  ];
}
