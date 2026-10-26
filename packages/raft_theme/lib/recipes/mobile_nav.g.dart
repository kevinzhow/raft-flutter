// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `mobileNav`.
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

/// raft-ui recipe `mobileNav` (`src/components/mobile-nav/mobile-nav.tsx`, index.mjs:4643).
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
      1039,
      1924,
      968,
      1048,
      504,
      1320,
      1018,
      639,
      634,
      596,
      1654,
      1640,
      1820,
      1609,
    ],
    [
      1678,
      1304,
      1736,
      1318,
      1573,
      935,
      933,
      277,
      1316,
      1481,
      967,
      1327,
      1028,
      621,
      1650,
      1639,
      1598,
      1015,
      1793,
      1016,
      1820,
      91,
      92,
      291,
      292,
      545,
      513,
      554,
      539,
      565,
      511,
      533,
      562,
      550,
      523,
      527,
      529,
      424,
      742,
      747,
      732,
      735,
      734,
      736,
      737,
      733,
      1706,
      995,
    ],
    [1481, 1893, 1422],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2],
  ];
}
