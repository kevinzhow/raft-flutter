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
      1159,
      965,
      1929,
      1319,
      1658,
      1836,
      1893,
      1527,
      1189,
      1023,
      1710,
      622,
      641,
      1666,
      1637,
      1618,
      1464,
      389,
      1016,
      1845,
      1013,
      1822,
      796,
      795,
      798,
      806,
      799,
      800,
      1533,
      1532,
      1577,
      1272,
      427,
      1534,
      996,
    ],
    [965, 1740, 1319, 1324, 177, 1762, 1824, 180, 186, 1112],
    [965, 1740, 1319, 1324, 277, 1762, 1824, 280, 292, 1112],
    [1211, 1484, 965, 966, 1318, 1021, 1836],
    [618, 1484, 1739, 1897, 1107],
    [618, 1484, 966, 1897, 1741, 1821, 1015, 1827, 1112],
    [1499, 1740, 1014, 1839, 1015, 1783, 1824, 1112],
    [1740, 1305, 1319],
    [
      1740,
      1319,
      1324,
      1019,
      115,
      277,
      295,
      1754,
      1491,
      1716,
      621,
      1592,
      575,
      1844,
      1310,
      1313,
      1695,
      1699,
      289,
      292,
    ],
    [1305, 1753, 1740, 1319, 1324, 277, 1824, 279, 1112],
    [965, 1740, 1319, 1021],
    [
      1740,
      1183,
      1491,
      1319,
      1324,
      1019,
      1716,
      621,
      1657,
      1666,
      770,
      570,
      1844,
      1310,
      1313,
      1695,
      1699,
      1014,
      1839,
      1008,
      1783,
      1873,
    ],
    [1519, 1561],
    [1305, 1319, 1020, 178, 177, 192],
    [1211, 1484, 966, 1836],
    [
      1159,
      965,
      1929,
      1658,
      1836,
      1893,
      1527,
      1023,
      1710,
      622,
      641,
      1637,
      1618,
      1016,
      1845,
      1013,
      1822,
      796,
      795,
      798,
      806,
      799,
      800,
      1533,
      1532,
      1577,
      1272,
      427,
      1534,
      996,
      1196,
      1321,
      1932,
      1480,
      1679,
      1465,
      391,
      37,
      38,
      39,
      66,
    ],
    [
      1159,
      965,
      1929,
      1319,
      1658,
      1836,
      1893,
      1527,
      1189,
      1023,
      1710,
      622,
      641,
      1666,
      1637,
      1618,
      1464,
      389,
      1016,
      1845,
      1013,
      1822,
      796,
      795,
      798,
      806,
      799,
      800,
      1533,
      1532,
      1577,
      660,
    ],
    [
      1159,
      965,
      1929,
      1658,
      1836,
      1893,
      1527,
      1023,
      1710,
      622,
      641,
      1637,
      1618,
      1016,
      1845,
      1013,
      1822,
      796,
      795,
      798,
      806,
      799,
      800,
      1533,
      1532,
      1577,
      660,
      1196,
      1321,
      1932,
      1480,
      1679,
      1465,
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
