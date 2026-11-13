// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `messageQuotedPreview`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
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
    required this.authorDelegatedBy,
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

  /// Slot `authorDelegatedBy`.
  final RaftSlotStyle authorDelegatedBy;

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
    'authorDelegatedBy': authorDelegatedBy,
    'timestamp': timestamp,
    'text': text,
    'attachments': attachments,
    'attachment': attachment,
    'loading': loading,
    'unavailable': unavailable,
  };
}

/// raft-ui recipe `messageQuotedPreview` (`dist/components/message-quoted-preview/message-quoted-preview.recipe.mjs`, index.mjs:13184).
///
/// Used by: MessageQuotedPreview, MessageQuotedPreviewAttachment, MessageQuotedPreviewAttachments, MessageQuotedPreviewAuthor, MessageQuotedPreviewAuthorDelegatedBy, MessageQuotedPreviewAuthorMeta, MessageQuotedPreviewAuthorName, MessageQuotedPreviewChannel, MessageQuotedPreviewContent, MessageQuotedPreviewHeader, MessageQuotedPreviewLoading, MessageQuotedPreviewText, MessageQuotedPreviewThread, MessageQuotedPreviewTimestamp, MessageQuotedPreviewUnavailable.
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
    'authorDelegatedBy',
    'timestamp',
    'text',
    'attachments',
    'attachment',
    'loading',
    'unavailable',
  ];
  static const List<RaftRecipeAxis> axes = [];

  static RaftMessageQuotedPreviewRecipeStyle resolve({
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
    return RaftMessageQuotedPreviewRecipeStyle(
      root: s[0],
      content: s[1],
      header: s[2],
      channel: s[3],
      thread: s[4],
      author: s[5],
      authorName: s[6],
      authorMeta: s[7],
      authorDelegatedBy: s[8],
      timestamp: s[9],
      text: s[10],
      attachments: s[11],
      attachment: s[12],
      loading: s[13],
      unavailable: s[14],
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
    [2725, 2468, 940, 951, 954, 933, 2299, 2603],
    [2116, 2260],
    [1400, 2116, 1864, 1759, 1465, 2260, 2273],
    [1847, 1866, 1464, 2597, 1457, 2600, 477, 471],
    [1847, 2116, 1864, 1465],
    [2681, 2597, 1449, 2603],
    [2681, 2588, 2600],
    [2499, 2729, 2597, 2603],
    [2132, 2499, 1454, 2616, 2556, 2600],
    [1901, 2587, 2603],
    [1400, 1408, 1465, 2146],
    [1847, 1864, 1666, 1464, 2461, 895, 2400, 1454, 2616, 2603, 477],
    [2725, 764, 2468, 940, 951, 954, 933, 2299],
    [937, 2725, 2613, 951, 954, 2299, 2587, 2600, 2247, 1439],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13],
  ];
}
