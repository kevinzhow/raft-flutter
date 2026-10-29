// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `switchRecipe`.
// ignore_for_file: type=lint

import '../recipe_runtime.dart';
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

/// raft-ui recipe `switchRecipe` (`src/components/switch/switch.tsx`, index.mjs:7663).
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

  static RaftSwitchRecipeStyle resolve({
    required RaftRecipeTheme theme,
    RaftSwitchRecipeSize? size,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [theme.name, size?.css],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftSwitchRecipeStyle(root: s[0], thumb: s[1]);
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
      2804,
      2320,
      2902,
      3085,
      2331,
      2672,
      3105,
      1628,
      1637,
      2616,
      2637,
      1464,
      619,
      617,
      618,
      624,
      1436,
      1677,
      1683,
      1686,
      1687,
      878,
      916,
      830,
      2639,
      1443,
      1463,
      1460,
      1437,
      1962,
      3155,
      2700,
    ],
    [2739, 874, 3128, 1628, 1637, 2616, 835, 1462, 1207, 2912],
    [
      2804,
      2320,
      2902,
      3085,
      2331,
      2672,
      3105,
      1628,
      1637,
      2616,
      2637,
      1464,
      619,
      617,
      618,
      624,
      1436,
      1677,
      1683,
      1686,
      1687,
      878,
      916,
      830,
      2639,
      1443,
      1463,
      1460,
      1437,
      1963,
      3158,
      2700,
    ],
    [2739, 874, 3128, 1628, 1637, 2616, 835, 1462, 1208, 2914],
    [
      2804,
      2320,
      2902,
      3085,
      2331,
      2672,
      3105,
      1628,
      1637,
      2616,
      2637,
      1464,
      619,
      617,
      618,
      624,
      1436,
      1677,
      1683,
      1686,
      1687,
      2845,
      812,
      1138,
      2887,
      1162,
      2638,
      1140,
      1448,
      1060,
      1444,
      1461,
      1471,
      1064,
      1065,
      1438,
      1440,
      1055,
      1056,
      2636,
      2610,
      1962,
      3155,
      2691,
    ],
    [
      2739,
      874,
      3128,
      1628,
      1637,
      2616,
      2845,
      833,
      992,
      1052,
      2875,
      1459,
      1472,
      1063,
      1054,
      2913,
      1207,
    ],
    [
      2804,
      2320,
      2902,
      3085,
      2331,
      2672,
      3105,
      1628,
      1637,
      2616,
      2637,
      1464,
      619,
      617,
      618,
      624,
      1436,
      1677,
      1683,
      1686,
      1687,
      2845,
      812,
      1138,
      2887,
      1162,
      2638,
      1140,
      1448,
      1060,
      1444,
      1461,
      1471,
      1064,
      1065,
      1438,
      1440,
      1055,
      1056,
      2636,
      2610,
      1963,
      3158,
      2691,
    ],
    [
      2739,
      874,
      3128,
      1628,
      1637,
      2616,
      2845,
      833,
      992,
      1052,
      2875,
      1459,
      1472,
      1063,
      1054,
      2915,
      1208,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1],
    [2, 3],
    [4, 5],
    [6, 7],
  ];
}
