// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `searchThread`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
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

/// raft-ui recipe `searchThread` (`dist/components/search/search-thread.recipe.mjs`, index.mjs:24726).
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
  static const List<RaftRecipeAxis> axes = [];

  static RaftSearchThreadRecipeStyle resolve({
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
    [2252, 2433, 2468, 940, 933, 2598, 2497],
    [2417, 2396, 2383, 2272],
    [1400, 1408, 1864, 1987, 1465, 1454, 2616, 1455, 2600],
    [2165, 2132],
    [1456, 2587, 1457, 2598],
    [1400, 1404, 1463, 2417, 962, 933],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5],
  ];
}
