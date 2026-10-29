// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `activityInboxShell`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftActivityInboxShellRecipe].
class RaftActivityInboxShellRecipeStyle {
  const RaftActivityInboxShellRecipeStyle({
    required this.panel,
    required this.viewport,
    required this.loadingMore,
  });

  /// Slot `panel`.
  final RaftSlotStyle panel;

  /// Slot `viewport`.
  final RaftSlotStyle viewport;

  /// Slot `loadingMore`.
  final RaftSlotStyle loadingMore;

  Map<String, RaftSlotStyle> get slots => {
    'panel': panel,
    'viewport': viewport,
    'loadingMore': loadingMore,
  };
}

/// raft-ui recipe `activityInboxShell` (`src/components/activity-inbox/activity-inbox-shell.recipe.ts`, index.mjs:15968).
///
/// Used by: ActivityInboxLoadingMore, ActivityInboxPanel, ActivityInboxViewport.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftActivityInboxShellRecipe {
  static const String recipeName = 'activityInboxShell';
  static const List<String> slotNames = ['panel', 'viewport', 'loadingMore'];
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
      viewport: s[1],
      loadingMore: s[2],
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
    [965, 1198, 1468, 966, 967, 1583, 595, 1016, 1822],
    [1682, 966, 1587, 595, 1592, 1612],
    [1673, 1816, 1814, 1824],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2],
  ];
}
