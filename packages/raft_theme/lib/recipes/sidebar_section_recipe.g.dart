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
    [1156, 1650],
    [],
    [1654, 1665, 1015, 1817, 1820],
    [965, 1318, 1322, 1157, 1505, 1427, 1195, 1022, 1654, 1644, 1601],
    [
      965,
      1481,
      966,
      1318,
      42,
      202,
      1195,
      1021,
      1712,
      621,
      1015,
      1817,
      1007,
      1525,
      1869,
      1820,
      1573,
      995,
      40,
      41,
    ],
    [1481, 1893],
    [1013, 1835, 1014, 1779, 1820],
    [1304, 1486, 1736, 1318, 1323, 1118, 1120, 1128],
    [1678, 965, 1486, 1736, 1318, 1324],
    [
      965,
      1736,
      1318,
      1020,
      1626,
      422,
      1861,
      1682,
      110,
      1554,
      1392,
      1387,
      1396,
      1384,
      1446,
      1445,
      1441,
      1440,
      1451,
      1450,
    ],
    [965, 1185, 1922, 1490, 1736, 1318, 1323, 1588, 100, 177, 159],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
  ];
}
