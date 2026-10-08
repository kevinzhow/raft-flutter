// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `activityInboxShell`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftActivityInboxShellRecipe].
class RaftActivityInboxShellRecipeStyle {
  const RaftActivityInboxShellRecipeStyle({required this.panel, required this.viewport, required this.loadingMore});

  /// Slot `panel`.
  final RaftSlotStyle panel;
  /// Slot `viewport`.
  final RaftSlotStyle viewport;
  /// Slot `loadingMore`.
  final RaftSlotStyle loadingMore;

  Map<String, RaftSlotStyle> get slots => {'panel': panel, 'viewport': viewport, 'loadingMore': loadingMore};
}

/// raft-ui recipe `activityInboxShell` (`src/components/activity-inbox/activity-inbox-shell.recipe.ts`, index.mjs:19696).
///
/// Used by: ActivityInboxLoadingMore, ActivityInboxPanel, ActivityInboxViewport.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftActivityInboxShellRecipe {
  static const String recipeName = 'activityInboxShell';
  static const List<String> slotNames = ['panel', 'viewport', 'loadingMore'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftActivityInboxShellRecipeStyle resolve({required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name], states, tokens);
    return RaftActivityInboxShellRecipeStyle(panel: s[0], viewport: s[1], loadingMore: s[2]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [1620, 1978, 2560, 1621, 1622, 2656, 856, 2956],
    [2775, 1621, 2661, 856, 2672, 2693],
    [2767, 2970, 3032, 1684, 2959],
    [1620, 1978, 2560, 1621, 1622, 2656, 820, 2976, 2497],
    [2775, 1621, 2661, 825, 1002, 2758, 2691, 2440, 2443],
    [2767, 2970, 3032, 1688, 2984],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2], [3, 4, 5],
  ];
}
