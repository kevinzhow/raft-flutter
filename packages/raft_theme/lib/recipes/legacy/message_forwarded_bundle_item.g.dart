// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `messageForwardedBundleItem`.
// ignore_for_file: type=lint

import '../recipe_runtime.dart';
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

/// raft-ui recipe `messageForwardedBundleItem` (`src/components/message-forwarded-bundle/message-forwarded-bundle.recipe.ts`, index.mjs:11554).
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
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
    RaftRecipeAxis('action', ['static', 'interactive'], 'static', false),
  ];

  static RaftMessageForwardedBundleItemRecipeStyle resolve({
    required RaftRecipeTheme theme,
    RaftMessageForwardedBundleItemRecipeAction? action,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [theme.name, action?.css],
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
    [868, 2781, 2794, 3053, 2994],
    [1644, 2597, 1650, 2331, 2512, 1722, 2958, 1714, 2999],
    [1709, 3002],
    [2597, 2505, 3177],
    [1644, 1650, 2622, 1722],
    [2320, 2505, 2331, 1721, 876, 895, 868, 2778, 2791, 2958, 1709, 3003],
    [2597, 3133],
    [2902, 2998],
    [
      2320,
      2505,
      2331,
      1721,
      876,
      895,
      868,
      2778,
      2791,
      2958,
      1709,
      3003,
      962,
      3125,
      2266,
      1663,
      1671,
      1668,
    ],
    [2781, 2797, 3053, 2354, 3024],
    [1644, 2597, 1650, 2331, 2512, 1722, 2958, 1716, 2946, 3021],
    [1717, 3024],
    [
      2320,
      2505,
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
    [2902, 3021],
    [
      2320,
      2505,
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
      962,
      3125,
      2266,
      1663,
      1671,
      1668,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7],
    [0, 1, 2, 3, 4, 8, 6, 7],
    [9, 10, 11, 3, 4, 12, 6, 13],
    [9, 10, 11, 3, 4, 14, 6, 13],
  ];
}
