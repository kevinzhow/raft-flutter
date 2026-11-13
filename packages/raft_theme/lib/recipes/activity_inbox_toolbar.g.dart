// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `activityInboxToolbar`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftActivityInboxToolbarRecipe].
class RaftActivityInboxToolbarRecipeStyle {
  const RaftActivityInboxToolbarRecipeStyle({
    required this.controls,
    required this.selectionToolbar,
    required this.selectionCount,
  });

  /// Slot `controls`.
  final RaftSlotStyle controls;

  /// Slot `selectionToolbar`.
  final RaftSlotStyle selectionToolbar;

  /// Slot `selectionCount`.
  final RaftSlotStyle selectionCount;

  Map<String, RaftSlotStyle> get slots => {
    'controls': controls,
    'selectionToolbar': selectionToolbar,
    'selectionCount': selectionCount,
  };
}

/// raft-ui recipe `activityInboxToolbar` (`dist/components/activity-inbox/activity-inbox-toolbar.recipe.mjs`, index.mjs:23793).
///
/// Used by: ActivityInboxControls, ActivityInboxSelectionCount, ActivityInboxSelectionToolbar.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftActivityInboxToolbarRecipe {
  static const String recipeName = 'activityInboxToolbar';
  static const List<String> slotNames = [
    'controls',
    'selectionToolbar',
    'selectionCount',
  ];
  static const List<RaftRecipeAxis> axes = [];

  static RaftActivityInboxToolbarRecipeStyle resolve({
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
    return RaftActivityInboxToolbarRecipeStyle(
      controls: s[0],
      selectionToolbar: s[1],
      selectionCount: s[2],
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
    [1400, 2499, 1406, 1864, 1466, 910, 2394, 2419, 2075],
    [
      1400,
      2100,
      2499,
      1408,
      1864,
      1466,
      2380,
      2279,
      2065,
      2058,
      942,
      953,
      910,
      2394,
      1,
      0,
    ],
    [2139, 2597, 1449, 2598],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2],
  ];
}
