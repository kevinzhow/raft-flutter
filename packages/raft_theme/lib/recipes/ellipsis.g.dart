// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `ellipsis`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftEllipsisRecipe].
class RaftEllipsisRecipeStyle {
  const RaftEllipsisRecipeStyle({
    required this.root,
    required this.text,
    required this.content,
    required this.spacer,
    required this.after,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `text`.
  final RaftSlotStyle text;

  /// Slot `content`.
  final RaftSlotStyle content;

  /// Slot `spacer`.
  final RaftSlotStyle spacer;

  /// Slot `after`.
  final RaftSlotStyle after;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'text': text,
    'content': content,
    'spacer': spacer,
    'after': after,
  };
}

/// raft-ui recipe `ellipsis` (`dist/components/ellipsis/ellipsis.mjs`, index.mjs:27457).
///
/// Used by: Ellipsis.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftEllipsisRecipe {
  static const String recipeName = 'ellipsis';
  static const List<String> slotNames = [
    'root',
    'text',
    'content',
    'spacer',
    'after',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('multiline', ['true', 'false'], null, true),
    RaftRecipeAxis('expanded', ['true', 'false'], null, true),
    RaftRecipeAxis('clickable', ['true', 'false'], null, true),
  ];

  static RaftEllipsisRecipeStyle resolve({
    bool? multiline,
    bool? expanded,
    bool? clickable,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [multiline?.toString(), expanded?.toString(), clickable?.toString()],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftEllipsisRecipeStyle(
      root: s[0],
      text: s[1],
      content: s[2],
      spacer: s[3],
      after: s[4],
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
    [1603, 2116, 1980, 1847, 1863, 1477, 760],
    [2116, 2681, 2370, 2371],
    [],
    [1410, 1669, 2693, 1236, 1565],
    [1236, 1565, 2499],
    [2116, 997, 2681, 2370, 2371],
    [2116, 2733, 2728],
    [2116, 997, 2733, 2728],
    [1603, 2116, 1980, 1400],
    [2116, 1401, 2734, 1899, 2369],
    [1236, 1565, 1410, 979, 2372],
    [2116, 1401, 2734, 997, 1899, 2369],
    [2116, 1401, 2734, 1903],
    [2116, 1401, 2734, 997, 1903],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4],
    [0, 5, 2, 3, 4],
    [0, 1, 2, 3, 4],
    [0, 6, 2, 3, 4],
    [0, 7, 2, 3, 4],
    [0, 6, 2, 3, 4],
    [0, 1, 2, 3, 4],
    [0, 5, 2, 3, 4],
    [0, 1, 2, 3, 4],
    [8, 9, 2, 3, 10],
    [8, 11, 2, 3, 10],
    [8, 9, 2, 3, 10],
    [8, 12, 2, 3, 10],
    [8, 13, 2, 3, 10],
    [8, 12, 2, 3, 10],
    [8, 9, 2, 3, 10],
    [8, 11, 2, 3, 10],
    [8, 9, 2, 3, 10],
    [0, 1, 2, 3, 4],
    [0, 5, 2, 3, 4],
    [0, 1, 2, 3, 4],
    [0, 6, 2, 3, 4],
    [0, 7, 2, 3, 4],
    [0, 6, 2, 3, 4],
    [0, 1, 2, 3, 4],
    [0, 5, 2, 3, 4],
    [0, 1, 2, 3, 4],
  ];
}
