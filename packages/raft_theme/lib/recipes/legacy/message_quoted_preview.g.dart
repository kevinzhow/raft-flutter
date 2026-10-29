// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `messageQuotedPreview`.
// ignore_for_file: type=lint

import '../recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftMessageQuotedPreviewRecipe].
class RaftMessageQuotedPreviewRecipeStyle {
  const RaftMessageQuotedPreviewRecipeStyle({
    required this.root,
    required this.content,
    required this.header,
    required this.channel,
    required this.thread,
    required this.author,
    required this.authorName,
    required this.authorMeta,
    required this.timestamp,
    required this.text,
    required this.attachments,
    required this.attachment,
    required this.loading,
    required this.unavailable,
  });

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

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'content': content,
    'header': header,
    'channel': channel,
    'thread': thread,
    'author': author,
    'authorName': authorName,
    'authorMeta': authorMeta,
    'timestamp': timestamp,
    'text': text,
    'attachments': attachments,
    'attachment': attachment,
    'loading': loading,
    'unavailable': unavailable,
  };
}

/// raft-ui recipe `messageQuotedPreview` (`src/components/message-quoted-preview/message-quoted-preview.recipe.ts`, index.mjs:10416).
///
/// Used by: MessageQuotedPreview, MessageQuotedPreviewAttachment, MessageQuotedPreviewAttachments, MessageQuotedPreviewAuthor, MessageQuotedPreviewAuthorMeta, MessageQuotedPreviewAuthorName, MessageQuotedPreviewChannel, MessageQuotedPreviewContent, MessageQuotedPreviewHeader, MessageQuotedPreviewLoading, MessageQuotedPreviewText, MessageQuotedPreviewThread, MessageQuotedPreviewTimestamp, MessageQuotedPreviewUnavailable.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftMessageQuotedPreviewRecipe {
  static const String recipeName = 'messageQuotedPreview';
  static const List<String> slotNames = [
    'root',
    'content',
    'header',
    'channel',
    'thread',
    'author',
    'authorName',
    'authorMeta',
    'timestamp',
    'text',
    'attachments',
    'attachment',
    'loading',
    'unavailable',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftMessageQuotedPreviewRecipeStyle resolve({
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
    return RaftMessageQuotedPreviewRecipeStyle(
      root: s[0],
      content: s[1],
      header: s[2],
      channel: s[3],
      thread: s[4],
      author: s[5],
      authorName: s[6],
      authorMeta: s[7],
      timestamp: s[8],
      text: s[9],
      attachments: s[10],
      attachment: s[11],
      loading: s[12],
      unavailable: s[13],
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
    [3168, 894, 2261, 2203],
    [2597, 2780, 2795, 2928, 2932],
    [1644, 2597, 2331, 1723, 894, 2780, 2794, 2928, 2931],
    [2320, 2331, 1721, 2958, 2352, 1709, 3001],
    [2320, 2331, 1721, 2958, 2352, 1709, 3005],
    [2320, 2597, 2331, 1722],
    [3133, 1709, 3001],
    [3133, 1714, 2956, 2996],
    [2608, 2902, 1714, 2958, 2352, 2996],
    [2374, 3073, 2365, 2994, 2934],
    [2623, 1644, 1650, 1722],
    [2320, 2331, 1721, 880, 892, 781, 2778, 2790, 1714, 2956, 1709, 2363, 2994],
    [3168, 647, 876, 894, 868],
    [
      874,
      3168,
      3040,
      876,
      894,
      868,
      2780,
      2795,
      2962,
      2365,
      2329,
      2996,
      2261,
      2203,
      2288,
      2928,
      2932,
    ],
    [3168],
    [2597, 2781, 2796, 2929, 2933],
    [1644, 2597, 2331, 1723],
    [2320, 2331, 1721, 2958, 2352, 1713, 3021],
    [3133, 1713, 3013],
    [3133, 1714, 2958, 2352, 3018],
    [2608, 2902, 2958, 2352, 3021, 2946],
    [2374, 2962, 2354, 3018],
    [
      2320,
      2331,
      1721,
      2852,
      876,
      912,
      830,
      2779,
      2791,
      2958,
      2352,
      1713,
      3018,
      1003,
    ],
    [3168, 647],
    [
      874,
      3168,
      3040,
      2847,
      879,
      912,
      826,
      2781,
      2796,
      2899,
      2929,
      2933,
      1029,
      2962,
      2354,
      3018,
      3106,
      1626,
      2205,
      2288,
      1662,
      1651,
      1665,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13],
    [14, 15, 16, 17, 17, 5, 18, 19, 20, 21, 10, 22, 23, 24],
  ];
}
