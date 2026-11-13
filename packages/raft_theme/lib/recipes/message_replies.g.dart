// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `messageReplies`.
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

/// raft-ui recipe `messageReplies` (`dist/components/message-replies/message-replies.recipe.mjs`, index.mjs:13358).
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
      1614,
      1400,
      2116,
      2725,
      1404,
      2613,
      2675,
      1423,
      1427,
      2147,
      1464,
      940,
      2402,
      2417,
      895,
      2603,
      1796,
      699,
      1432,
      1439,
    ],
    [
      1400,
      2499,
      1408,
      1864,
      2675,
      1465,
      2597,
      1449,
      2603,
      1727,
      446,
      445,
      451,
      449,
      450,
      455,
      452,
      444,
      456,
      443,
      442,
      457,
      447,
      448,
      453,
      454,
    ],
    [1847, 1864, 1463, 761, 477],
    [1400, 2116, 1864, 1465, 2597],
    [2116, 2498, 2681, 1457, 2603],
    [2116, 1401, 2681, 2600],
    [2132, 2499, 1454, 2616, 2556, 2600],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6],
  ];
}
