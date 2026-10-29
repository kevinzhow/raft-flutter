// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `searchThread`.
// ignore_for_file: type=lint

import '../recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftSearchThreadRecipe].
class RaftSearchThreadRecipeStyle {
  const RaftSearchThreadRecipeStyle({
    required this.thread,
    required this.threadHeader,
    required this.threadMeta,
    required this.threadTimestamp,
    required this.threadTitle,
    required this.threadMessages,
  });

  /// Slot `thread`.
  final RaftSlotStyle thread;

  /// Slot `threadHeader`.
  final RaftSlotStyle threadHeader;

  /// Slot `threadMeta`.
  final RaftSlotStyle threadMeta;

  /// Slot `threadTimestamp`.
  final RaftSlotStyle threadTimestamp;

  /// Slot `threadTitle`.
  final RaftSlotStyle threadTitle;

  /// Slot `threadMessages`.
  final RaftSlotStyle threadMessages;

  Map<String, RaftSlotStyle> get slots => {
    'thread': thread,
    'threadHeader': threadHeader,
    'threadMeta': threadMeta,
    'threadTimestamp': threadTimestamp,
    'threadTitle': threadTitle,
    'threadMessages': threadMessages,
  };
}

/// raft-ui recipe `searchThread` (`src/components/search/search-thread.recipe.ts`, index.mjs:20838).
///
/// Used by: SearchThreadResult, SearchThreadResultHeader, SearchThreadResultMessages, SearchThreadResultMeta, SearchThreadResultTimestamp, SearchThreadResultTitle.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftSearchThreadRecipe {
  static const String recipeName = 'searchThread';
  static const List<String> slotNames = [
    'thread',
    'threadHeader',
    'threadMeta',
    'threadTimestamp',
    'threadTitle',
    'threadMessages',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftSearchThreadRecipeStyle resolve({
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
    return RaftSearchThreadRecipeStyle(
      thread: s[0],
      threadHeader: s[1],
      threadMeta: s[2],
      threadTimestamp: s[3],
      threadTitle: s[4],
      threadMessages: s[5],
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
    [2679, 3125, 878, 896, 868, 2260, 2288, 1338, 1346],
    [2781, 2794, 891, 892, 758],
    [2512, 1644, 1650, 2331, 1723, 2958, 1709, 3137, 3096, 3001],
    [2634, 1714, 2998],
    [3053, 1709, 2994],
    [1644, 1646, 218],
    [
      2679,
      2847,
      879,
      912,
      830,
      2899,
      3103,
      1626,
      2204,
      1339,
      1340,
      1344,
      1342,
      1343,
      1046,
      1029,
    ],
    [2794, 2781, 2761, 2706],
    [2512, 1644, 1650, 2331, 1723, 2958, 1713, 3018],
    [2634, 1716, 2946, 3019],
    [3053, 1713, 3024],
    [1644, 1646, 218, 2678, 928, 911, 863, 3125, 1626, 1024],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5],
    [6, 7, 8, 9, 10, 11],
  ];
}
