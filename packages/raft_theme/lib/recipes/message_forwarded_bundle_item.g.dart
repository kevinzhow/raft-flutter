// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `messageForwardedBundleItem`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `action` axis of `messageForwardedBundleItem` (default `static`).
enum RaftMessageForwardedBundleItemRecipeAction {
  static_('static'),
  interactive('interactive');

  const RaftMessageForwardedBundleItemRecipeAction(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftMessageForwardedBundleItemRecipe].
class RaftMessageForwardedBundleItemRecipeStyle {
  const RaftMessageForwardedBundleItemRecipeStyle({
    required this.root,
    required this.meta,
    required this.author,
    required this.itemContent,
    required this.attachments,
    required this.attachment,
    required this.attachmentName,
    required this.attachmentMeta,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `meta`.
  final RaftSlotStyle meta;

  /// Slot `author`.
  final RaftSlotStyle author;

  /// Slot `itemContent`.
  final RaftSlotStyle itemContent;

  /// Slot `attachments`.
  final RaftSlotStyle attachments;

  /// Slot `attachment`.
  final RaftSlotStyle attachment;

  /// Slot `attachmentName`.
  final RaftSlotStyle attachmentName;

  /// Slot `attachmentMeta`.
  final RaftSlotStyle attachmentMeta;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'meta': meta,
    'author': author,
    'itemContent': itemContent,
    'attachments': attachments,
    'attachment': attachment,
    'attachmentName': attachmentName,
    'attachmentMeta': attachmentMeta,
  };
}

/// raft-ui recipe `messageForwardedBundleItem` (`dist/components/message-forwarded-bundle/message-forwarded-bundle.recipe.mjs`, index.mjs:14173).
///
/// Used by: MessageForwardedBundleAttachment, MessageForwardedBundleAttachmentMeta, MessageForwardedBundleAttachmentName, MessageForwardedBundleAttachments, MessageForwardedBundleItem, MessageForwardedBundleItemAuthor, MessageForwardedBundleItemContent, MessageForwardedBundleItemMeta.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftMessageForwardedBundleItemRecipe {
  static const String recipeName = 'messageForwardedBundleItem';
  static const List<String> slotNames = [
    'root',
    'meta',
    'author',
    'itemContent',
    'attachments',
    'attachment',
    'attachmentName',
    'attachmentMeta',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('action', ['static', 'interactive'], 'static', false),
  ];

  static RaftMessageForwardedBundleItemRecipeStyle resolve({
    RaftMessageForwardedBundleItemRecipeAction? action,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [action?.css],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftMessageForwardedBundleItemRecipeStyle(
      root: s[0],
      meta: s[1],
      author: s[2],
      itemContent: s[3],
      attachments: s[4],
      attachment: s[5],
      attachmentName: s[6],
      attachmentMeta: s[7],
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
    [2403, 2418, 2585, 2598],
    [1400, 2116, 1408, 1864, 1987, 1465, 1454, 2616, 2556, 2600],
    [1456, 2597, 1449, 2598],
    [2116, 1980, 2734],
    [1400, 1408, 2146, 1465],
    [
      1847,
      1980,
      1864,
      1666,
      1464,
      2461,
      895,
      2362,
      2305,
      2588,
      1457,
      2598,
      477,
    ],
    [2116, 2681],
    [2499, 1454, 1455, 2600],
    [
      1847,
      1980,
      1864,
      1666,
      1464,
      2461,
      895,
      2362,
      2305,
      2588,
      1457,
      2598,
      477,
      997,
      1424,
      1429,
      1427,
      1794,
      699,
      1432,
      1439,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7],
    [0, 1, 2, 3, 4, 8, 6, 7],
  ];
}
