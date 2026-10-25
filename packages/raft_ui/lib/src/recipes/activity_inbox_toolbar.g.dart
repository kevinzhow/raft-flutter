// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
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

/// raft-ui recipe `activityInboxToolbar` (`src/components/activity-inbox/activity-inbox-toolbar.recipe.ts`, index.mjs:19959).
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
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftActivityInboxToolbarRecipeStyle resolve({
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
    [1644, 2902, 1648, 2331, 1723, 2781, 2795, 891, 892, 868],
    [
      1644,
      2584,
      2902,
      2331,
      1723,
      2781,
      2427,
      2473,
      2549,
      2538,
      2574,
      891,
      892,
      772,
      2727,
      0,
      1,
      331,
      2,
      336,
      3,
      333,
      332,
      334,
    ],
    [2617, 3073, 1708, 2994],
    [
      1644,
      2902,
      1648,
      2331,
      1723,
      2795,
      889,
      911,
      830,
      1028,
      1022,
      2786,
      2460,
      2463,
      2577,
      2523,
      2524,
      2525,
      2522,
      2521,
    ],
    [
      1644,
      2584,
      2902,
      2331,
      1723,
      2781,
      2427,
      2473,
      2549,
      2538,
      2574,
      2751,
      2728,
      2463,
      2461,
      337,
      332,
      335,
    ],
    [2617, 3073, 1713, 3024],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2],
    [3, 4, 5],
  ];
}
