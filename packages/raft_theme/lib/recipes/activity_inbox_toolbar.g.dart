// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `activityInboxToolbar`.
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

/// raft-ui recipe `activityInboxToolbar` (`src/components/activity-inbox/activity-inbox-toolbar.recipe.ts`, index.mjs:16043).
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
    [965, 1740, 969, 1319, 1023, 595, 1662, 1673],
    [
      965,
      1470,
      1740,
      1319,
      1023,
      1381,
      1393,
      1450,
      1441,
      1464,
      623,
      633,
      595,
      1662,
      0,
      204,
    ],
    [1506, 1821, 1008, 1822],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2],
  ];
}
