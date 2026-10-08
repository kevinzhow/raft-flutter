// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
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
  const RaftMessageForwardedBundleItemRecipeStyle({required this.root, required this.meta, required this.author, required this.itemContent, required this.attachments, required this.attachment, required this.attachmentName, required this.attachmentMeta});

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

  Map<String, RaftSlotStyle> get slots => {'root': root, 'meta': meta, 'author': author, 'itemContent': itemContent, 'attachments': attachments, 'attachment': attachment, 'attachmentName': attachmentName, 'attachmentMeta': attachmentMeta};
}

/// raft-ui recipe `messageForwardedBundleItem` (`src/components/message-forwarded-bundle/message-forwarded-bundle.recipe.ts`, index.mjs:11511).
///
/// Used by: MessageForwardedBundleAttachment, MessageForwardedBundleAttachmentMeta, MessageForwardedBundleAttachmentName, MessageForwardedBundleAttachments, MessageForwardedBundleItem, MessageForwardedBundleItemAuthor, MessageForwardedBundleItemContent, MessageForwardedBundleItemMeta.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftMessageForwardedBundleItemRecipe {
  static const String recipeName = 'messageForwardedBundleItem';
  static const List<String> slotNames = ['root', 'meta', 'author', 'itemContent', 'attachments', 'attachment', 'attachmentName', 'attachmentMeta'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
    RaftRecipeAxis('action', ['static', 'interactive'], 'static', false),
  ];

  static RaftMessageForwardedBundleItemRecipeStyle resolve({required RaftRecipeTheme theme, RaftMessageForwardedBundleItemRecipeAction? action, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name, action?.css], states, tokens);
    return RaftMessageForwardedBundleItemRecipeStyle(root: s[0], meta: s[1], author: s[2], itemContent: s[3], attachments: s[4], attachment: s[5], attachmentName: s[6], attachmentMeta: s[7]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [856, 2753, 2765, 3017, 2956],
    [1620, 2574, 1626, 2312, 2491, 1697, 2920, 1689, 2962],
    [1684, 2965],
    [2574, 2484, 3136],
    [1620, 1626, 2599, 1697],
    [2301, 2484, 2312, 1696, 864, 879, 856, 2750, 2762, 2920, 1684, 2966],
    [2574, 3092],
    [2867, 2961],
    [2301, 2484, 2312, 1696, 864, 879, 856, 2750, 2762, 2920, 1684, 2966, 942, 3084, 2247, 1639, 1647, 1644],
    [2753, 2768, 3017, 2335, 2987],
    [1620, 2574, 1626, 2312, 2491, 1697, 2920, 1691, 2911, 2984],
    [1692, 2987],
    [2301, 2484, 2312, 1696, 2822, 864, 896, 825, 2751, 2762, 2920, 2333, 1688, 2981, 983],
    [2867, 2984],
    [2301, 2484, 2312, 1696, 2822, 864, 896, 825, 2751, 2762, 2920, 2333, 1688, 2981, 983, 942, 3084, 2247, 1639, 1647, 1644],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7], [0, 1, 2, 3, 4, 8, 6, 7], [9, 10, 11, 3, 4, 12, 6, 13], [9, 10, 11, 3, 4, 14, 6, 13],
  ];
}
