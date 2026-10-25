// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
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

/// raft-ui recipe `mobileNav` (`src/components/mobile-nav/mobile-nav.tsx`, index.mjs:5806).
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

  static RaftMobileNavRecipeStyle resolve({
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
    [1742, 3168, 1647, 1750, 679, 2334, 1719, 927, 892, 868, 2717, 2994],
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
      2597,
      1646,
      1720,
      877,
      922,
      916,
      2775,
      2794,
      2956,
      3097,
      2344,
      2999,
      2291,
      595,
      1348,
      1336,
      1345,
      1663,
      1672,
      1671,
      1666,
    ],
    [2597, 3133],
    [
      1644,
      3167,
      2505,
      1647,
      2870,
      2331,
      1723,
      2845,
      830,
      2692,
      2895,
      2623,
      2517,
    ],
    [
      2320,
      2902,
      2331,
      2336,
      2672,
      1614,
      1611,
      430,
      425,
      2804,
      2907,
      2597,
      1719,
      2845,
      877,
      2690,
      3021,
      126,
      127,
      2298,
      592,
      1335,
      1350,
      1347,
      1340,
      1341,
      1044,
      1047,
      1331,
      1327,
      1330,
      1333,
      1332,
      1328,
      1329,
      1043,
    ],
    [2597, 3133, 2942],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2],
    [3, 4, 5],
  ];
}
