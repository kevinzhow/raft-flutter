// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `sidebarMenuRecipe`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
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

/// raft-ui recipe `sidebarMenuRecipe` (`src/components/sidebar/sidebar-menu.recipe.ts`, index.mjs:2794).
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
  static const List<RaftRecipeAxis> axes = [];

  static RaftSidebarMenuRecipeStyle resolve({
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
      965,
      1484,
      966,
      1319,
      1196,
      1022,
      1716,
      1016,
      1821,
      1008,
      1529,
      1873,
      1824,
      1285,
      474,
      1577,
      996,
    ],
    [965, 1740, 1319, 1324, 277, 274, 296, 1752, 279, 292, 297],
    [1484, 1897],
    [965, 1740, 1319, 1021],
    [1014, 1839, 1015, 1783, 1824],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4],
  ];
}
