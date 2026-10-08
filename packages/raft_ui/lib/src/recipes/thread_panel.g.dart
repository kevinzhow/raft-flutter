// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `threadPanel`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftThreadPanelRecipe].
class RaftThreadPanelRecipeStyle {
  const RaftThreadPanelRecipeStyle({required this.root, required this.header, required this.content, required this.title, required this.titleMeta, required this.actions, required this.search, required this.searchTrailing, required this.searchCount, required this.originalMessage, required this.replySummary, required this.replyCount, required this.footer});

  /// Slot `root`.
  final RaftSlotStyle root;
  /// Slot `header`.
  final RaftSlotStyle header;
  /// Slot `content`.
  final RaftSlotStyle content;
  /// Slot `title`.
  final RaftSlotStyle title;
  /// Slot `titleMeta`.
  final RaftSlotStyle titleMeta;
  /// Slot `actions`.
  final RaftSlotStyle actions;
  /// Slot `search`.
  final RaftSlotStyle search;
  /// Slot `searchTrailing`.
  final RaftSlotStyle searchTrailing;
  /// Slot `searchCount`.
  final RaftSlotStyle searchCount;
  /// Slot `originalMessage`.
  final RaftSlotStyle originalMessage;
  /// Slot `replySummary`.
  final RaftSlotStyle replySummary;
  /// Slot `replyCount`.
  final RaftSlotStyle replyCount;
  /// Slot `footer`.
  final RaftSlotStyle footer;

  Map<String, RaftSlotStyle> get slots => {'root': root, 'header': header, 'content': content, 'title': title, 'titleMeta': titleMeta, 'actions': actions, 'search': search, 'searchTrailing': searchTrailing, 'searchCount': searchCount, 'originalMessage': originalMessage, 'replySummary': replySummary, 'replyCount': replyCount, 'footer': footer};
}

/// raft-ui recipe `threadPanel` (`src/components/thread-panel/thread-panel.recipe.ts`, index.mjs:16989).
///
/// Used by: ThreadPanelActions, ThreadPanelContent, ThreadPanelFooter, ThreadPanelHeader, ThreadPanelOriginalMessage, ThreadPanelReplyCount, ThreadPanelReplySummary, ThreadPanelRoot, ThreadPanelSearch, ThreadPanelSearchCount, ThreadPanelSearchTrailing, ThreadPanelTitle, ThreadPanelTitleMeta.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftThreadPanelRecipe {
  static const String recipeName = 'threadPanel';
  static const List<String> slotNames = ['root', 'header', 'content', 'title', 'titleMeta', 'actions', 'search', 'searchTrailing', 'searchCount', 'originalMessage', 'replySummary', 'replyCount', 'footer'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftThreadPanelRecipeStyle resolve({required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name], states, tokens);
    return RaftThreadPanelRecipeStyle(root: s[0], header: s[1], content: s[2], title: s[3], titleMeta: s[4], actions: s[5], search: s[6], searchTrailing: s[7], searchCount: s[8], originalMessage: s[9], replySummary: s[10], replyCount: s[11], footer: s[12]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [2309, 1620, 2890, 2560, 1622, 993, 856, 1691, 2956],
    [1620, 1944, 2867, 2312, 1700, 2756, 875, 876, 856],
    [1620, 2560, 2574, 1621, 1622, 856],
    [2359, 2574, 1621, 3092, 2955, 1684, 2956],
    [1690, 2961],
    [1620, 2867, 2312, 1697],
    [2775, 3139, 1620, 2867, 2312, 1697, 2756, 2765, 232, 101, 875, 876, 856],
    [2585, 1620, 2867, 2312, 1697],
    [2867, 3131, 1689, 3032, 2911, 2961],
    [2775, 2867, 856, 2752, 875, 876, 81],
    [2753, 2735],
    [2491, 873, 2683, 2970, 1689, 3032, 877, 2959],
    [3032, 913, 876, 856, 2961],
    [2309, 1620, 2890, 2560, 1622, 993, 2775, 850, 1691, 2987, 1118],
    [1620, 2867, 2312, 1700, 2756, 2775, 2309, 1976, 2559, 2387, 565, 820, 2383, 2440, 2443, 2544, 2385, 2413, 2380, 2375, 2379, 2381, 2372, 2382, 2377, 2376, 2374, 2373, 2378, 2370, 2371],
    [1620, 2560, 2574, 1621, 1622, 2775, 2655, 825, 1002, 348],
    [2359, 2574, 1621, 3092, 1687, 2925, 1688, 2347, 3054, 2911, 2981],
    [1690, 2981],
    [2775, 3139, 1620, 2867, 2312, 1697, 2756, 2765, 232, 101, 2384, 2385, 873, 896, 820],
    [2585, 1620, 2867, 2312, 1697, 255, 388, 389, 387],
    [2867, 3131, 1689, 3032, 2911, 2981],
    [2775, 2867, 850, 873, 896, 80],
    [2735, 2756, 2386],
    [2491, 873, 2683, 2970, 1689, 3032, 895, 2981],
    [3032, 2756, 2386, 2548, 2450, 2981],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], [13, 14, 15, 16, 17, 5, 18, 19, 20, 21, 22, 23, 24],
  ];
}
