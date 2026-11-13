// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `activityInboxShell`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftActivityInboxShellRecipe].
class RaftActivityInboxShellRecipeStyle {
  const RaftActivityInboxShellRecipeStyle({
    required this.panel,
    required this.frame,
    required this.viewport,
    required this.loadingMore,
  });

  /// Slot `panel`.
  final RaftSlotStyle panel;

  /// Slot `frame`.
  final RaftSlotStyle frame;

  /// Slot `viewport`.
  final RaftSlotStyle viewport;

  /// Slot `loadingMore`.
  final RaftSlotStyle loadingMore;

  Map<String, RaftSlotStyle> get slots => {
    'panel': panel,
    'frame': frame,
    'viewport': viewport,
    'loadingMore': loadingMore,
  };
}

/// raft-ui recipe `activityInboxShell` (`dist/components/activity-inbox/activity-inbox-shell.recipe.mjs`, index.mjs:23691).
///
/// Used by: ActivityInboxLoadingMore, ActivityInboxPanel, ActivityInboxViewport.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftActivityInboxShellRecipe {
  static const String recipeName = 'activityInboxShell';
  static const List<String> slotNames = [
    'panel',
    'frame',
    'viewport',
    'loadingMore',
  ];
  static const List<RaftRecipeAxis> axes = [];

  static RaftActivityInboxShellRecipeStyle resolve({
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
    return RaftActivityInboxShellRecipeStyle(
      panel: s[0],
      frame: s[1],
      viewport: s[2],
      loadingMore: s[3],
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
    [1400, 1678, 2098, 1401, 1404, 2252, 910, 1456, 2598, 508, 2018],
    [2098, 1401],
    [
      2433,
      1400,
      2098,
      1401,
      1404,
      1463,
      163,
      2247,
      1439,
      910,
      2397,
      2381,
      2283,
    ],
    [2419, 2590, 2588, 2600],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3],
  ];
}
