// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `switchRecipe`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `size` axis of `switchRecipe` (default `sm`).
enum RaftSwitchRecipeSize {
  sm('sm'),
  md('md');

  const RaftSwitchRecipeSize(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftSwitchRecipe].
class RaftSwitchRecipeStyle {
  const RaftSwitchRecipeStyle({required this.root, required this.thumb});

  /// Slot `root`.
  final RaftSlotStyle root;
  /// Slot `thumb`.
  final RaftSlotStyle thumb;

  Map<String, RaftSlotStyle> get slots => {'root': root, 'thumb': thumb};
}

/// raft-ui recipe `switchRecipe` (`src/components/switch/switch.tsx`, index.mjs:7646).
///
/// Used by: Switch, SwitchThumb.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftSwitchRecipe {
  static const String recipeName = 'switchRecipe';
  static const List<String> slotNames = ['root', 'thumb'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
    RaftRecipeAxis('size', ['sm', 'md'], 'sm', false),
  ];

  static RaftSwitchRecipeStyle resolve({required RaftRecipeTheme theme, RaftSwitchRecipeSize? size, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name, size?.css], states, tokens);
    return RaftSwitchRecipeStyle(root: s[0], thumb: s[1]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [2775, 2301, 2867, 3044, 2312, 2649, 3064, 1604, 1613, 2593, 2615, 1442, 613, 611, 612, 618, 1414, 1653, 1659, 1662, 1663, 866, 900, 825, 2617, 1421, 1441, 1438, 1415, 1960, 3114, 2677],
    [2716, 862, 3087, 1604, 1613, 2593, 830, 1440, 1188, 2877],
    [2775, 2301, 2867, 3044, 2312, 2649, 3064, 1604, 1613, 2593, 2615, 1442, 613, 611, 612, 618, 1414, 1653, 1659, 1662, 1663, 866, 900, 825, 2617, 1421, 1441, 1438, 1415, 1961, 3117, 2677],
    [2716, 862, 3087, 1604, 1613, 2593, 830, 1440, 1189, 2879],
    [2775, 2301, 2867, 3044, 2312, 2649, 3064, 1604, 1613, 2593, 2615, 1442, 613, 611, 612, 618, 1414, 1653, 1659, 1662, 1663, 2815, 806, 1119, 2853, 1143, 2616, 1121, 1426, 1040, 1422, 1439, 1449, 1044, 1045, 1416, 1418, 1035, 1036, 2614, 2587, 1960, 3114, 2668],
    [2716, 862, 3087, 1604, 1613, 2593, 2815, 828, 972, 1032, 2841, 1437, 1450, 1043, 1034, 2878, 1188],
    [2775, 2301, 2867, 3044, 2312, 2649, 3064, 1604, 1613, 2593, 2615, 1442, 613, 611, 612, 618, 1414, 1653, 1659, 1662, 1663, 2815, 806, 1119, 2853, 1143, 2616, 1121, 1426, 1040, 1422, 1439, 1449, 1044, 1045, 1416, 1418, 1035, 1036, 2614, 2587, 1961, 3117, 2668],
    [2716, 862, 3087, 1604, 1613, 2593, 2815, 828, 972, 1032, 2841, 1437, 1450, 1043, 1034, 2880, 1189],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1], [2, 3], [4, 5], [6, 7],
  ];
}
