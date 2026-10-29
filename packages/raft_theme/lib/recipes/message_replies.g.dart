// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `messageReplies`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
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

/// raft-ui recipe `messageReplies` (`src/components/message-replies/message-replies.recipe.ts`, index.mjs:8222).
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
  static const List<RaftRecipeAxis> axes = [];

  static RaftMessageRepliesRecipeStyle resolve({
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
      1152,
      965,
      1484,
      1929,
      967,
      1836,
      1893,
      981,
      985,
      1513,
      1417,
      1021,
      1709,
      621,
      1659,
      1671,
      581,
      1827,
      1283,
      429,
      986,
      996,
    ],
    [
      965,
      1740,
      971,
      1319,
      1893,
      1022,
      1821,
      1008,
      1827,
      1240,
      251,
      250,
      256,
      254,
      255,
      260,
      257,
      249,
      261,
      248,
      247,
      262,
      252,
      253,
      258,
      259,
    ],
    [1305, 1319, 1020, 469, 279],
    [965, 1484, 1319, 1022, 1821],
    [1484, 1739, 1897, 1017, 1827],
    [1484, 966, 1897, 1824],
    [1499, 1740, 1014, 1839, 1783, 1824],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6],
  ];
}
