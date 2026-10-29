// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `threadPanel`.
// ignore_for_file: type=lint

import '../recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftThreadPanelRecipe].
class RaftThreadPanelRecipeStyle {
  const RaftThreadPanelRecipeStyle({
    required this.root,
    required this.header,
    required this.content,
    required this.title,
    required this.titleMeta,
    required this.actions,
    required this.search,
    required this.searchTrailing,
    required this.searchCount,
    required this.originalMessage,
    required this.replySummary,
    required this.replyCount,
    required this.footer,
  });

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

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'header': header,
    'content': content,
    'title': title,
    'titleMeta': titleMeta,
    'actions': actions,
    'search': search,
    'searchTrailing': searchTrailing,
    'searchCount': searchCount,
    'originalMessage': originalMessage,
    'replySummary': replySummary,
    'replyCount': replyCount,
    'footer': footer,
  };
}

/// raft-ui recipe `threadPanel` (`src/components/thread-panel/thread-panel.recipe.ts`, index.mjs:17249).
///
/// Used by: ThreadPanelActions, ThreadPanelContent, ThreadPanelFooter, ThreadPanelHeader, ThreadPanelOriginalMessage, ThreadPanelReplyCount, ThreadPanelReplySummary, ThreadPanelRoot, ThreadPanelSearch, ThreadPanelSearchCount, ThreadPanelSearchTrailing, ThreadPanelTitle, ThreadPanelTitleMeta.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftThreadPanelRecipe {
  static const String recipeName = 'threadPanel';
  static const List<String> slotNames = [
    'root',
    'header',
    'content',
    'title',
    'titleMeta',
    'actions',
    'search',
    'searchTrailing',
    'searchCount',
    'originalMessage',
    'replySummary',
    'replyCount',
    'footer',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftThreadPanelRecipeStyle resolve({
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
    return RaftThreadPanelRecipeStyle(
      root: s[0],
      header: s[1],
      content: s[2],
      title: s[3],
      titleMeta: s[4],
      actions: s[5],
      search: s[6],
      searchTrailing: s[7],
      searchCount: s[8],
      originalMessage: s[9],
      replySummary: s[10],
      replyCount: s[11],
      footer: s[12],
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
    [2328, 1644, 2925, 2583, 1646, 1013, 868, 1716, 2994],
    [1644, 1946, 2902, 2331, 1725, 2784, 891, 892, 868],
    [1644, 2583, 2597, 1645, 1646, 868],
    [2378, 2597, 1645, 3133, 2993, 1709, 2994],
    [1715, 2998],
    [1644, 2902, 2331, 1722],
    [2804, 3180, 1644, 2902, 2331, 1722, 2784, 2794, 230, 101, 891, 892, 868],
    [2608, 1644, 2902, 2331, 1722],
    [2902, 3172, 1714, 3073, 2946, 2998],
    [2804, 2902, 868, 2780, 891, 892, 81],
    [2781, 2760],
    [2512, 889, 2706, 3007, 1714, 3073, 893, 2996],
    [3073, 927, 892, 868, 2998],
    [2328, 1644, 2925, 2583, 1646, 1013, 2804, 863, 1716, 3024],
    [
      1644,
      2902,
      2331,
      1725,
      2784,
      2804,
      2328,
      1978,
      2582,
      2406,
      566,
      825,
      2402,
      2460,
      2463,
      2567,
      2404,
      2434,
      2399,
      2394,
      2398,
      2400,
      2391,
      2401,
      2396,
      2395,
      2393,
      2392,
      2397,
      2389,
      2390,
    ],
    [1644, 2583, 2597, 1645, 1646, 2804, 2678, 830, 1022],
    [2378, 2597, 1645, 3133, 1712, 2963, 1713, 2366, 3095, 2946, 3018],
    [1715, 3018],
    [
      2804,
      3180,
      1644,
      2902,
      2331,
      1722,
      2784,
      2794,
      230,
      101,
      2403,
      2404,
      889,
      912,
      825,
    ],
    [2608, 1644, 2902, 2331, 1722, 251, 386, 387, 385],
    [2902, 3172, 1714, 3073, 2946, 3018],
    [2804, 2902, 863, 889, 912, 80],
    [2760, 2784, 2405],
    [2512, 889, 2706, 3007, 1714, 3073, 911, 3018],
    [3073, 2784, 2405, 2571, 2470, 3018],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
    [13, 14, 15, 16, 17, 5, 18, 19, 20, 21, 22, 23, 24],
  ];
}
