// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `threadPanel`.
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

/// raft-ui recipe `threadPanel` (`dist/components/thread-panel/thread-panel.recipe.mjs`, index.mjs:20270).
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
    [1862, 1400, 2538, 2098, 1404, 2433, 910, 1456, 2598],
    [1400, 1639, 2499, 1864, 1468, 1937, 2394, 265, 267, 942, 954, 910],
    [1400, 2098, 2116, 1401, 1404, 2433, 910],
    [1907, 2116, 1401, 2681, 1449, 1456, 2609, 2598],
    [1455, 2600],
    [1400, 2499, 1864, 1463, 2038, 543],
    [2433, 2738, 1400, 2499, 1864, 1465, 2417, 296, 114, 942, 953, 910, 2396],
    [2132, 1400, 2499, 1864, 1465],
    [2499, 2729, 1454, 2556, 2616, 2600],
    [2433, 2499, 942, 953, 933, 2290, 79],
    [2393, 2396],
    [2162, 942, 2275, 2590, 1454, 953, 2616, 2600],
    [2378, 2588, 2600],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
  ];
}
