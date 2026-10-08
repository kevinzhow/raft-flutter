// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `messageQuotedPreview`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftMessageQuotedPreviewRecipe].
class RaftMessageQuotedPreviewRecipeStyle {
  const RaftMessageQuotedPreviewRecipeStyle({required this.root, required this.content, required this.header, required this.channel, required this.thread, required this.author, required this.authorName, required this.authorMeta, required this.timestamp, required this.text, required this.attachments, required this.attachment, required this.loading, required this.unavailable});

  /// Slot `root`.
  final RaftSlotStyle root;
  /// Slot `content`.
  final RaftSlotStyle content;
  /// Slot `header`.
  final RaftSlotStyle header;
  /// Slot `channel`.
  final RaftSlotStyle channel;
  /// Slot `thread`.
  final RaftSlotStyle thread;
  /// Slot `author`.
  final RaftSlotStyle author;
  /// Slot `authorName`.
  final RaftSlotStyle authorName;
  /// Slot `authorMeta`.
  final RaftSlotStyle authorMeta;
  /// Slot `timestamp`.
  final RaftSlotStyle timestamp;
  /// Slot `text`.
  final RaftSlotStyle text;
  /// Slot `attachments`.
  final RaftSlotStyle attachments;
  /// Slot `attachment`.
  final RaftSlotStyle attachment;
  /// Slot `loading`.
  final RaftSlotStyle loading;
  /// Slot `unavailable`.
  final RaftSlotStyle unavailable;

  Map<String, RaftSlotStyle> get slots => {'root': root, 'content': content, 'header': header, 'channel': channel, 'thread': thread, 'author': author, 'authorName': authorName, 'authorMeta': authorMeta, 'timestamp': timestamp, 'text': text, 'attachments': attachments, 'attachment': attachment, 'loading': loading, 'unavailable': unavailable};
}

/// raft-ui recipe `messageQuotedPreview` (`src/components/message-quoted-preview/message-quoted-preview.recipe.ts`, index.mjs:10373).
///
/// Used by: MessageQuotedPreview, MessageQuotedPreviewAttachment, MessageQuotedPreviewAttachments, MessageQuotedPreviewAuthor, MessageQuotedPreviewAuthorMeta, MessageQuotedPreviewAuthorName, MessageQuotedPreviewChannel, MessageQuotedPreviewContent, MessageQuotedPreviewHeader, MessageQuotedPreviewLoading, MessageQuotedPreviewText, MessageQuotedPreviewThread, MessageQuotedPreviewTimestamp, MessageQuotedPreviewUnavailable.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftMessageQuotedPreviewRecipe {
  static const String recipeName = 'messageQuotedPreview';
  static const List<String> slotNames = ['root', 'content', 'header', 'channel', 'thread', 'author', 'authorName', 'authorMeta', 'timestamp', 'text', 'attachments', 'attachment', 'loading', 'unavailable'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftMessageQuotedPreviewRecipeStyle resolve({required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name], states, tokens);
    return RaftMessageQuotedPreviewRecipeStyle(root: s[0], content: s[1], header: s[2], channel: s[3], thread: s[4], author: s[5], authorName: s[6], authorMeta: s[7], timestamp: s[8], text: s[9], attachments: s[10], attachment: s[11], loading: s[12], unavailable: s[13]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [3127, 878, 2242, 2184],
    [2574, 2752, 2766, 2893, 2897],
    [1620, 2574, 2312, 1698, 878, 2752, 2765, 2893, 2896],
    [2301, 2312, 1696, 2920, 2333, 1684, 2964],
    [2301, 2312, 1696, 2920, 2333, 1684, 2968],
    [2301, 2574, 2312, 1697],
    [3092, 1684, 2964],
    [3092, 1689, 2918, 2959],
    [2585, 2867, 1689, 2920, 2333, 2959],
    [2355, 3032, 2346, 2956, 2899],
    [2600, 1620, 1626, 1697],
    [2301, 2312, 1696, 868, 876, 775, 2750, 2761, 1689, 2918, 1684, 2344, 2956],
    [3127, 641, 864, 878, 856],
    [862, 3127, 3003, 864, 878, 856, 2752, 2766, 2924, 2346, 2310, 2959, 2242, 2184, 2269, 2893, 2897],
    [3127],
    [2574, 2753, 2767, 2894, 2898],
    [1620, 2574, 2312, 1698],
    [2301, 2312, 1696, 2920, 2333, 1688, 2984],
    [3092, 1688, 2976],
    [3092, 1689, 2920, 2333, 2981],
    [2585, 2867, 2920, 2333, 2984, 2911],
    [2355, 2924, 2335, 2981],
    [2301, 2312, 1696, 2822, 864, 896, 825, 2751, 2762, 2920, 2333, 1688, 2981, 983],
    [3127, 641],
    [862, 3127, 3003, 2817, 867, 896, 821, 2753, 2767, 2865, 2894, 2898, 1009, 2924, 2335, 2981, 3065, 1602, 2186, 2269, 1638, 1627, 1641],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13], [14, 15, 16, 17, 17, 5, 18, 19, 20, 21, 10, 22, 23, 24],
  ];
}
