// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `sidebarMenuRecipe`.
// ignore_for_file: type=lint

import '../recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftSidebarMenuRecipe].
class RaftSidebarMenuRecipeStyle {
  const RaftSidebarMenuRecipeStyle({
    required this.sidebarMenu,
    required this.sidebarMenuIcon,
    required this.sidebarMenuTitle,
    required this.sidebarMenuAside,
    required this.sidebarMenuCount,
  });

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

  Map<String, RaftSlotStyle> get slots => {
    'sidebarMenu': sidebarMenu,
    'sidebarMenuIcon': sidebarMenuIcon,
    'sidebarMenuTitle': sidebarMenuTitle,
    'sidebarMenuAside': sidebarMenuAside,
    'sidebarMenuCount': sidebarMenuCount,
  };
}

/// raft-ui recipe `sidebarMenuRecipe` (`src/components/sidebar/sidebar-menu.recipe.ts`, index.mjs:3370).
///
/// Used by: SidebarMenu, SidebarMenuAside, SidebarMenuCount, SidebarMenuIcon, SidebarMenuTitle.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftSidebarMenuRecipe {
  static const String recipeName = 'sidebarMenuRecipe';
  static const List<String> slotNames = [
    'sidebarMenu',
    'sidebarMenuIcon',
    'sidebarMenuTitle',
    'sidebarMenuAside',
    'sidebarMenuCount',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftSidebarMenuRecipeStyle resolve({
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
    return RaftSidebarMenuRecipeStyle(
      sidebarMenu: s[0],
      sidebarMenuIcon: s[1],
      sidebarMenuTitle: s[2],
      sidebarMenuAside: s[3],
      sidebarMenuCount: s[4],
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
      1644,
      2597,
      1645,
      2331,
      1965,
      1721,
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
    [1644, 2913, 2902, 2331, 2336, 427, 425, 419, 455, 443, 458],
    [2597, 3133],
    [1644, 2902, 2331, 1721],
    [1714, 2634, 3094, 2996],
    [
      1644,
      2597,
      1645,
      2331,
      1968,
      3168,
      2335,
      1722,
      2848,
      2774,
      3073,
      2363,
      1715,
      2634,
      3094,
      3018,
      2233,
      2295,
      1125,
      612,
    ],
    [1644, 2913, 2902, 2331, 2336, 427, 425, 419, 455, 3015, 444, 459],
    [1644, 2902, 2331, 1721, 2608],
    [2902, 1716, 3073, 1713, 2363, 2635, 3015],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4],
    [5, 6, 2, 7, 8],
  ];
}
