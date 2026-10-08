// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `sidebarMenuRecipe`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftSidebarMenuRecipe].
class RaftSidebarMenuRecipeStyle {
  const RaftSidebarMenuRecipeStyle({required this.sidebarMenu, required this.sidebarMenuIcon, required this.sidebarMenuTitle, required this.sidebarMenuAside, required this.sidebarMenuCount});

  /// Slot `sidebarMenu`.
  final RaftSlotStyle sidebarMenu;
  /// Slot `sidebarMenuIcon`.
  final RaftSlotStyle sidebarMenuIcon;
  /// Slot `sidebarMenuTitle`.
  final RaftSlotStyle sidebarMenuTitle;
  /// Slot `sidebarMenuAside`.
  final RaftSlotStyle sidebarMenuAside;
  /// Slot `sidebarMenuCount`.
  final RaftSlotStyle sidebarMenuCount;

  Map<String, RaftSlotStyle> get slots => {'sidebarMenu': sidebarMenu, 'sidebarMenuIcon': sidebarMenuIcon, 'sidebarMenuTitle': sidebarMenuTitle, 'sidebarMenuAside': sidebarMenuAside, 'sidebarMenuCount': sidebarMenuCount};
}

/// raft-ui recipe `sidebarMenuRecipe` (`src/components/sidebar/sidebar-menu.recipe.ts`, index.mjs:3359).
///
/// Used by: SidebarMenu, SidebarMenuAside, SidebarMenuCount, SidebarMenuIcon, SidebarMenuTitle.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftSidebarMenuRecipe {
  static const String recipeName = 'sidebarMenuRecipe';
  static const List<String> slotNames = ['sidebarMenu', 'sidebarMenuIcon', 'sidebarMenuTitle', 'sidebarMenuAside', 'sidebarMenuCount'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftSidebarMenuRecipeStyle resolve({required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name], states, tokens);
    return RaftSidebarMenuRecipeStyle(sidebarMenu: s[0], sidebarMenuIcon: s[1], sidebarMenuTitle: s[2], sidebarMenuAside: s[3], sidebarMenuCount: s[4]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [1620, 2574, 1621, 2312, 1963, 1696, 3032, 1684, 3057, 3096, 2956, 3084, 2273, 1639, 1648, 1647, 1640],
    [1620, 2878, 2867, 2312, 2317, 429, 427, 421, 457, 445, 460],
    [2574, 3092],
    [1620, 2867, 2312, 1696],
    [1689, 2612, 3053, 2959],
    [1620, 2574, 1621, 2312, 1966, 3127, 2316, 1697, 2818, 2746, 3032, 2344, 1690, 2612, 3053, 2981, 2214, 2276, 1105, 606],
    [1620, 2878, 2867, 2312, 2317, 429, 427, 421, 457, 2978, 446, 461],
    [1620, 2867, 2312, 1696, 2585],
    [2867, 1691, 3032, 1688, 2344, 2613, 2978],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4], [5, 6, 2, 7, 8],
  ];
}
