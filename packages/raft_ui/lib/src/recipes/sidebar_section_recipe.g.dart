// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `sidebarSectionRecipe`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftSidebarSectionRecipe].
class RaftSidebarSectionRecipeStyle {
  const RaftSidebarSectionRecipeStyle({required this.sidebarSection, required this.sidebarList, required this.sidebarSectionEmpty, required this.sidebarSectionHeader, required this.sidebarSectionDisclosure, required this.sidebarSectionTitle, required this.sidebarSectionCount, required this.sidebarSectionAttention, required this.sidebarSectionTrailing, required this.sidebarSectionControls, required this.sidebarSectionControl});

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

  Map<String, RaftSlotStyle> get slots => {'sidebarSection': sidebarSection, 'sidebarList': sidebarList, 'sidebarSectionEmpty': sidebarSectionEmpty, 'sidebarSectionHeader': sidebarSectionHeader, 'sidebarSectionDisclosure': sidebarSectionDisclosure, 'sidebarSectionTitle': sidebarSectionTitle, 'sidebarSectionCount': sidebarSectionCount, 'sidebarSectionAttention': sidebarSectionAttention, 'sidebarSectionTrailing': sidebarSectionTrailing, 'sidebarSectionControls': sidebarSectionControls, 'sidebarSectionControl': sidebarSectionControl};
}

/// raft-ui recipe `sidebarSectionRecipe` (`src/components/sidebar/sidebar-section.recipe.ts`, index.mjs:4094).
///
/// Used by: SidebarList, SidebarSection, SidebarSectionAttention, SidebarSectionControl, SidebarSectionControls, SidebarSectionCount, SidebarSectionDisclosure, SidebarSectionEmpty, SidebarSectionHeader, SidebarSectionTitle, SidebarSectionTrailing.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftSidebarSectionRecipe {
  static const String recipeName = 'sidebarSectionRecipe';
  static const List<String> slotNames = ['sidebarSection', 'sidebarList', 'sidebarSectionEmpty', 'sidebarSectionHeader', 'sidebarSectionDisclosure', 'sidebarSectionTitle', 'sidebarSectionCount', 'sidebarSectionAttention', 'sidebarSectionTrailing', 'sidebarSectionControls', 'sidebarSectionControl'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftSidebarSectionRecipeStyle resolve({required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name], states, tokens);
    return RaftSidebarSectionRecipeStyle(sidebarSection: s[0], sidebarList: s[1], sidebarSectionEmpty: s[2], sidebarSectionHeader: s[3], sidebarSectionDisclosure: s[4], sidebarSectionTitle: s[5], sidebarSectionCount: s[6], sidebarSectionAttention: s[7], sidebarSectionTrailing: s[8], sidebarSectionControls: s[9], sidebarSectionControl: s[10]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [2747],
    [],
    [2751, 1691, 3032, 2346, 2961],
    [1620, 2312, 2316, 1932, 2602, 2491, 1963, 2751],
    [1620, 2574, 1621, 2312, 56, 330, 1963, 1697, 866, 916, 3032, 1684, 3057, 3096, 2956, 3084, 2273, 1639, 1648, 1647, 1640],
    [2574, 3092],
    [1689, 3032, 1688, 2612, 3053, 2964],
    [2301, 2577, 2867, 2312, 2317, 1877, 1882, 1903],
    [2775, 1620, 2577, 2867, 2312, 2318],
    [1620, 2867, 2312, 1696, 2716, 580, 3039, 2780, 155, 2626, 2456, 2442, 2459, 2436, 2525, 2524, 2520, 2519, 2532, 2531],
    [1620, 2883, 2312, 2317, 2667, 302, 288, 1691, 1684, 2964, 3084, 1601, 2193, 2272, 582, 1677, 1634, 1668, 1645],
    [2746, 3032, 2346, 2978],
    [1620, 2312, 2316, 1932, 2775, 137, 2603, 2489, 1966, 3119, 2818, 2747, 2214, 1105],
    [1620, 2574, 1621, 2312, 56, 330, 1966, 3127, 2322, 1697, 2818, 864, 916, 2746, 3032, 1688, 2344, 2612, 3053, 2978, 2280, 55],
    [2867, 1691, 3032, 1688, 2344, 2613, 2978],
    [2775, 1620, 2577, 2867, 2312, 2318, 2717],
    [1620, 2867, 2312, 1696, 2716, 580, 3039, 155, 2626, 2456, 2442, 2459, 2436, 2525, 2524, 2520, 2519, 2532, 2531, 2779],
    [1620, 2883, 2312, 2317, 2667, 302, 288, 2867, 2978, 2280],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10], [0, 1, 11, 12, 13, 5, 14, 7, 15, 16, 17],
  ];
}
