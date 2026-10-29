// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `messageReplies`.
// ignore_for_file: type=lint

import '../recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftMessageRepliesRecipe].
class RaftMessageRepliesRecipeStyle {
  const RaftMessageRepliesRecipeStyle({
    required this.root,
    required this.summary,
    required this.summaryItem,
    required this.reply,
    required this.sender,
    required this.content,
    required this.time,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `summary`.
  final RaftSlotStyle summary;

  /// Slot `summaryItem`.
  final RaftSlotStyle summaryItem;

  /// Slot `reply`.
  final RaftSlotStyle reply;

  /// Slot `sender`.
  final RaftSlotStyle sender;

  /// Slot `content`.
  final RaftSlotStyle content;

  /// Slot `time`.
  final RaftSlotStyle time;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'summary': summary,
    'summaryItem': summaryItem,
    'reply': reply,
    'sender': sender,
    'content': content,
    'time': time,
  };
}

/// raft-ui recipe `messageReplies` (`src/components/message-replies/message-replies.recipe.ts`, index.mjs:10610).
///
/// Used by: MessageReplies, MessageRepliesItem, MessageRepliesItemContent, MessageRepliesItemSender, MessageRepliesItemTime, MessageRepliesSummary, MessageRepliesSummaryItem.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftMessageRepliesRecipe {
  static const String recipeName = 'messageReplies';
  static const List<String> slotNames = [
    'root',
    'summary',
    'summaryItem',
    'reply',
    'sender',
    'content',
    'time',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftMessageRepliesRecipeStyle resolve({
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
    return RaftMessageRepliesRecipeStyle(
      root: s[0],
      summary: s[1],
      summaryItem: s[2],
      reply: s[3],
      sender: s[4],
      content: s[5],
      time: s[6],
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
    [
      1928,
      2622,
      1644,
      2597,
      3168,
      1646,
      1721,
      2780,
      2794,
      3040,
      3125,
      1662,
      1668,
      877,
      772,
      2214,
    ],
    [1644, 2902, 1650, 2331, 1721, 3125, 2959, 1709, 2999, 1903, 410],
    [2320, 2331, 1720, 643, 426],
    [1644, 2597, 2331, 1722, 2959],
    [2597, 2900, 3133, 1717, 3001],
    [2597, 1645, 3133, 3000],
    [2608, 2902, 1714, 2957, 2946, 2996],
    [
      1928,
      2622,
      1644,
      2597,
      3168,
      1646,
      1721,
      2780,
      2794,
      3040,
      1662,
      1668,
      826,
      2899,
      3106,
      1626,
      2205,
      2288,
      2848,
    ],
    [1644, 2902, 1650, 2331, 1721, 3073, 1713, 3125, 411, 2513, 3018],
    [1644, 2597, 2331, 1722, 3073, 2366],
    [2597, 2900, 3133, 1717, 3018],
    [2597, 1645, 3133, 3020],
    [2608, 2902, 1716, 2957, 2946, 3021],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6],
    [7, 8, 2, 9, 10, 11, 12],
  ];
}
