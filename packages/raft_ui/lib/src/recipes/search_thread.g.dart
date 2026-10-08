// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `searchThread`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftSearchThreadRecipe].
class RaftSearchThreadRecipeStyle {
  const RaftSearchThreadRecipeStyle({required this.thread, required this.threadHeader, required this.threadMeta, required this.threadTimestamp, required this.threadTitle, required this.threadMessages});

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

  Map<String, RaftSlotStyle> get slots => {'thread': thread, 'threadHeader': threadHeader, 'threadMeta': threadMeta, 'threadTimestamp': threadTimestamp, 'threadTitle': threadTitle, 'threadMessages': threadMessages};
}

/// raft-ui recipe `searchThread` (`src/components/search/search-thread.recipe.ts`, index.mjs:20689).
///
/// Used by: SearchThreadResult, SearchThreadResultHeader, SearchThreadResultMessages, SearchThreadResultMeta, SearchThreadResultTimestamp, SearchThreadResultTitle.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftSearchThreadRecipe {
  static const String recipeName = 'searchThread';
  static const List<String> slotNames = ['thread', 'threadHeader', 'threadMeta', 'threadTimestamp', 'threadTitle', 'threadMessages'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftSearchThreadRecipeStyle resolve({required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name], states, tokens);
    return RaftSearchThreadRecipeStyle(thread: s[0], threadHeader: s[1], threadMeta: s[2], threadTimestamp: s[3], threadTitle: s[4], threadMessages: s[5]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [2656, 3084, 866, 880, 856, 2241, 2269, 1316, 1324],
    [2753, 2765, 875, 876, 752],
    [2491, 1620, 1626, 2312, 1698, 2920, 1684, 3096, 3055, 2964],
    [2612, 1689, 2961],
    [3017, 1684, 2956],
    [1620, 1622, 220],
    [2656, 2817, 867, 896, 825, 2865, 3062, 1602, 2185, 1317, 1318, 1322, 1320, 1321, 1026, 1009],
    [2765, 2753, 2736, 2683],
    [2491, 1620, 1626, 2312, 1698, 2920, 1688, 2981],
    [2612, 1691, 2911, 2982],
    [3017, 1688, 2987],
    [1620, 1622, 220, 2655, 914, 895, 850, 3084, 1602, 1004],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5], [6, 7, 8, 9, 10, 11],
  ];
}
