// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `heading`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `level` axis of `heading` (default `1`).
enum RaftHeadingRecipeLevel {
  v1('1'),
  v2('2'),
  v3('3'),
  v4('4'),
  v5('5'),
  v6('6');

  const RaftHeadingRecipeLevel(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// `variant` axis of `heading`.
enum RaftHeadingRecipeVariant {
  default_('default'),
  primary('primary'),
  information('information'),
  muted('muted'),
  placeholder('placeholder'),
  accent('accent'),
  success('success'),
  warning('warning'),
  danger('danger');

  const RaftHeadingRecipeVariant(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftHeadingRecipe].
class RaftHeadingRecipeStyle {
  const RaftHeadingRecipeStyle({required this.base});

  /// Slot `base`.
  final RaftSlotStyle base;

  Map<String, RaftSlotStyle> get slots => {'base': base};
}

/// raft-ui recipe `heading` (`dist/components/text/text.mjs`, index.mjs:15126).
///
/// Used by: TextHeading.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftHeadingRecipe {
  static const String recipeName = 'heading';
  static const List<String> slotNames = ['base'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('level', ['1', '2', '3', '4', '5', '6'], '1', false),
    RaftRecipeAxis(
      'variant',
      [
        'default',
        'primary',
        'information',
        'muted',
        'placeholder',
        'accent',
        'success',
        'warning',
        'danger',
      ],
      null,
      true,
    ),
  ];

  static RaftHeadingRecipeStyle resolve({
    RaftHeadingRecipeLevel? level,
    RaftHeadingRecipeVariant? variant,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [level?.css, variant?.css],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftHeadingRecipeStyle(base: s[0]);
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
    [1907, 1452, 1453, 2598, 2580, 2653, 1881],
    [1907, 1452, 1453, 2580, 2653, 1881, 2598],
    [1907, 1452, 1453, 2580, 2653, 1881, 2586],
    [1907, 1452, 1453, 2580, 2653, 1881, 2610],
    [1907, 1452, 1453, 2580, 2653, 1881, 2603],
    [1907, 1452, 1453, 2580, 2653, 1881, 2600],
    [1907, 1452, 1453, 2580, 2653, 1881, 2581],
    [1907, 1452, 1453, 2580, 2653, 1881, 2623],
    [1907, 1452, 1453, 2580, 2653, 1881, 2632],
    [1907, 1452, 1453, 2580, 2653, 1881, 2593],
    [1907, 1452, 1453, 2598, 2567, 2653, 1880],
    [1907, 1452, 1453, 2567, 2653, 1880, 2598],
    [1907, 1452, 1453, 2567, 2653, 1880, 2586],
    [1907, 1452, 1453, 2567, 2653, 1880, 2610],
    [1907, 1452, 1453, 2567, 2653, 1880, 2603],
    [1907, 1452, 1453, 2567, 2653, 1880, 2600],
    [1907, 1452, 1453, 2567, 2653, 1880, 2581],
    [1907, 1452, 1453, 2567, 2653, 1880, 2623],
    [1907, 1452, 1453, 2567, 2653, 1880, 2632],
    [1907, 1452, 1453, 2567, 2653, 1880, 2593],
    [1907, 1452, 1453, 2598, 2578, 2653, 1879],
    [1907, 1452, 1453, 2578, 2653, 1879, 2598],
    [1907, 1452, 1453, 2578, 2653, 1879, 2586],
    [1907, 1452, 1453, 2578, 2653, 1879, 2610],
    [1907, 1452, 1453, 2578, 2653, 1879, 2603],
    [1907, 1452, 1453, 2578, 2653, 1879, 2600],
    [1907, 1452, 1453, 2578, 2653, 1879, 2581],
    [1907, 1452, 1453, 2578, 2653, 1879, 2623],
    [1907, 1452, 1453, 2578, 2653, 1879, 2632],
    [1907, 1452, 1453, 2578, 2653, 1879, 2593],
    [1907, 1452, 1453, 2598, 2577, 2652, 1878],
    [1907, 1452, 1453, 2577, 2652, 1878, 2598],
    [1907, 1452, 1453, 2577, 2652, 1878, 2586],
    [1907, 1452, 1453, 2577, 2652, 1878, 2610],
    [1907, 1452, 1453, 2577, 2652, 1878, 2603],
    [1907, 1452, 1453, 2577, 2652, 1878, 2600],
    [1907, 1452, 1453, 2577, 2652, 1878, 2581],
    [1907, 1452, 1453, 2577, 2652, 1878, 2623],
    [1907, 1452, 1453, 2577, 2652, 1878, 2632],
    [1907, 1452, 1453, 2577, 2652, 1878, 2593],
    [1907, 1452, 1453, 2598, 2566, 1886],
    [1907, 1452, 1453, 2566, 1886, 2598],
    [1907, 1452, 1453, 2566, 1886, 2586],
    [1907, 1452, 1453, 2566, 1886, 2610],
    [1907, 1452, 1453, 2566, 1886, 2603],
    [1907, 1452, 1453, 2566, 1886, 2600],
    [1907, 1452, 1453, 2566, 1886, 2581],
    [1907, 1452, 1453, 2566, 1886, 2623],
    [1907, 1452, 1453, 2566, 1886, 2632],
    [1907, 1452, 1453, 2566, 1886, 2593],
    [1907, 1452, 1453, 2598, 2636, 1885],
    [1907, 1452, 1453, 2636, 1885, 2598],
    [1907, 1452, 1453, 2636, 1885, 2586],
    [1907, 1452, 1453, 2636, 1885, 2610],
    [1907, 1452, 1453, 2636, 1885, 2603],
    [1907, 1452, 1453, 2636, 1885, 2600],
    [1907, 1452, 1453, 2636, 1885, 2581],
    [1907, 1452, 1453, 2636, 1885, 2623],
    [1907, 1452, 1453, 2636, 1885, 2632],
    [1907, 1452, 1453, 2636, 1885, 2593],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0],
    [1],
    [2],
    [3],
    [4],
    [5],
    [6],
    [7],
    [8],
    [9],
    [10],
    [11],
    [12],
    [13],
    [14],
    [15],
    [16],
    [17],
    [18],
    [19],
    [20],
    [21],
    [22],
    [23],
    [24],
    [25],
    [26],
    [27],
    [28],
    [29],
    [30],
    [31],
    [32],
    [33],
    [34],
    [35],
    [36],
    [37],
    [38],
    [39],
    [40],
    [41],
    [42],
    [43],
    [44],
    [45],
    [46],
    [47],
    [48],
    [49],
    [50],
    [51],
    [52],
    [53],
    [54],
    [55],
    [56],
    [57],
    [58],
    [59],
  ];
}
