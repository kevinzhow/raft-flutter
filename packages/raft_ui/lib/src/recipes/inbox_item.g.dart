// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `inboxItem`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftInboxItemRecipe].
class RaftInboxItemRecipeStyle {
  const RaftInboxItemRecipeStyle({required this.item, required this.itemTrigger, required this.itemSelection, required this.itemContent, required this.itemContext, required this.itemSubtitle, required this.itemHeading, required this.itemTitle, required this.itemTrailing, required this.itemTimestamp, required this.itemBody, required this.itemMessage, required this.itemSender, required this.itemMetadata, required this.itemActions});

  /// Slot `item`.
  final RaftSlotStyle item;
  /// Slot `itemTrigger`.
  final RaftSlotStyle itemTrigger;
  /// Slot `itemSelection`.
  final RaftSlotStyle itemSelection;
  /// Slot `itemContent`.
  final RaftSlotStyle itemContent;
  /// Slot `itemContext`.
  final RaftSlotStyle itemContext;
  /// Slot `itemSubtitle`.
  final RaftSlotStyle itemSubtitle;
  /// Slot `itemHeading`.
  final RaftSlotStyle itemHeading;
  /// Slot `itemTitle`.
  final RaftSlotStyle itemTitle;
  /// Slot `itemTrailing`.
  final RaftSlotStyle itemTrailing;
  /// Slot `itemTimestamp`.
  final RaftSlotStyle itemTimestamp;
  /// Slot `itemBody`.
  final RaftSlotStyle itemBody;
  /// Slot `itemMessage`.
  final RaftSlotStyle itemMessage;
  /// Slot `itemSender`.
  final RaftSlotStyle itemSender;
  /// Slot `itemMetadata`.
  final RaftSlotStyle itemMetadata;
  /// Slot `itemActions`.
  final RaftSlotStyle itemActions;

  Map<String, RaftSlotStyle> get slots => {'item': item, 'itemTrigger': itemTrigger, 'itemSelection': itemSelection, 'itemContent': itemContent, 'itemContext': itemContext, 'itemSubtitle': itemSubtitle, 'itemHeading': itemHeading, 'itemTitle': itemTitle, 'itemTrailing': itemTrailing, 'itemTimestamp': itemTimestamp, 'itemBody': itemBody, 'itemMessage': itemMessage, 'itemSender': itemSender, 'itemMetadata': itemMetadata, 'itemActions': itemActions};
}

/// raft-ui recipe `inboxItem` (`src/components/inbox-item/inbox-item.recipe.ts`, index.mjs:19880).
///
/// Used by: InboxItem, InboxItemActions, InboxItemBody, InboxItemContent, InboxItemContext, InboxItemHeading, InboxItemMessage, InboxItemMetadata, InboxItemSelection, InboxItemSender, InboxItemSubtitle, InboxItemTimestamp, InboxItemTitle, InboxItemTrailing, InboxItemTrigger.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftInboxItemRecipe {
  static const String recipeName = 'inboxItem';
  static const List<String> slotNames = ['item', 'itemTrigger', 'itemSelection', 'itemContent', 'itemContext', 'itemSubtitle', 'itemHeading', 'itemTitle', 'itemTrailing', 'itemTimestamp', 'itemBody', 'itemMessage', 'itemSender', 'itemMetadata', 'itemActions'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftInboxItemRecipeStyle resolve({required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name], states, tokens);
    return RaftInboxItemRecipeStyle(item: s[0], itemTrigger: s[1], itemSelection: s[2], itemContent: s[3], itemContext: s[4], itemSubtitle: s[5], itemHeading: s[6], itemTitle: s[7], itemTrailing: s[8], itemTimestamp: s[9], itemBody: s[10], itemMessage: s[11], itemSender: s[12], itemMetadata: s[13], itemActions: s[14]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [2775, 1717, 3127, 1722, 2314, 1700, 2672, 3003, 2142, 3084, 866, 880, 856, 2241, 2269, 592, 604, 1447, 1444, 1445, 1175, 1183, 1177, 1178, 2077, 2080],
    [580, 2303, 3137, 2649],
    [2775, 3138, 2597, 1620, 2880, 2867, 2312, 2317],
    [2716, 2775, 3138, 2574, 1621, 3003],
    [1620, 2574, 2312, 1698, 2491, 2760, 3032, 2333, 1684, 2960],
    [2490, 2574, 2761, 2920, 2331, 1684, 2960],
    [2490, 1620, 2574, 2314, 1698],
    [2775, 2355, 2574, 1621, 2703, 3017, 2335, 292, 320, 297, 304, 1692, 2962, 1824, 1825, 314],
    [2716, 2775, 3138, 1620, 2867, 2312, 1700, 2405, 2430, 2407, 134],
    [2867, 3131, 3012, 3032, 2335, 2911, 1689, 2959],
    [2355, 3032, 2333, 2962, 1825],
    [2574, 2356, 3017, 2335, 2956],
    [1684, 2964],
    [2598, 1620, 2564, 1626, 2312, 1697],
    [2715, 1620, 2867, 2312, 1697, 238, 239, 234, 235],
    [2775, 1717, 3127, 1722, 2314, 1700, 3003, 2142, 2672, 2817, 867, 896, 825, 2865, 3062, 1602, 2185, 1009, 1447, 1176, 1179, 1182, 1180, 1181, 1010, 2078, 2079, 1086, 1087],
    [1620, 2574, 2312, 1698, 2761, 2491, 3032, 2333, 3047, 1688, 2984],
    [2574, 2761, 2491, 3032, 2333, 3047, 1688, 2984],
    [1620, 2574, 2314, 1698, 2491],
    [2775, 2355, 2574, 1621, 2703, 292, 320, 297, 304, 3017, 2335, 1688, 3047, 2976, 1827, 317],
    [2716, 2775, 3138, 135, 1620, 2867, 2312, 1700, 2405, 2430, 2407],
    [2867, 3131, 3012, 2920, 2335, 1688, 2911, 2984],
    [2355, 2924, 2334, 3047, 2981, 1826],
    [2574, 2355, 2924, 2334, 3047, 2981],
    [1688, 2976],
    [1620, 2564, 1626, 2312, 1697, 2600],
    [2715, 1620, 2867, 2312, 1695, 237, 240, 233, 236, 950, 949],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14], [15, 1, 2, 3, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26],
  ];
}
