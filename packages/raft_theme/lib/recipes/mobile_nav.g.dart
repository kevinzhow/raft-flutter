// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `mobileNav`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftMobileNavRecipe].
class RaftMobileNavRecipeStyle {
  const RaftMobileNavRecipeStyle({
    required this.root,
    required this.item,
    required this.itemLabel,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `item`.
  final RaftSlotStyle item;

  /// Slot `itemLabel`.
  final RaftSlotStyle itemLabel;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'item': item,
    'itemLabel': itemLabel,
  };
}

/// raft-ui recipe `mobileNav` (`dist/components/mobile-nav/mobile-nav.mjs`, index.mjs:6718).
///
/// Used by: MobileNavItem, MobileNavLabel, MobileNavRoot.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftMobileNavRecipe {
  static const String recipeName = 'mobileNav';
  static const List<String> slotNames = ['root', 'item', 'itemLabel'];
  static const List<RaftRecipeAxis> axes = [];

  static RaftMobileNavRecipeStyle resolve({
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
    return RaftMobileNavRecipeStyle(root: s[0], item: s[1], itemLabel: s[2]);
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
      1489,
      2725,
      1405,
      1501,
      797,
      1866,
      1462,
      960,
      954,
      911,
      2401,
      2380,
      2600,
      2289,
    ],
    [
      2433,
      1847,
      2499,
      1864,
      2247,
      1360,
      1358,
      474,
      1862,
      2116,
      1404,
      1873,
      1473,
      940,
      2397,
      2379,
      2272,
      1456,
      2573,
      1457,
      2600,
      162,
      165,
      489,
      490,
      849,
      810,
      860,
      843,
      871,
      808,
      835,
      868,
      855,
      822,
      826,
      828,
      693,
      1072,
      1076,
      1061,
      1066,
      1065,
      1067,
      1068,
      1062,
      2463,
      1439,
    ],
    [2116, 2681, 1980],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2],
  ];
}
