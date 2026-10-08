// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `messageReplies`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftMessageRepliesRecipe].
class RaftMessageRepliesRecipeStyle {
  const RaftMessageRepliesRecipeStyle({required this.root, required this.summary, required this.summaryItem, required this.reply, required this.sender, required this.content, required this.time});

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

  Map<String, RaftSlotStyle> get slots => {'root': root, 'summary': summary, 'summaryItem': summaryItem, 'reply': reply, 'sender': sender, 'content': content, 'time': time};
}

/// raft-ui recipe `messageReplies` (`src/components/message-replies/message-replies.recipe.ts`, index.mjs:10567).
///
/// Used by: MessageReplies, MessageRepliesItem, MessageRepliesItemContent, MessageRepliesItemSender, MessageRepliesItemTime, MessageRepliesSummary, MessageRepliesSummaryItem.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftMessageRepliesRecipe {
  static const String recipeName = 'messageReplies';
  static const List<String> slotNames = ['root', 'summary', 'summaryItem', 'reply', 'sender', 'content', 'time'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftMessageRepliesRecipeStyle resolve({required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name], states, tokens);
    return RaftMessageRepliesRecipeStyle(root: s[0], summary: s[1], summaryItem: s[2], reply: s[3], sender: s[4], content: s[5], time: s[6]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [1927, 2599, 1620, 2574, 3127, 1622, 1696, 2752, 2765, 3003, 3084, 1638, 1644, 865, 766, 2195],
    [1620, 2867, 1626, 2312, 1696, 3084, 2921, 1684, 2962, 1898, 412],
    [2301, 2312, 1695, 637, 428],
    [1620, 2574, 2312, 1697, 2921],
    [2574, 2866, 3092, 1692, 2964],
    [2574, 1621, 3092, 2963],
    [2585, 2867, 1691, 2919, 2911, 2959],
    [1927, 2599, 1620, 2574, 3127, 1622, 1696, 2752, 2765, 3003, 1638, 1644, 821, 2865, 3065, 1602, 2186, 2269, 2818],
    [1620, 2867, 1626, 2312, 1696, 3032, 1688, 3084, 413, 2492, 2981],
    [1620, 2574, 2312, 1697, 3032, 2347],
    [2574, 2866, 3092, 1692, 2981],
    [2574, 1621, 3092, 2983],
    [2585, 2867, 1689, 2918, 2984],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6], [7, 8, 2, 9, 10, 11, 12],
  ];
}
