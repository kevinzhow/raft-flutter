// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `sidebarSectionRecipe`.
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
    required this.sidebarSectionChevronSlot,
    required this.sidebarSectionEndChevron,
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

  /// Slot `sidebarSectionChevronSlot`.
  final RaftSlotStyle sidebarSectionChevronSlot;

  /// Slot `sidebarSectionEndChevron`.
  final RaftSlotStyle sidebarSectionEndChevron;

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
    'sidebarSectionChevronSlot': sidebarSectionChevronSlot,
    'sidebarSectionEndChevron': sidebarSectionEndChevron,
    'sidebarSectionTitle': sidebarSectionTitle,
    'sidebarSectionCount': sidebarSectionCount,
    'sidebarSectionAttention': sidebarSectionAttention,
    'sidebarSectionTrailing': sidebarSectionTrailing,
    'sidebarSectionControls': sidebarSectionControls,
    'sidebarSectionControl': sidebarSectionControl,
  };
}

/// raft-ui recipe `sidebarSectionRecipe` (`dist/components/sidebar/sidebar-section.recipe.mjs`, index.mjs:4833).
///
/// Used by: SidebarList, SidebarSection, SidebarSectionAttention, SidebarSectionChevron, SidebarSectionControl, SidebarSectionControls, SidebarSectionCount, SidebarSectionDisclosure, SidebarSectionEmpty, SidebarSectionEndChevron, SidebarSectionHeader, SidebarSectionTitle, SidebarSectionTrailing.
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
    'sidebarSectionChevronSlot',
    'sidebarSectionEndChevron',
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
      sidebarSectionChevronSlot: s[5],
      sidebarSectionEndChevron: s[6],
      sidebarSectionTitle: s[7],
      sidebarSectionCount: s[8],
      sidebarSectionAttention: s[9],
      sidebarSectionTrailing: s[10],
      sidebarSectionControls: s[11],
      sidebarSectionControl: s[12],
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
    [1619, 2397],
    [1400, 1404, 1463, 2417, 2065],
    [2396, 2060, 2417, 1456, 2597, 2600],
    [
      1400,
      1864,
      1868,
      1620,
      2157,
      1673,
      1466,
      2384,
      2272,
      2303,
      2365,
      2051,
      2067,
      2059,
      2064,
      2211,
    ],
    [
      1400,
      2116,
      1401,
      1864,
      69,
      375,
      1673,
      1465,
      2471,
      940,
      1456,
      2597,
      1449,
      2165,
      2654,
      2600,
      2247,
      1439,
      67,
      68,
    ],
    [1400, 2518, 2499, 1864, 1869, 2043],
    [1776, 2037, 493, 1269],
    [2116, 2681],
    [1454, 2616, 1455, 2556, 2600],
    [1847, 2120, 2499, 1864, 1869, 1568],
    [2433, 1400, 2120, 2499, 1864, 1870],
    [1400, 2499, 1864, 1464, 267],
    [
      2433,
      1400,
      1658,
      2723,
      2124,
      2499,
      1864,
      1869,
      2260,
      178,
      2081,
      2041,
      2053,
      474,
      459,
      541,
      2600,
      1798,
      701,
      1441,
      1277,
      1284,
      2206,
      2208,
      2207,
      2347,
      2349,
      2348,
      2209,
      2210,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
  ];
}
