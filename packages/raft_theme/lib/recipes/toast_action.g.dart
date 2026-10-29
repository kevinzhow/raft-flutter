// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `toastAction`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftToastActionRecipe].
class RaftToastActionRecipeStyle {
  const RaftToastActionRecipeStyle({
    required this.root,
    required this.content,
    required this.loadingIndicator,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `content`.
  final RaftSlotStyle content;

  /// Slot `loadingIndicator`.
  final RaftSlotStyle loadingIndicator;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'content': content,
    'loadingIndicator': loadingIndicator,
  };
}

/// raft-ui recipe `toastAction` (`src/components/toast/toast.tsx`, index.mjs:12901).
///
/// Used by: ToastAction.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftToastActionRecipe {
  static const String recipeName = 'toastAction';
  static const List<String> slotNames = ['root', 'content', 'loadingIndicator'];
  static const List<RaftRecipeAxis> axes = [];

  static RaftToastActionRecipeStyle resolve({
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
    return RaftToastActionRecipeStyle(
      root: s[0],
      content: s[1],
      loadingIndicator: s[2],
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
    [
      1682,
      1565,
      1305,
      1740,
      1319,
      1324,
      1933,
      1727,
      621,
      615,
      1592,
      1016,
      1813,
      1008,
      1829,
      1898,
      915,
      1900,
      442,
      435,
      441,
      461,
      450,
      423,
      1573,
      1578,
      1580,
      982,
      984,
      935,
      932,
      485,
      490,
      701,
      703,
      275,
      277,
      55,
      263,
    ],
    [1682, 1940, 1305, 1319, 1324, 1030, 702],
    [1630, 422, 1307, 1940, 965, 1319, 1324],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2],
  ];
}
