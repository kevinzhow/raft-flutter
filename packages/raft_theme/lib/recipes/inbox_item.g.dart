// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `inboxItem`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `density` axis of `inboxItem`.
enum RaftInboxItemRecipeDensity {
  compact('compact');

  const RaftInboxItemRecipeDensity(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// `reveal` axis of `inboxItem`.
enum RaftInboxItemRecipeReveal {
  hover('hover');

  const RaftInboxItemRecipeReveal(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftInboxItemRecipe].
class RaftInboxItemRecipeStyle {
  const RaftInboxItemRecipeStyle({
    required this.item,
    required this.itemTrigger,
    required this.itemLeading,
    required this.itemLeadingBadge,
    required this.itemSelection,
    required this.itemContent,
    required this.itemContext,
    required this.itemSubtitle,
    required this.itemHeading,
    required this.itemTitle,
    required this.itemTrailing,
    required this.itemStatusWord,
    required this.itemStatusPixel,
    required this.itemListGroup,
    required this.itemListHeading,
    required this.itemMarks,
    required this.itemHoverTarget,
    required this.itemTimestamp,
    required this.itemLine,
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

  /// Slot `itemLeading`.
  final RaftSlotStyle itemLeading;

  /// Slot `itemLeadingBadge`.
  final RaftSlotStyle itemLeadingBadge;

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

  /// Slot `itemStatusWord`.
  final RaftSlotStyle itemStatusWord;

  /// Slot `itemStatusPixel`.
  final RaftSlotStyle itemStatusPixel;

  /// Slot `itemListGroup`.
  final RaftSlotStyle itemListGroup;

  /// Slot `itemListHeading`.
  final RaftSlotStyle itemListHeading;

  /// Slot `itemMarks`.
  final RaftSlotStyle itemMarks;

  /// Slot `itemHoverTarget`.
  final RaftSlotStyle itemHoverTarget;

  /// Slot `itemTimestamp`.
  final RaftSlotStyle itemTimestamp;

  /// Slot `itemLine`.
  final RaftSlotStyle itemLine;

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
    'itemLeading': itemLeading,
    'itemLeadingBadge': itemLeadingBadge,
    'itemSelection': itemSelection,
    'itemContent': itemContent,
    'itemContext': itemContext,
    'itemSubtitle': itemSubtitle,
    'itemHeading': itemHeading,
    'itemTitle': itemTitle,
    'itemTrailing': itemTrailing,
    'itemStatusWord': itemStatusWord,
    'itemStatusPixel': itemStatusPixel,
    'itemListGroup': itemListGroup,
    'itemListHeading': itemListHeading,
    'itemMarks': itemMarks,
    'itemHoverTarget': itemHoverTarget,
    'itemTimestamp': itemTimestamp,
    'itemLine': itemLine,
    'itemBody': itemBody,
    'itemMessage': itemMessage,
    'itemSender': itemSender,
    'itemMetadata': itemMetadata,
    'itemActions': itemActions,
  };
}

/// raft-ui recipe `inboxItem` (`dist/components/inbox-item/inbox-item.recipe.mjs`, index.mjs:23837).
///
/// Used by: InboxItem, InboxItemActions, InboxItemBody, InboxItemContent, InboxItemContext, InboxItemHeading, InboxItemHoverTarget, InboxItemLeading, InboxItemLeadingBadge, InboxItemLine, InboxItemListGroup, InboxItemListHeading, InboxItemMarks, InboxItemMessage, InboxItemMetadata, InboxItemSelection, InboxItemSender, InboxItemStatus, InboxItemSubtitle, InboxItemTimestamp, InboxItemTitle, InboxItemTrailing, InboxItemTrigger.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftInboxItemRecipe {
  static const String recipeName = 'inboxItem';
  static const List<String> slotNames = [
    'item',
    'itemTrigger',
    'itemLeading',
    'itemLeadingBadge',
    'itemSelection',
    'itemContent',
    'itemContext',
    'itemSubtitle',
    'itemHeading',
    'itemTitle',
    'itemTrailing',
    'itemStatusWord',
    'itemStatusPixel',
    'itemListGroup',
    'itemListHeading',
    'itemMarks',
    'itemHoverTarget',
    'itemTimestamp',
    'itemLine',
    'itemBody',
    'itemMessage',
    'itemSender',
    'itemMetadata',
    'itemActions',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('density', ['compact'], null, true),
    RaftRecipeAxis('reveal', ['hover'], null, true),
  ];

  static RaftInboxItemRecipeStyle resolve({
    RaftInboxItemRecipeDensity? density,
    RaftInboxItemRecipeReveal? reveal,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [density?.css, reveal?.css],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftInboxItemRecipeStyle(
      item: s[0],
      itemTrigger: s[1],
      itemLeading: s[2],
      itemLeadingBadge: s[3],
      itemSelection: s[4],
      itemContent: s[5],
      itemContext: s[6],
      itemSubtitle: s[7],
      itemHeading: s[8],
      itemTitle: s[9],
      itemTrailing: s[10],
      itemStatusWord: s[11],
      itemStatusPixel: s[12],
      itemListGroup: s[13],
      itemListHeading: s[14],
      itemMarks: s[15],
      itemHoverTarget: s[16],
      itemTimestamp: s[17],
      itemLine: s[18],
      itemBody: s[19],
      itemMessage: s[20],
      itemSender: s[21],
      itemMetadata: s[22],
      itemActions: s[23],
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
      1489,
      2725,
      1495,
      1866,
      1468,
      2613,
      1747,
      1739,
      1748,
      1481,
      1484,
      2468,
      940,
      2419,
      2073,
      2336,
      2342,
      1904,
      2433,
      1862,
      933,
      2497,
      2247,
      503,
      504,
      505,
      2017,
      502,
      2366,
      2308,
      849,
      810,
      872,
      820,
      828,
      840,
      850,
      841,
      853,
      821,
      865,
      830,
      831,
      2183,
      2182,
      694,
      2180,
      2181,
      1001,
      1185,
      1715,
      1716,
      2168,
      2169,
    ],
    [691, 1849, 2736, 2247],
    [2346, 2433, 2747, 1400, 2523, 2499, 1864, 1869],
    [
      691,
      182,
      166,
      2747,
      1847,
      2516,
      1864,
      1869,
      2458,
      939,
      958,
      2244,
      2246,
      2249,
      910,
      882,
      2598,
      475,
      474,
    ],
    [2433, 2747, 1400, 2519, 2499, 1864, 1869],
    [2346, 2433, 2747, 2116, 1401, 2613, 168, 982, 2476, 676, 1500],
    [984, 2212, 1400, 2116, 1864, 1987, 1465, 2412, 2588, 2600],
    [984, 2212, 2116, 2144, 1986, 2412, 2588, 2600],
    [984, 2212, 1400, 2116, 1866, 1466, 1986],
    [
      2433,
      1901,
      2116,
      1401,
      2304,
      334,
      362,
      340,
      351,
      1456,
      2622,
      1457,
      2603,
      1555,
      1556,
      359,
    ],
    [
      2346,
      2433,
      2747,
      980,
      2476,
      1400,
      2499,
      2143,
      1404,
      1865,
      1466,
      2391,
      1934,
      1940,
      1937,
      734,
      754,
      722,
      753,
      750,
      725,
      727,
      724,
      1553,
      157,
      746,
      156,
      744,
      158,
      757,
      2350,
      2334,
      1584,
      1578,
      1504,
      1572,
      1687,
    ],
    [2499, 207],
    [1776, 1864, 208],
    [1400, 1404, 1463, 2146, 1392],
    [1987, 2396, 2414, 1456, 2597, 1449, 2600],
    [1400, 1656, 2499, 1864, 1870, 1465, 2600],
    [2345],
    [2499, 2729, 2618, 2556, 1454, 2616, 2600],
    [1400, 1642, 2116, 1864, 1466, 160, 159, 111],
    [984, 2212, 1901, 2144, 2587, 2603],
    [984, 2212, 2116, 2144, 1901, 2587, 2603],
    [1457, 2598],
    [984, 2212, 1400, 2103, 1408, 1864, 1465, 2147],
    [
      2345,
      1400,
      2499,
      1864,
      2237,
      1463,
      122,
      123,
      297,
      124,
      125,
      298,
      301,
      300,
      303,
      302,
      299,
      2333,
      2315,
      2314,
      2317,
      2316,
    ],
    [2499, 2729, 2618, 2556, 1454, 2616, 2600, 677],
    [
      1400,
      2499,
      1864,
      2237,
      1463,
      122,
      123,
      297,
      124,
      125,
      298,
      301,
      300,
      303,
      302,
      299,
      2333,
      2315,
      2314,
      2317,
      2316,
      691,
      2640,
      2437,
      2747,
      2346,
      2228,
      2676,
      1586,
      1585,
      1580,
      1579,
      1506,
      1505,
      1574,
      1573,
      1772,
      1770,
      2341,
      2340,
      2338,
    ],
    [
      1489,
      2725,
      1495,
      1468,
      2613,
      1747,
      1739,
      1748,
      1481,
      1484,
      2468,
      940,
      2419,
      2073,
      2336,
      2342,
      1904,
      2433,
      1862,
      933,
      2497,
      2247,
      503,
      504,
      505,
      2017,
      502,
      2366,
      2308,
      849,
      810,
      872,
      820,
      828,
      840,
      850,
      841,
      853,
      821,
      865,
      830,
      831,
      2183,
      2182,
      694,
      2180,
      2181,
      1001,
      1185,
      1715,
      1716,
      2168,
      2169,
      1864,
      1740,
      1741,
      1746,
      1745,
      1744,
      1742,
      1743,
    ],
    [2346, 2433, 2747, 2116, 1401, 2613, 168, 982, 2476, 676, 1500, 1696],
    [984, 2212, 1400, 2116, 1866, 1466, 1986, 1684, 1685, 149, 148],
    [
      2433,
      2116,
      1401,
      334,
      362,
      340,
      351,
      1456,
      2622,
      1457,
      2603,
      1555,
      1556,
      359,
      1900,
      2295,
      1709,
    ],
    [
      2346,
      2433,
      2747,
      980,
      2476,
      1400,
      2499,
      2143,
      1404,
      1865,
      1934,
      1940,
      734,
      754,
      722,
      753,
      750,
      725,
      727,
      724,
      157,
      746,
      156,
      744,
      158,
      757,
      2350,
      2334,
      1584,
      1578,
      1504,
      1572,
      1687,
      1462,
      2378,
      1936,
      1554,
    ],
    [2499, 2729, 2618, 2556, 1454, 2616, 2600, 1883],
    [984, 2212, 2587, 2603, 1900, 2143],
    [984, 2212, 2116, 2587, 2603, 1900, 2143],
    [2499, 2729, 2618, 2556, 1454, 2616, 2600, 1883, 677],
    [
      1400,
      2499,
      1864,
      2237,
      1463,
      122,
      123,
      297,
      124,
      125,
      298,
      301,
      300,
      303,
      302,
      299,
      2333,
      2315,
      2314,
      2317,
      2316,
      691,
      2437,
      2747,
      2346,
      2228,
      2676,
      1586,
      1585,
      1580,
      1579,
      1506,
      1505,
      1574,
      1573,
      1772,
      1770,
      2341,
      2340,
      2338,
      2642,
      193,
      2339,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [
      0,
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      9,
      10,
      11,
      12,
      13,
      14,
      15,
      16,
      17,
      18,
      19,
      20,
      21,
      22,
      23,
    ],
    [
      0,
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      9,
      10,
      11,
      12,
      13,
      14,
      15,
      16,
      24,
      18,
      19,
      20,
      21,
      22,
      25,
    ],
    [
      26,
      1,
      2,
      3,
      4,
      27,
      6,
      7,
      28,
      29,
      30,
      11,
      12,
      13,
      14,
      15,
      16,
      31,
      18,
      32,
      33,
      21,
      22,
      23,
    ],
    [
      26,
      1,
      2,
      3,
      4,
      27,
      6,
      7,
      28,
      29,
      30,
      11,
      12,
      13,
      14,
      15,
      16,
      34,
      18,
      32,
      33,
      21,
      22,
      35,
    ],
  ];
}
