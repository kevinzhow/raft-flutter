// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `appRail`.
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

/// raft-ui recipe `appRail` (`dist/components/app-rail/app-rail.recipe.mjs`, index.mjs:3904).
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
    [1400, 2538, 1404, 1864, 2483, 2691, 956, 954, 913, 2604, 616],
    [2433, 1400, 2725, 2499, 1864, 1869, 1639, 942, 954, 609],
    [
      1400,
      2725,
      1401,
      1404,
      1864,
      2417,
      1465,
      2382,
      2275,
      1395,
      613,
      608,
      2038,
      2066,
      2036,
      745,
      733,
      742,
      758,
      752,
      729,
      732,
    ],
    [1400, 2725, 2499, 1404, 1864, 1869, 1673, 1465, 2275, 611, 2038, 2057],
    [
      2433,
      1847,
      2499,
      1864,
      1869,
      2247,
      1360,
      1358,
      474,
      2503,
      2463,
      941,
      963,
      2604,
      480,
      1784,
      696,
      1071,
      1070,
      1074,
      1075,
      1077,
      1439,
      615,
    ],
    [2433, 1847, 1864, 1869],
    [2539],
    [
      691,
      183,
      188,
      1847,
      1864,
      1869,
      1654,
      2119,
      2471,
      2399,
      885,
      2621,
      1853,
      1856,
      2446,
      2450,
      1454,
      2572,
      1449,
      1882,
      2556,
    ],
    [2346, 691, 188, 183],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8],
  ];
}
