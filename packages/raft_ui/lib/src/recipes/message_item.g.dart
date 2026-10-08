// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `messageItem`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftMessageItemRecipe].
class RaftMessageItemRecipeStyle {
  const RaftMessageItemRecipeStyle({required this.root, required this.gutter, required this.avatarSlot, required this.continuationTime, required this.content, required this.header, required this.sender, required this.senderBadges, required this.meta, required this.time, required this.inlineStatus, required this.body, required this.searchMatch, required this.embedded, required this.attachments, required this.footer, required this.toolbar, required this.toolbarButton});

  /// Slot `root`.
  final RaftSlotStyle root;
  /// Slot `gutter`.
  final RaftSlotStyle gutter;
  /// Slot `avatarSlot`.
  final RaftSlotStyle avatarSlot;
  /// Slot `continuationTime`.
  final RaftSlotStyle continuationTime;
  /// Slot `content`.
  final RaftSlotStyle content;
  /// Slot `header`.
  final RaftSlotStyle header;
  /// Slot `sender`.
  final RaftSlotStyle sender;
  /// Slot `senderBadges`.
  final RaftSlotStyle senderBadges;
  /// Slot `meta`.
  final RaftSlotStyle meta;
  /// Slot `time`.
  final RaftSlotStyle time;
  /// Slot `inlineStatus`.
  final RaftSlotStyle inlineStatus;
  /// Slot `body`.
  final RaftSlotStyle body;
  /// Slot `searchMatch`.
  final RaftSlotStyle searchMatch;
  /// Slot `embedded`.
  final RaftSlotStyle embedded;
  /// Slot `attachments`.
  final RaftSlotStyle attachments;
  /// Slot `footer`.
  final RaftSlotStyle footer;
  /// Slot `toolbar`.
  final RaftSlotStyle toolbar;
  /// Slot `toolbarButton`.
  final RaftSlotStyle toolbarButton;

  Map<String, RaftSlotStyle> get slots => {'root': root, 'gutter': gutter, 'avatarSlot': avatarSlot, 'continuationTime': continuationTime, 'content': content, 'header': header, 'sender': sender, 'senderBadges': senderBadges, 'meta': meta, 'time': time, 'inlineStatus': inlineStatus, 'body': body, 'searchMatch': searchMatch, 'embedded': embedded, 'attachments': attachments, 'footer': footer, 'toolbar': toolbar, 'toolbarButton': toolbarButton};
}

/// raft-ui recipe `messageItem` (`src/components/message-item/message-item.recipe.ts`, index.mjs:8977).
///
/// Used by: MessageItem, MessageItemAttachments, MessageItemAvatarSlot, MessageItemBody, MessageItemContent, MessageItemContinuationTime, MessageItemEmbedded, MessageItemFooter, MessageItemGutter, MessageItemHeader, MessageItemInlineStatus, MessageItemMeta, MessageItemSearchMatch, MessageItemSender, MessageItemSenderBadges, MessageItemSenderButton, MessageItemTime, MessageItemToolbar, MessageItemToolbarButton.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftMessageItemRecipe {
  static const String recipeName = 'messageItem';
  static const List<String> slotNames = ['root', 'gutter', 'avatarSlot', 'continuationTime', 'content', 'header', 'sender', 'senderBadges', 'meta', 'time', 'inlineStatus', 'body', 'searchMatch', 'embedded', 'attachments', 'footer', 'toolbar', 'toolbarButton'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
    RaftRecipeAxis('compact', ['true', 'false'], null, true),
  ];

  static RaftMessageItemRecipeStyle resolve({required RaftRecipeTheme theme, bool? compact, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name, compact?.toString()], states, tokens);
    return RaftMessageItemRecipeStyle(root: s[0], gutter: s[1], avatarSlot: s[2], continuationTime: s[3], content: s[4], header: s[5], sender: s[6], senderBadges: s[7], meta: s[8], time: s[9], inlineStatus: s[10], body: s[11], searchMatch: s[12], embedded: s[13], attachments: s[14], footer: s[15], toolbar: s[16], toolbarButton: s[17]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [1926, 2775, 1620, 1977, 2569, 1700, 2606, 2491, 2599, 866, 916, 2750, 2762, 2247, 2223, 1529, 1525, 2173, 2172, 2147, 2145, 2155, 2149],
    [2775, 3117, 2867, 2838],
    [2775, 3117, 2867, 2837],
    [580, 2780, 3037, 2834, 2911, 1689, 2918, 2344, 2957, 1901, 1880],
    [2574, 1621, 3017],
    [1620, 2574, 2656, 2723, 2312, 1698],
    [2574, 2867, 3092, 1348, 3017, 1684, 2956, 1350, 1349, 1351],
    [2301, 2867, 2312, 1696],
    [2574, 3092, 1689, 3032, 2959],
    [2867, 3131, 1689, 3032, 2959],
    [2867, 2918, 1684, 2959],
    [3136, 2835, 84, 3017, 2956],
    [841, 3000, 577, 999],
    [2599, 2574],
    [2598, 2901],
    [2599, 1620, 1626, 2312, 1697],
    [2716, 580, 3139, 1620, 2312, 2656, 2626, 1900, 1899, 1861, 1860, 1879, 1878, 150, 2783, 866, 900, 856, 2863],
    [2301, 2867, 2312, 2317, 427, 2883, 2961, 2228, 2272, 1526, 1537, 1408, 1399, 439],
    [1926, 2775, 1620, 1977, 1700, 2606, 2491, 866, 916, 2750, 2247, 2223, 1529, 1525, 2173, 2172, 2147, 2145, 2155, 2149, 2596, 2560, 2762],
    [1926, 2775, 1620, 1977, 2569, 1700, 864, 916, 2410, 2758, 2738, 2685, 2451, 2446, 2437, 1980, 2414, 2221, 1523, 2171, 2148, 2146, 2154, 2150, 2151, 2153, 2152],
    [2775, 3117, 2867, 2838, 2460],
    [2775, 3117, 2867, 2837, 377, 376, 375, 374, 2460, 2393],
    [580, 2780, 2834, 2911, 3036, 2734, 1691, 3032, 2344, 3022, 1902, 1881],
    [2574, 1621, 3017, 2336, 3047],
    [1620, 2574, 2656, 2723, 2311, 1697],
    [2574, 2867, 3092, 1348, 3017, 1688, 2344, 2981, 1350, 1349, 1351],
    [2574, 3092, 1691, 3032, 2344, 2982],
    [2867, 3131, 1691, 3032, 2344, 2911, 2982],
    [2867, 1691, 2920, 1688, 2344, 2981],
    [3136, 2835, 84, 2599, 2492, 2434, 2432, 3017, 2336, 3047, 2981, 1728, 1727],
    [1620, 1626, 2312, 1697, 2601, 2435],
    [2716, 580, 3139, 1620, 2312, 2656, 2626, 1900, 1899, 1861, 1860, 1879, 1878, 3037, 2787, 1695, 2817, 2749, 2761, 867, 896, 825, 2865, 1009],
    [2301, 2867, 2312, 2317, 427, 2884, 2818, 864, 916, 850, 2667, 2978, 2212, 2280, 1522, 1539, 1654, 1667, 1412, 1402, 430],
    [1926, 2775, 1620, 1977, 1700, 864, 916, 2410, 2758, 2451, 1980, 2414, 2221, 1523, 2171, 2148, 2146, 2154, 2150, 2151, 2153, 2152, 2596, 2560, 2734, 2682, 2445, 2437],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17], [18, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17], [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17], [19, 20, 21, 22, 23, 24, 25, 7, 26, 27, 28, 29, 12, 13, 14, 30, 31, 32], [33, 20, 21, 22, 23, 24, 25, 7, 26, 27, 28, 29, 12, 13, 14, 30, 31, 32], [19, 20, 21, 22, 23, 24, 25, 7, 26, 27, 28, 29, 12, 13, 14, 30, 31, 32],
  ];
}
