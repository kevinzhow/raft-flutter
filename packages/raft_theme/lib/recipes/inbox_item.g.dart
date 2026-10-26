// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
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

/// raft-ui recipe `inboxItem` (`src/components/inbox-item/inbox-item.recipe.ts`, index.mjs:16083).
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
  static const List<RaftRecipeAxis> axes = [];

  static RaftInboxItemRecipeStyle resolve({
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
      1678,
      1039,
      1924,
      1043,
      1320,
      1024,
      1592,
      1832,
      1251,
      1889,
      1033,
      1035,
      1710,
      621,
      615,
      1658,
      1669,
      1734,
      545,
      513,
      554,
      546,
      541,
      536,
      526,
      524,
      404,
      1250,
      1271,
      667,
      668,
      834,
      832,
      1225,
      1226,
    ],
    [422, 1306, 1934, 1573],
    [1678, 1935, 1506, 965, 1749, 1736, 1318, 1323],
    [1626, 1678, 1935, 1481, 966, 1832],
    [965, 1481, 1318, 1428, 1021, 1662, 1810, 1820],
    [1481, 1506, 1427, 1662, 1810, 1820],
    [965, 1481, 1320, 1022, 1427],
    [
      1678,
      1352,
      1481,
      966,
      1620,
      165,
      190,
      170,
      179,
      1015,
      1841,
      1016,
      1823,
      1108,
      1109,
      188,
    ],
    [
      1626,
      1678,
      1935,
      965,
      1736,
      1505,
      967,
      1319,
      1022,
      1649,
      1378,
      1382,
      1380,
      454,
      463,
      462,
      460,
      445,
      447,
      443,
      1107,
    ],
    [1736, 1928, 1837, 1779, 1013, 1835, 1820],
    [1352, 1506, 1809, 1823],
    [1481, 1506, 1352, 1809, 1823],
    [1016, 1818],
    [965, 1472, 971, 1318, 1021, 1509],
    [
      1625,
      965,
      1736,
      1318,
      1563,
      1019,
      72,
      73,
      138,
      74,
      75,
      139,
      142,
      141,
      143,
      140,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14],
  ];
}
