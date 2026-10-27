// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `threadPanel`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
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

/// raft-ui recipe `threadPanel` (`src/components/thread-panel/thread-panel.recipe.ts`, index.mjs:14244).
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
  static const List<RaftRecipeAxis> axes = [];

  static RaftThreadPanelRecipeStyle resolve({
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
    [1317, 965, 1768, 1467, 967, 1680, 595, 1016, 1820],
    [
      965,
      1168,
      1738,
      1319,
      1025,
      1382,
      1636,
      1621,
      1390,
      1388,
      1375,
      126,
      1374,
      623,
      634,
      595,
    ],
    [965, 1467, 1483, 966, 967, 1680, 595],
    [1357, 1483, 966, 1895, 1008, 1016, 1831, 1820],
    [1015, 1822],
    [965, 1738, 1319, 1020, 1506, 1460, 1444],
    [1680, 1938, 965, 1738, 1319, 1022, 1669, 137, 71, 623, 633, 595, 1661],
    [1497, 965, 1738, 1319, 1022],
    [1738, 1930, 1014, 1781, 1837, 1822],
    [1680, 1738, 623, 633, 615, 1604, 60],
    [1643, 1661],
    [1431, 623, 1604, 1814, 1014, 633, 1837, 1822],
    [1812, 1822],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
  ];
}
