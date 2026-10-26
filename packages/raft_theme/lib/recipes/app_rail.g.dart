// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `appRail`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftAppRailRecipe].
class RaftAppRailRecipeStyle {
  const RaftAppRailRecipeStyle({
    required this.root,
    required this.header,
    required this.nav,
    required this.footer,
    required this.item,
    required this.itemIcon,
    required this.itemLabel,
    required this.itemBadge,
    required this.itemIndicator,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `header`.
  final RaftSlotStyle header;

  /// Slot `nav`.
  final RaftSlotStyle nav;

  /// Slot `footer`.
  final RaftSlotStyle footer;

  /// Slot `item`.
  final RaftSlotStyle item;

  /// Slot `itemIcon`.
  final RaftSlotStyle itemIcon;

  /// Slot `itemLabel`.
  final RaftSlotStyle itemLabel;

  /// Slot `itemBadge`.
  final RaftSlotStyle itemBadge;

  /// Slot `itemIndicator`.
  final RaftSlotStyle itemIndicator;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'header': header,
    'nav': nav,
    'footer': footer,
    'item': item,
    'itemIcon': itemIcon,
    'itemLabel': itemLabel,
    'itemBadge': itemBadge,
    'itemIndicator': itemIndicator,
  };
}

/// raft-ui recipe `appRail` (`src/components/app-rail/app-rail.recipe.ts`, index.mjs:2080).
///
/// Used by: AppRailFooter, AppRailHeader, AppRailItem, AppRailItemBadge, AppRailItemIcon, AppRailItemIndicator, AppRailItemLabel, AppRailNav, AppRailRoot.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftAppRailRecipe {
  static const String recipeName = 'appRail';
  static const List<String> slotNames = [
    'root',
    'header',
    'nav',
    'footer',
    'item',
    'itemIcon',
    'itemLabel',
    'itemBadge',
    'itemIndicator',
  ];
  static const List<RaftRecipeAxis> axes = [];

  static RaftAppRailRecipeStyle resolve({
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
    return RaftAppRailRecipeStyle(
      root: s[0],
      header: s[1],
      nav: s[2],
      footer: s[3],
      item: s[4],
      itemIcon: s[5],
      itemLabel: s[6],
      itemBadge: s[7],
      itemIndicator: s[8],
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
    [965, 1766, 967, 1318, 1723, 1917, 636, 634, 600, 1824, 393],
    [1678, 965, 1924, 1736, 1318, 1323, 1167, 623, 634, 385],
    [965, 1924, 966, 967, 1318, 1667, 1021, 1642, 1602, 960, 388, 384],
    [965, 1924, 1736, 967, 1318, 1323, 1195, 1021, 1602, 387],
    [
      1678,
      1304,
      1736,
      1318,
      1323,
      1573,
      935,
      933,
      277,
      1742,
      1706,
      622,
      641,
      1824,
      282,
      1270,
      426,
      741,
      740,
      745,
      746,
      748,
      995,
      392,
    ],
    [1678, 1304, 1318, 1323],
    [1777],
    [
      422,
      102,
      105,
      1304,
      1318,
      1323,
      1181,
      1485,
      1712,
      1652,
      571,
      1840,
      1309,
      1312,
      1691,
      1695,
      1013,
      1792,
      1007,
      1335,
      1779,
    ],
    [1626, 422, 105, 102],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8],
  ];
}
