// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `switchRecipe`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftSwitchRecipe].
class RaftSwitchRecipeStyle {
  const RaftSwitchRecipeStyle({required this.root, required this.thumb});

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `thumb`.
  final RaftSlotStyle thumb;

  Map<String, RaftSlotStyle> get slots => {'root': root, 'thumb': thumb};
}

/// raft-ui recipe `switchRecipe` (`dist/components/switch/switch.mjs`, index.mjs:9065).
///
/// Used by: Switch, SwitchThumb.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftSwitchRecipe {
  static const String recipeName = 'switchRecipe';
  static const List<String> slotNames = ['root', 'thumb'];
  static const List<RaftRecipeAxis> axes = [];

  static RaftSwitchRecipeStyle resolve({
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
    return RaftSwitchRecipeStyle(root: s[0], thumb: s[1]);
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
      1847,
      2499,
      2650,
      1864,
      2247,
      2659,
      1376,
      2138,
      2185,
      1181,
      723,
      713,
      719,
      729,
      1436,
      1438,
      1640,
      2692,
      2466,
      941,
      955,
      895,
      2267,
      1366,
      1156,
      1154,
      1162,
      1163,
      1435,
      1437,
      1439,
      1180,
      1178,
      1158,
      1157,
    ],
    [
      2346,
      937,
      2678,
      1376,
      2138,
      2534,
      2466,
      911,
      2491,
      1167,
      1368,
      1377,
      1155,
      1164,
      1178,
      1186,
      1157,
      1159,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1],
  ];
}
