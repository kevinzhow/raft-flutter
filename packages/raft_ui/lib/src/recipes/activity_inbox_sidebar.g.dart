// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `activityInboxSidebar`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftActivityInboxSidebarRecipe].
class RaftActivityInboxSidebarRecipeStyle {
  const RaftActivityInboxSidebarRecipeStyle({required this.sidebar, required this.sidebarBody, required this.sidebarContent});

  /// Slot `sidebar`.
  final RaftSlotStyle sidebar;
  /// Slot `sidebarBody`.
  final RaftSlotStyle sidebarBody;
  /// Slot `sidebarContent`.
  final RaftSlotStyle sidebarContent;

  Map<String, RaftSlotStyle> get slots => {'sidebar': sidebar, 'sidebarBody': sidebarBody, 'sidebarContent': sidebarContent};
}

/// raft-ui recipe `activityInboxSidebar` (`src/components/activity-inbox/activity-inbox-sidebar.recipe.ts`, index.mjs:19748).
///
/// Used by: ActivityInboxSidebar.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftActivityInboxSidebarRecipe {
  static const String recipeName = 'activityInboxSidebar';
  static const List<String> slotNames = ['sidebar', 'sidebarBody', 'sidebarContent'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftActivityInboxSidebarRecipeStyle resolve({required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name], states, tokens);
    return RaftActivityInboxSidebarRecipeStyle(sidebar: s[0], sidebarBody: s[1], sidebarContent: s[2]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [3111, 2867, 2428, 2513, 907, 876],
    [856],
    [2672, 394, 393, 48, 50, 392, 395, 396, 49, 390, 397, 52, 54, 66, 69, 345, 347, 74, 67, 70, 72, 65, 73, 342],
    [2867, 2428, 2513, 3112, 991],
    [],
    [2672, 394, 393, 48, 50, 392, 395, 396, 49, 391, 53, 51, 66, 69, 346, 347, 74, 67, 71, 73, 68, 343, 344, 340, 341],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2], [3, 4, 5],
  ];
}
