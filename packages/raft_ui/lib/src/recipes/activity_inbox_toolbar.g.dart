// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `activityInboxToolbar`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftActivityInboxToolbarRecipe].
class RaftActivityInboxToolbarRecipeStyle {
  const RaftActivityInboxToolbarRecipeStyle({required this.controls, required this.selectionToolbar, required this.selectionCount});

  /// Slot `controls`.
  final RaftSlotStyle controls;
  /// Slot `selectionToolbar`.
  final RaftSlotStyle selectionToolbar;
  /// Slot `selectionCount`.
  final RaftSlotStyle selectionCount;

  Map<String, RaftSlotStyle> get slots => {'controls': controls, 'selectionToolbar': selectionToolbar, 'selectionCount': selectionCount};
}

/// raft-ui recipe `activityInboxToolbar` (`src/components/activity-inbox/activity-inbox-toolbar.recipe.ts`, index.mjs:19810).
///
/// Used by: ActivityInboxControls, ActivityInboxSelectionCount, ActivityInboxSelectionToolbar.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftActivityInboxToolbarRecipe {
  static const String recipeName = 'activityInboxToolbar';
  static const List<String> slotNames = ['controls', 'selectionToolbar', 'selectionCount'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftActivityInboxToolbarRecipeStyle resolve({required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name], states, tokens);
    return RaftActivityInboxToolbarRecipeStyle(controls: s[0], selectionToolbar: s[1], selectionCount: s[2]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [1620, 2867, 1624, 2312, 1698, 2753, 2766, 875, 876, 856],
    [1620, 2561, 2867, 2312, 1698, 2753, 2406, 2453, 2526, 2516, 2551, 875, 876, 766, 2704, 0, 1, 333, 2, 338, 3, 335, 334, 336],
    [2594, 3032, 1683, 2956],
    [1620, 2867, 1624, 2312, 1698, 2766, 873, 895, 825, 1008, 1002, 2758, 2440, 2443, 2554, 2502, 2503, 2504, 2501, 2500],
    [1620, 2561, 2867, 2312, 1698, 2753, 2406, 2453, 2526, 2516, 2551, 2726, 2705, 2443, 2441, 339, 334, 337],
    [2594, 3032, 1688, 2987],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2], [3, 4, 5],
  ];
}
