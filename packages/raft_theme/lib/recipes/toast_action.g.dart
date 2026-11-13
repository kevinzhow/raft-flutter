// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `toastAction`.
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

/// raft-ui recipe `toastAction` (`dist/components/toast/toast.mjs`, index.mjs:18837).
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
      2433,
      2235,
      1847,
      2499,
      1864,
      1869,
      2729,
      2483,
      940,
      933,
      2260,
      1456,
      2587,
      1449,
      2605,
      1338,
      2684,
      2200,
      723,
      711,
      717,
      751,
      729,
      692,
      2243,
      2248,
      2250,
      1424,
      1426,
      1360,
      1357,
      777,
      781,
      1039,
      1041,
      472,
      474,
      74,
      458,
    ],
    [2433, 2747, 1847, 1864, 1869, 1474, 1040],
    [2346, 691, 1849, 2747, 1400, 1864, 1869],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2],
  ];
}
