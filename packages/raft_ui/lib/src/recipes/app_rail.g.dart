// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `appRail`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftAppRailRecipe].
class RaftAppRailRecipeStyle {
  const RaftAppRailRecipeStyle({required this.root, required this.header, required this.nav, required this.footer, required this.item, required this.itemIcon, required this.itemAttentionMask, required this.itemLabel, required this.itemBadge, required this.itemIndicator});

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

  Map<String, RaftSlotStyle> get slots => {'root': root, 'header': header, 'nav': nav, 'footer': footer, 'item': item, 'itemIcon': itemIcon, 'itemAttentionMask': itemAttentionMask, 'itemLabel': itemLabel, 'itemBadge': itemBadge, 'itemIndicator': itemIndicator};
}

/// raft-ui recipe `appRail` (`src/components/app-rail/app-rail.recipe.ts`, index.mjs:2133).
///
/// Used by: AppRailFooter, AppRailHeader, AppRailItem, AppRailItemAttentionMask, AppRailItemBadge, AppRailItemIcon, AppRailItemIndicator, AppRailItemLabel, AppRailNav, AppRailRoot.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftAppRailRecipe {
  static const String recipeName = 'appRail';
  static const List<String> slotNames = ['root', 'header', 'nav', 'footer', 'item', 'itemIcon', 'itemAttentionMask', 'itemLabel', 'itemBadge', 'itemIndicator'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftAppRailRecipeStyle resolve({required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name], states, tokens);
    return RaftAppRailRecipeStyle(root: s[0], header: s[1], nav: s[2], footer: s[3], item: s[4], itemIcon: s[5], itemAttentionMask: s[6], itemLabel: s[7], itemBadge: s[8], itemIndicator: s[9]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [1620, 2890, 1622, 2312, 2834, 3103, 907, 876, 831, 2987, 2508],
    [2775, 1620, 3127, 2867, 2312, 2317, 1944, 875, 876, 564],
    [1620, 3127, 1621, 1622, 2312, 1697, 2765],
    [1620, 3127, 2867, 1622, 2312, 2317, 1697, 1976, 2683, 566],
    [2775, 2301, 2867, 2312, 2317, 2649, 1590, 1587, 432, 427, 2871, 866, 916, 2987, 3084, 2241, 2237, 1316, 1315, 1324, 1639, 1648, 1647, 1642, 2507],
    [2775, 2301, 2312, 2317],
    [2716, 580, 2303, 440, 427, 2174],
    [2907],
    [580, 142, 148, 2301, 2576, 2312, 2317, 2749, 2918, 1684, 2333, 866, 876, 780, 2956],
    [2716, 580, 142, 3042],
    [1620, 2890, 1622, 2312, 2834, 3102, 820],
    [2775, 1620, 3127, 2867, 2312, 2317, 1943, 874],
    [1620, 3127, 1621, 1622, 2312, 1697, 2765, 2751, 2739, 2683],
    [1620, 3127, 2867, 1622, 2312, 2317, 1976, 1697, 2751, 2683, 85],
    [2775, 2301, 2867, 2312, 2317, 2649, 1590, 1587, 427, 2889, 2582, 2672, 2818, 864, 916, 2924, 2978, 431, 2214, 2280, 587, 607, 1105, 960, 1317, 1312, 1025, 1327, 1323, 1029, 1028, 1654, 1667],
    [2716, 580, 2303, 440, 427, 2949, 1600, 2360, 558],
    [580, 142, 148, 2301, 2576, 2312, 2317, 2815, 865, 833, 3010, 2749, 1689, 2918, 1681, 2344, 2911, 2612, 3053, 2792, 2798],
    [2716, 580, 142, 3042, 1375],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9], [10, 11, 12, 13, 14, 5, 15, 7, 16, 17],
  ];
}
