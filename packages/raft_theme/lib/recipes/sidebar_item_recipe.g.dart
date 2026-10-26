// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `sidebarItemRecipe`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftSidebarItemRecipe].
class RaftSidebarItemRecipeStyle {
  const RaftSidebarItemRecipeStyle({
    required this.sidebarItem,
    required this.sidebarItemIcon,
    required this.sidebarItemChannelIcon,
    required this.sidebarItemContent,
    required this.sidebarItemTitle,
    required this.sidebarItemSubtitle,
    required this.sidebarItemMeta,
    required this.sidebarItemStatus,
    required this.sidebarItemIndicator,
    required this.sidebarItemMetaIcon,
    required this.sidebarItemAside,
    required this.sidebarItemCount,
    required this.sidebarItemCountSeparator,
    required this.sidebarItemThreadCount,
  });

  /// Slot `sidebarItem`.
  final RaftSlotStyle sidebarItem;

  /// Slot `sidebarItemIcon`.
  final RaftSlotStyle sidebarItemIcon;

  /// Slot `sidebarItemChannelIcon`.
  final RaftSlotStyle sidebarItemChannelIcon;

  /// Slot `sidebarItemContent`.
  final RaftSlotStyle sidebarItemContent;

  /// Slot `sidebarItemTitle`.
  final RaftSlotStyle sidebarItemTitle;

  /// Slot `sidebarItemSubtitle`.
  final RaftSlotStyle sidebarItemSubtitle;

  /// Slot `sidebarItemMeta`.
  final RaftSlotStyle sidebarItemMeta;

  /// Slot `sidebarItemStatus`.
  final RaftSlotStyle sidebarItemStatus;

  /// Slot `sidebarItemIndicator`.
  final RaftSlotStyle sidebarItemIndicator;

  /// Slot `sidebarItemMetaIcon`.
  final RaftSlotStyle sidebarItemMetaIcon;

  /// Slot `sidebarItemAside`.
  final RaftSlotStyle sidebarItemAside;

  /// Slot `sidebarItemCount`.
  final RaftSlotStyle sidebarItemCount;

  /// Slot `sidebarItemCountSeparator`.
  final RaftSlotStyle sidebarItemCountSeparator;

  /// Slot `sidebarItemThreadCount`.
  final RaftSlotStyle sidebarItemThreadCount;

  Map<String, RaftSlotStyle> get slots => {
    'sidebarItem': sidebarItem,
    'sidebarItemIcon': sidebarItemIcon,
    'sidebarItemChannelIcon': sidebarItemChannelIcon,
    'sidebarItemContent': sidebarItemContent,
    'sidebarItemTitle': sidebarItemTitle,
    'sidebarItemSubtitle': sidebarItemSubtitle,
    'sidebarItemMeta': sidebarItemMeta,
    'sidebarItemStatus': sidebarItemStatus,
    'sidebarItemIndicator': sidebarItemIndicator,
    'sidebarItemMetaIcon': sidebarItemMetaIcon,
    'sidebarItemAside': sidebarItemAside,
    'sidebarItemCount': sidebarItemCount,
    'sidebarItemCountSeparator': sidebarItemCountSeparator,
    'sidebarItemThreadCount': sidebarItemThreadCount,
  };
}

/// raft-ui recipe `sidebarItemRecipe` (`src/components/sidebar/sidebar-item.recipe.ts`, index.mjs:2877).
///
/// Used by: SidebarItem, SidebarItemAside, SidebarItemChannelIcon, SidebarItemContent, SidebarItemCount, SidebarItemCountSeparator, SidebarItemIcon, SidebarItemIndicator, SidebarItemMeta, SidebarItemMetaIcon, SidebarItemStatus, SidebarItemSubtitle, SidebarItemThreadCount, SidebarItemTitle.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftSidebarItemRecipe {
  static const String recipeName = 'sidebarItemRecipe';
  static const List<String> slotNames = [
    'sidebarItem',
    'sidebarItemIcon',
    'sidebarItemChannelIcon',
    'sidebarItemContent',
    'sidebarItemTitle',
    'sidebarItemSubtitle',
    'sidebarItemMeta',
    'sidebarItemStatus',
    'sidebarItemIndicator',
    'sidebarItemMetaIcon',
    'sidebarItemAside',
    'sidebarItemCount',
    'sidebarItemCountSeparator',
    'sidebarItemThreadCount',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('interactive', ['true', 'false'], 'true', false),
    RaftRecipeAxis('wrap', ['false', 'true'], 'false', false),
    RaftRecipeAxis('stacked', ['false', 'true'], 'false', false),
  ];

  static RaftSidebarItemRecipeStyle resolve({
    bool? interactive,
    bool? wrap,
    bool? stacked,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [interactive?.toString(), wrap?.toString(), stacked?.toString()],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftSidebarItemRecipeStyle(
      sidebarItem: s[0],
      sidebarItemIcon: s[1],
      sidebarItemChannelIcon: s[2],
      sidebarItemContent: s[3],
      sidebarItemTitle: s[4],
      sidebarItemSubtitle: s[5],
      sidebarItemMeta: s[6],
      sidebarItemStatus: s[7],
      sidebarItemIndicator: s[8],
      sidebarItemMetaIcon: s[9],
      sidebarItemAside: s[10],
      sidebarItemCount: s[11],
      sidebarItemCountSeparator: s[12],
      sidebarItemThreadCount: s[13],
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
      1158,
      965,
      1924,
      1318,
      1654,
      1832,
      1889,
      1523,
      1188,
      1022,
      1706,
      622,
      641,
      1662,
      1633,
      1614,
      1461,
      389,
      1015,
      1841,
      1012,
      1818,
      796,
      795,
      798,
      806,
      799,
      800,
      1529,
      1528,
      1573,
      1271,
      427,
      1530,
      995,
    ],
    [965, 1736, 1318, 1323, 177, 1758, 1820, 180, 186, 1111],
    [965, 1736, 1318, 1323, 277, 1758, 1820, 280, 292, 1111],
    [1210, 1481, 965, 966, 1317, 1020, 1832],
    [618, 1481, 1735, 1893, 1106],
    [618, 1481, 966, 1893, 1737, 1817, 1014, 1823, 1111],
    [1495, 1736, 1013, 1835, 1014, 1779, 1820, 1111],
    [1736, 1304, 1318],
    [
      1736,
      1318,
      1323,
      1018,
      115,
      277,
      295,
      1750,
      1488,
      1712,
      621,
      1588,
      575,
      1840,
      1309,
      1312,
      1691,
      1695,
      289,
      292,
    ],
    [1304, 1749, 1736, 1318, 1323, 277, 1820, 279, 1111],
    [965, 1736, 1318, 1020],
    [
      1736,
      1182,
      1488,
      1318,
      1323,
      1018,
      1712,
      621,
      1653,
      1662,
      770,
      570,
      1840,
      1309,
      1312,
      1691,
      1695,
      1013,
      1835,
      1007,
      1779,
      1869,
    ],
    [1515, 1557],
    [1304, 1318, 1019, 178, 177, 192],
    [1210, 1481, 966, 1832],
    [
      1158,
      965,
      1924,
      1654,
      1832,
      1889,
      1523,
      1022,
      1706,
      622,
      641,
      1633,
      1614,
      1015,
      1841,
      1012,
      1818,
      796,
      795,
      798,
      806,
      799,
      800,
      1529,
      1528,
      1573,
      1271,
      427,
      1530,
      995,
      1195,
      1320,
      1927,
      1477,
      1675,
      1462,
      391,
      37,
      38,
      39,
      66,
    ],
    [
      1158,
      965,
      1924,
      1318,
      1654,
      1832,
      1889,
      1523,
      1188,
      1022,
      1706,
      622,
      641,
      1662,
      1633,
      1614,
      1461,
      389,
      1015,
      1841,
      1012,
      1818,
      796,
      795,
      798,
      806,
      799,
      800,
      1529,
      1528,
      1573,
      660,
    ],
    [
      1158,
      965,
      1924,
      1654,
      1832,
      1889,
      1523,
      1022,
      1706,
      622,
      641,
      1633,
      1614,
      1015,
      1841,
      1012,
      1818,
      796,
      795,
      798,
      806,
      799,
      800,
      1529,
      1528,
      1573,
      660,
      1195,
      1320,
      1927,
      1477,
      1675,
      1462,
      391,
      37,
      38,
      39,
      66,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13],
    [0, 1, 2, 14, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13],
    [15, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13],
    [15, 1, 2, 14, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13],
    [16, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13],
    [16, 1, 2, 14, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13],
    [17, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13],
    [17, 1, 2, 14, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13],
  ];
}
