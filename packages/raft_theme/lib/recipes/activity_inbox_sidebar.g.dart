// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `activityInboxSidebar`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftActivityInboxSidebarRecipe].
class RaftActivityInboxSidebarRecipeStyle {
  const RaftActivityInboxSidebarRecipeStyle({
    required this.sidebar,
    required this.sidebarBody,
    required this.sidebarContent,
  });

  /// Slot `sidebar`.
  final RaftSlotStyle sidebar;

  /// Slot `sidebarBody`.
  final RaftSlotStyle sidebarBody;

  /// Slot `sidebarContent`.
  final RaftSlotStyle sidebarContent;

  Map<String, RaftSlotStyle> get slots => {
    'sidebar': sidebar,
    'sidebarBody': sidebarBody,
    'sidebarContent': sidebarContent,
  };
}

/// raft-ui recipe `activityInboxSidebar` (`src/components/activity-inbox/activity-inbox-sidebar.recipe.ts`, index.mjs:16003).
///
/// Used by: ActivityInboxSidebar.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftActivityInboxSidebarRecipe {
  static const String recipeName = 'activityInboxSidebar';
  static const List<String> slotNames = [
    'sidebar',
    'sidebarBody',
    'sidebarContent',
  ];
  static const List<RaftRecipeAxis> axes = [];

  static RaftActivityInboxSidebarRecipeStyle resolve({
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
    return RaftActivityInboxSidebarRecipeStyle(
      sidebar: s[0],
      sidebarBody: s[1],
      sidebarContent: s[2],
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
    [1736, 1381, 1437, 1907, 636, 634, 595],
    [595],
    [
      1592,
      233,
      232,
      31,
      33,
      231,
      234,
      235,
      32,
      35,
      230,
      36,
      34,
      236,
      48,
      50,
      205,
      206,
      54,
      49,
      51,
      52,
      47,
      53,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2],
  ];
}
