// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `sidebarSectionRecipe`.
// ignore_for_file: type=lint

import '../recipe_runtime.dart';
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

/// raft-ui recipe `sidebarSectionRecipe` (`src/components/sidebar/sidebar-section.recipe.ts`, index.mjs:4109).
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
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftSidebarSectionRecipeStyle resolve({
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
    [1933, 2775],
    [],
    [2779, 1716, 3073, 2365, 2998],
    [1644, 2331, 2335, 1934, 2625, 2512, 1965, 2779],
    [
      1644,
      2597,
      1645,
      2331,
      56,
      328,
      1965,
      1722,
      878,
      930,
      3073,
      1709,
      3098,
      3137,
      2994,
      3125,
      2292,
      1663,
      1672,
      1671,
      1664,
    ],
    [2597, 3133],
    [1714, 3073, 1713, 2634, 3094, 3001],
    [2320, 2600, 2902, 2331, 2336, 1871, 1873, 1904],
    [2804, 1644, 2600, 2902, 2331, 2337],
    [
      1644,
      2902,
      2331,
      1721,
      2739,
      586,
      3080,
      2809,
      155,
      2649,
      2476,
      2462,
      2479,
      2456,
      2548,
      2547,
      2542,
      2541,
      2555,
      2554,
    ],
    [
      1644,
      2918,
      2331,
      2336,
      2690,
      298,
      284,
      1716,
      1709,
      3001,
      3125,
      1625,
      2212,
      2291,
      588,
      1702,
      1658,
      1692,
      1669,
    ],
    [2774, 3073, 2365, 3015],
    [
      1644,
      2331,
      2335,
      1934,
      2804,
      137,
      2626,
      2510,
      1968,
      3160,
      2848,
      2775,
      2233,
      1125,
    ],
    [
      1644,
      2597,
      1645,
      2331,
      56,
      328,
      1968,
      3168,
      2341,
      1722,
      2848,
      876,
      930,
      2774,
      3073,
      1713,
      2363,
      2634,
      3094,
      3015,
      2299,
      55,
    ],
    [2902, 1716, 3073, 1713, 2363, 2635, 3015],
    [2804, 1644, 2600, 2902, 2331, 2337, 2742],
    [
      1644,
      2902,
      2331,
      1721,
      2739,
      586,
      3080,
      155,
      2649,
      2476,
      2462,
      2479,
      2456,
      2548,
      2547,
      2542,
      2541,
      2555,
      2554,
      2808,
    ],
    [1644, 2918, 2331, 2336, 2690, 298, 284, 2902, 3015, 2299],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
    [0, 1, 11, 12, 13, 5, 14, 7, 15, 16, 17],
  ];
}
