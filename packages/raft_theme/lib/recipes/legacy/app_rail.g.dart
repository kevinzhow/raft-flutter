// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `appRail`.
// ignore_for_file: type=lint

import '../recipe_runtime.dart';
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
    required this.itemAttentionMask,
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

  /// Slot `itemAttentionMask`.
  final RaftSlotStyle itemAttentionMask;

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
    'itemAttentionMask': itemAttentionMask,
    'itemLabel': itemLabel,
    'itemBadge': itemBadge,
    'itemIndicator': itemIndicator,
  };
}

/// raft-ui recipe `appRail` (`src/components/app-rail/app-rail.recipe.ts`, index.mjs:2144).
///
/// Used by: AppRailFooter, AppRailHeader, AppRailItem, AppRailItemAttentionMask, AppRailItemBadge, AppRailItemIcon, AppRailItemIndicator, AppRailItemLabel, AppRailNav, AppRailRoot.
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
    'itemAttentionMask',
    'itemLabel',
    'itemBadge',
    'itemIndicator',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftAppRailRecipeStyle resolve({
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
    return RaftAppRailRecipeStyle(
      root: s[0],
      header: s[1],
      nav: s[2],
      footer: s[3],
      item: s[4],
      itemIcon: s[5],
      itemAttentionMask: s[6],
      itemLabel: s[7],
      itemBadge: s[8],
      itemIndicator: s[9],
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
    [1644, 2925, 1646, 2331, 2868, 3144, 922, 892, 836, 3024, 2529],
    [2804, 1644, 3168, 2902, 2331, 2336, 1946, 891, 892, 565],
    [1644, 3168, 1645, 1646, 2331, 1722, 2794],
    [1644, 3168, 2902, 1646, 2331, 2336, 1722, 1978, 2706, 567],
    [
      2804,
      2320,
      2902,
      2331,
      2336,
      2672,
      1614,
      1611,
      430,
      425,
      2906,
      878,
      930,
      3024,
      3125,
      2260,
      2256,
      1338,
      1337,
      1346,
      1663,
      1672,
      1671,
      1666,
      2528,
    ],
    [2804, 2320, 2331, 2336],
    [2739, 586, 2322, 438, 425, 2189],
    [2942],
    [
      586,
      142,
      148,
      2320,
      2599,
      2331,
      2336,
      2777,
      2956,
      1709,
      2352,
      878,
      892,
      786,
      2994,
    ],
    [2739, 586, 142, 3083],
    [1644, 2925, 1646, 2331, 2868, 3143, 825],
    [2804, 1644, 3168, 2902, 2331, 2336, 1945, 890],
    [1644, 3168, 1645, 1646, 2331, 1722, 2794, 2779, 2764, 2706],
    [1644, 3168, 2902, 1646, 2331, 2336, 1978, 1722, 2779, 2706, 85],
    [
      2804,
      2320,
      2902,
      2331,
      2336,
      2672,
      1614,
      1611,
      425,
      2924,
      2605,
      2695,
      2848,
      876,
      930,
      2962,
      3015,
      429,
      2233,
      2299,
      593,
      613,
      1125,
      980,
      1339,
      1334,
      1045,
      1349,
      1345,
      1049,
      1048,
      1678,
      1691,
    ],
    [2739, 586, 2322, 438, 425, 2987, 1624, 2379, 559],
    [
      586,
      142,
      148,
      2320,
      2599,
      2331,
      2336,
      2845,
      877,
      838,
      3046,
      2777,
      1714,
      2956,
      1706,
      2363,
      2946,
      2634,
      3094,
      2822,
      2828,
    ],
    [2739, 586, 142, 3083, 1397],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
    [10, 11, 12, 13, 14, 5, 15, 7, 16, 17],
  ];
}
