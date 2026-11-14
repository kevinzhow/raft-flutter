// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `webTopBar`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftWebTopBarRecipe].
class RaftWebTopBarRecipeStyle {
  const RaftWebTopBarRecipeStyle({
    required this.root,
    required this.start,
    required this.center,
    required this.end,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `start`.
  final RaftSlotStyle start;

  /// Slot `center`.
  final RaftSlotStyle center;

  /// Slot `end`.
  final RaftSlotStyle end;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'start': start,
    'center': center,
    'end': end,
  };
}

/// raft-ui recipe `webTopBar` (`dist/components/web-top-bar/web-top-bar.recipe.mjs`, index.mjs:29311).
///
/// Used by: WebTopBarCenter, WebTopBarEnd, WebTopBarRoot, WebTopBarStart.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftWebTopBarRecipe {
  static const String recipeName = 'webTopBar';
  static const List<String> slotNames = ['root', 'start', 'center', 'end'];
  static const List<RaftRecipeAxis> axes = [];

  static RaftWebTopBarRecipeStyle resolve({
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
    return RaftWebTopBarRecipeStyle(
      root: s[0],
      start: s[1],
      center: s[2],
      end: s[3],
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
    [1489, 1493, 1864, 1670, 2499, 942, 954, 913, 2604, 1458],
    [1400, 1864, 1873, 2293, 2375, 612],
    [1400, 2121, 1864, 1869],
    [1400, 1864, 1870, 2373, 2294, 266],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3],
  ];
}
