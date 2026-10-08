// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `mobileNav`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftMobileNavRecipe].
class RaftMobileNavRecipeStyle {
  const RaftMobileNavRecipeStyle({required this.root, required this.item, required this.itemLabel});

  /// Slot `root`.
  final RaftSlotStyle root;
  /// Slot `item`.
  final RaftSlotStyle item;
  /// Slot `itemLabel`.
  final RaftSlotStyle itemLabel;

  Map<String, RaftSlotStyle> get slots => {'root': root, 'item': item, 'itemLabel': itemLabel};
}

/// raft-ui recipe `mobileNav` (`src/components/mobile-nav/mobile-nav.tsx`, index.mjs:5794).
///
/// Used by: MobileNavItem, MobileNavLabel, MobileNavRoot.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftMobileNavRecipe {
  static const String recipeName = 'mobileNav';
  static const List<String> slotNames = ['root', 'item', 'itemLabel'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftMobileNavRecipeStyle resolve({required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name], states, tokens);
    return RaftMobileNavRecipeStyle(root: s[0], item: s[1], itemLabel: s[2]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [1717, 3127, 1623, 1725, 673, 2315, 1694, 913, 876, 856, 2694, 2956],
    [2775, 2301, 2867, 2312, 2317, 2649, 1590, 1587, 432, 427, 2574, 1622, 1695, 865, 907, 900, 2747, 2765, 2918, 3056, 2325, 2962, 2272, 589, 1326, 1314, 1323, 1639, 1648, 1647, 1642],
    [2574, 3092],
    [1620, 3126, 2484, 1623, 2836, 2312, 1698, 2815, 825, 2669, 2861, 2600, 2496],
    [2301, 2867, 2312, 2317, 2649, 1590, 1587, 432, 427, 2775, 2872, 2574, 1694, 2815, 865, 2667, 2984, 126, 127, 2279, 586, 1313, 1328, 1325, 1318, 1319, 1024, 1027, 1309, 1305, 1308, 1311, 1310, 1306, 1307, 1023],
    [2574, 3092, 2907],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2], [3, 4, 5],
  ];
}
