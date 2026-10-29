// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `sidebarSectionRecipe`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftSidebarSectionRecipe].
class RaftSidebarSectionRecipeStyle {
  const RaftSidebarSectionRecipeStyle({
    required this.sidebarSection,
    required this.sidebarList,
    required this.sidebarSectionEmpty,
    required this.sidebarSectionHeader,
    required this.sidebarSectionDisclosure,
    required this.sidebarSectionTitle,
    required this.sidebarSectionCount,
    required this.sidebarSectionAttention,
    required this.sidebarSectionTrailing,
    required this.sidebarSectionControls,
    required this.sidebarSectionControl,
  });

  /// Slot `sidebarSection`.
  final RaftSlotStyle sidebarSection;

  /// Slot `sidebarList`.
  final RaftSlotStyle sidebarList;

  /// Slot `sidebarSectionEmpty`.
  final RaftSlotStyle sidebarSectionEmpty;

  /// Slot `sidebarSectionHeader`.
  final RaftSlotStyle sidebarSectionHeader;

  /// Slot `sidebarSectionDisclosure`.
  final RaftSlotStyle sidebarSectionDisclosure;

  /// Slot `sidebarSectionTitle`.
  final RaftSlotStyle sidebarSectionTitle;

  /// Slot `sidebarSectionCount`.
  final RaftSlotStyle sidebarSectionCount;

  /// Slot `sidebarSectionAttention`.
  final RaftSlotStyle sidebarSectionAttention;

  /// Slot `sidebarSectionTrailing`.
  final RaftSlotStyle sidebarSectionTrailing;

  /// Slot `sidebarSectionControls`.
  final RaftSlotStyle sidebarSectionControls;

  /// Slot `sidebarSectionControl`.
  final RaftSlotStyle sidebarSectionControl;

  Map<String, RaftSlotStyle> get slots => {
    'sidebarSection': sidebarSection,
    'sidebarList': sidebarList,
    'sidebarSectionEmpty': sidebarSectionEmpty,
    'sidebarSectionHeader': sidebarSectionHeader,
    'sidebarSectionDisclosure': sidebarSectionDisclosure,
    'sidebarSectionTitle': sidebarSectionTitle,
    'sidebarSectionCount': sidebarSectionCount,
    'sidebarSectionAttention': sidebarSectionAttention,
    'sidebarSectionTrailing': sidebarSectionTrailing,
    'sidebarSectionControls': sidebarSectionControls,
    'sidebarSectionControl': sidebarSectionControl,
  };
}

/// raft-ui recipe `sidebarSectionRecipe` (`src/components/sidebar/sidebar-section.recipe.ts`, index.mjs:3265).
///
/// Used by: SidebarList, SidebarSection, SidebarSectionAttention, SidebarSectionControl, SidebarSectionControls, SidebarSectionCount, SidebarSectionDisclosure, SidebarSectionEmpty, SidebarSectionHeader, SidebarSectionTitle, SidebarSectionTrailing.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftSidebarSectionRecipe {
  static const String recipeName = 'sidebarSectionRecipe';
  static const List<String> slotNames = [
    'sidebarSection',
    'sidebarList',
    'sidebarSectionEmpty',
    'sidebarSectionHeader',
    'sidebarSectionDisclosure',
    'sidebarSectionTitle',
    'sidebarSectionCount',
    'sidebarSectionAttention',
    'sidebarSectionTrailing',
    'sidebarSectionControls',
    'sidebarSectionControl',
  ];
  static const List<RaftRecipeAxis> axes = [];

  static RaftSidebarSectionRecipeStyle resolve({
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
    return RaftSidebarSectionRecipeStyle(
      sidebarSection: s[0],
      sidebarList: s[1],
      sidebarSectionEmpty: s[2],
      sidebarSectionHeader: s[3],
      sidebarSectionDisclosure: s[4],
      sidebarSectionTitle: s[5],
      sidebarSectionCount: s[6],
      sidebarSectionAttention: s[7],
      sidebarSectionTrailing: s[8],
      sidebarSectionControls: s[9],
      sidebarSectionControl: s[10],
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
    [1157, 1652],
    [],
    [1656, 1667, 1016, 1819, 1822],
    [965, 1319, 1323, 1158, 1507, 1429, 1196, 1023, 1656, 1646, 1603],
    [
      965,
      1483,
      966,
      1319,
      42,
      202,
      1196,
      1022,
      1714,
      621,
      1016,
      1819,
      1008,
      1527,
      1871,
      1822,
      1575,
      996,
      40,
      41,
    ],
    [1483, 1895],
    [1014, 1837, 1015, 1781, 1822],
    [1305, 1488, 1738, 1319, 1324, 1119, 1121, 1129],
    [1680, 965, 1488, 1738, 1319, 1325],
    [
      965,
      1738,
      1319,
      1021,
      1628,
      422,
      1863,
      1684,
      110,
      1556,
      1394,
      1389,
      1398,
      1386,
      1448,
      1447,
      1443,
      1442,
      1453,
      1452,
    ],
    [965, 1186, 1924, 1492, 1738, 1319, 1324, 1590, 100, 177, 159],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
  ];
}
