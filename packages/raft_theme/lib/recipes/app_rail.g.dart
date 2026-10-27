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
    [965, 1768, 967, 1319, 1725, 1919, 636, 634, 600, 1826, 393],
    [1680, 965, 1926, 1738, 1319, 1324, 1168, 623, 634, 385],
    [965, 1926, 966, 967, 1319, 1669, 1022, 1644, 1604, 960, 388, 384],
    [965, 1926, 1738, 967, 1319, 1324, 1196, 1022, 1604, 387],
    [
      1680,
      1305,
      1738,
      1319,
      1324,
      1575,
      935,
      933,
      277,
      1744,
      1708,
      622,
      641,
      1826,
      282,
      1271,
      426,
      741,
      740,
      745,
      746,
      748,
      996,
      392,
    ],
    [1680, 1305, 1319, 1324],
    [1779],
    [
      422,
      102,
      105,
      1305,
      1319,
      1324,
      1182,
      1487,
      1714,
      1654,
      571,
      1842,
      1310,
      1313,
      1693,
      1697,
      1014,
      1794,
      1008,
      1336,
      1781,
    ],
    [1628, 422, 105, 102],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8],
  ];
}
