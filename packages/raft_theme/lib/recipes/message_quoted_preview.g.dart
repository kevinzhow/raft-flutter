// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `messageQuotedPreview`.
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

/// raft-ui recipe `messageQuotedPreview` (`src/components/message-quoted-preview/message-quoted-preview.recipe.ts`, index.mjs:8067).
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
    [1926, 1712, 621, 631, 634, 615, 1617, 1825],
    [1483, 1590],
    [965, 1483, 1319, 1022, 1590, 1601],
    [1305, 1319, 1021, 1819, 1017, 1822, 279],
    [1305, 1483, 1319, 1022],
    [1895, 1819, 1008, 1825],
    [1895, 1812, 1822],
    [1497, 1738, 1014, 1837, 1781, 1822],
    [1353, 1811, 1825],
    [965, 971, 1022, 1510],
    [1305, 1319, 1191, 1021, 1706, 581, 1655, 1014, 1837, 1825, 279],
    [1926, 473, 1712, 621, 631, 634, 615, 1617],
    [618, 1926, 1834, 631, 634, 1617, 1811, 1822, 1575, 996],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
  ];
}
