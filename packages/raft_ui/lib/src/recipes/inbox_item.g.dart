// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `inboxItem`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftInboxItemRecipe].
class RaftInboxItemRecipeStyle {
  const RaftInboxItemRecipeStyle({
    required this.item,
    required this.itemTrigger,
    required this.itemSelection,
    required this.itemContent,
    required this.itemContext,
    required this.itemSubtitle,
    required this.itemHeading,
    required this.itemTitle,
    required this.itemTrailing,
    required this.itemTimestamp,
    required this.itemBody,
    required this.itemMessage,
    required this.itemSender,
    required this.itemMetadata,
    required this.itemActions,
  });

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

  Map<String, RaftSlotStyle> get slots => {
    'item': item,
    'itemTrigger': itemTrigger,
    'itemSelection': itemSelection,
    'itemContent': itemContent,
    'itemContext': itemContext,
    'itemSubtitle': itemSubtitle,
    'itemHeading': itemHeading,
    'itemTitle': itemTitle,
    'itemTrailing': itemTrailing,
    'itemTimestamp': itemTimestamp,
    'itemBody': itemBody,
    'itemMessage': itemMessage,
    'itemSender': itemSender,
    'itemMetadata': itemMetadata,
    'itemActions': itemActions,
  };
}

/// raft-ui recipe `inboxItem` (`src/components/inbox-item/inbox-item.recipe.ts`, index.mjs:20029).
///
/// Used by: InboxItem, InboxItemActions, InboxItemBody, InboxItemContent, InboxItemContext, InboxItemHeading, InboxItemMessage, InboxItemMetadata, InboxItemSelection, InboxItemSender, InboxItemSubtitle, InboxItemTimestamp, InboxItemTitle, InboxItemTrailing, InboxItemTrigger.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftInboxItemRecipe {
  static const String recipeName = 'inboxItem';
  static const List<String> slotNames = [
    'item',
    'itemTrigger',
    'itemSelection',
    'itemContent',
    'itemContext',
    'itemSubtitle',
    'itemHeading',
    'itemTitle',
    'itemTrailing',
    'itemTimestamp',
    'itemBody',
    'itemMessage',
    'itemSender',
    'itemMetadata',
    'itemActions',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftInboxItemRecipeStyle resolve({
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
    return RaftInboxItemRecipeStyle(
      item: s[0],
      itemTrigger: s[1],
      itemSelection: s[2],
      itemContent: s[3],
      itemContext: s[4],
      itemSubtitle: s[5],
      itemHeading: s[6],
      itemTitle: s[7],
      itemTrailing: s[8],
      itemTimestamp: s[9],
      itemBody: s[10],
      itemMessage: s[11],
      itemSender: s[12],
      itemMetadata: s[13],
      itemActions: s[14],
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
    [
      2804,
      1742,
      3168,
      1747,
      2333,
      1725,
      2695,
      3040,
      2153,
      3125,
      878,
      896,
      868,
      2260,
      2288,
      598,
      610,
      1469,
      1466,
      1467,
      1194,
      1202,
      1196,
      1197,
      2083,
      2086,
    ],
    [586, 2322, 3178, 2672],
    [2804, 3179, 2620, 1644, 2915, 2902, 2331, 2336],
    [2739, 2804, 3179, 2597, 1645, 3040],
    [1644, 2597, 2331, 1723, 2512, 2789, 3073, 2352, 1709, 2997],
    [2511, 2597, 2790, 2958, 2350, 1709, 2997],
    [2511, 1644, 2597, 2333, 1723],
    [
      2804,
      2374,
      2597,
      1645,
      2726,
      3053,
      2354,
      288,
      316,
      293,
      300,
      1717,
      2999,
      1849,
      1850,
      310,
    ],
    [2739, 2804, 3179, 1644, 2902, 2331, 1725, 2426, 2450, 2428, 134],
    [2902, 3172, 3048, 3073, 2354, 2946, 1714, 2996],
    [2374, 3073, 2352, 2999, 1850],
    [2597, 2375, 3053, 2354, 2994],
    [1709, 3001],
    [2621, 1644, 2587, 1650, 2331, 1722],
    [2738, 1644, 2902, 2331, 1722, 236, 237, 232, 233],
    [
      2804,
      1742,
      3168,
      1747,
      2333,
      1725,
      3040,
      2153,
      2695,
      2847,
      879,
      912,
      830,
      2899,
      3103,
      1626,
      2204,
      1029,
      1469,
      1195,
      1198,
      1201,
      1199,
      1200,
      1030,
      2084,
      2085,
      1106,
      1107,
    ],
    [1644, 2597, 2331, 1723, 2790, 2512, 3073, 2352, 3088, 1713, 3021],
    [2597, 2790, 2512, 3073, 2352, 3088, 1713, 3021],
    [1644, 2597, 2333, 1723, 2512],
    [
      2804,
      2374,
      2597,
      1645,
      2726,
      288,
      316,
      293,
      300,
      3053,
      2354,
      1713,
      3088,
      3013,
      1852,
      313,
    ],
    [2739, 2804, 3179, 135, 1644, 2902, 2331, 1725, 2426, 2450, 2428],
    [2902, 3172, 3048, 2958, 2354, 1713, 2946, 3021],
    [2374, 2962, 2353, 3088, 3018, 1851],
    [2597, 2374, 2962, 2353, 3088, 3018],
    [1713, 3013],
    [1644, 2587, 1650, 2331, 1722, 2623],
    [2738, 1644, 2902, 2331, 1720, 235, 238, 231, 234, 970, 969],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14],
    [15, 1, 2, 3, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26],
  ];
}
