// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `activityInboxSidebar`.
// ignore_for_file: type=lint

import '../recipe_runtime.dart';
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

/// raft-ui recipe `activityInboxSidebar` (`src/components/activity-inbox/activity-inbox-sidebar.recipe.ts`, index.mjs:19897).
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
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftActivityInboxSidebarRecipeStyle resolve({
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
    [3152, 2902, 2448, 2535, 922, 892],
    [868],
    [
      2695,
      392,
      391,
      48,
      50,
      390,
      393,
      394,
      49,
      388,
      395,
      52,
      54,
      66,
      69,
      343,
      345,
      74,
      67,
      70,
      72,
      65,
      73,
      340,
    ],
    [2902, 2448, 2535, 3153, 1011],
    [],
    [
      2695,
      392,
      391,
      48,
      50,
      390,
      393,
      394,
      49,
      389,
      53,
      51,
      66,
      69,
      344,
      345,
      74,
      67,
      71,
      73,
      68,
      341,
      342,
      338,
      339,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2],
    [3, 4, 5],
  ];
}
