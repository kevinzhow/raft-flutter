// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `messageForwardedBundleItem`.
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

/// raft-ui recipe `messageForwardedBundleItem` (`src/components/message-forwarded-bundle/message-forwarded-bundle.recipe.ts`, index.mjs:9216).
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
    [1656, 1668, 1806, 1818],
    [965, 1481, 971, 1318, 1428, 1021, 1013, 1835, 1779, 1820],
    [1015, 1817, 1007, 1818],
    [1481, 1422, 1933],
    [965, 971, 1508, 1021],
    [1304, 1422, 1318, 1190, 1020, 1704, 581, 1653, 1810, 1016, 1818, 279],
    [1481, 1893],
    [1736, 1013, 1014, 1820],
    [
      1304,
      1422,
      1318,
      1190,
      1020,
      1704,
      581,
      1653,
      1810,
      1016,
      1818,
      279,
      664,
      1889,
      1275,
      982,
      988,
      985,
      1282,
      429,
      986,
      995,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7],
    [0, 1, 2, 3, 4, 8, 6, 7],
  ];
}
