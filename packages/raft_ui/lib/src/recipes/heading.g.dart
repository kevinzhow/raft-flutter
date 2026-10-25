// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `heading`.
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

/// raft-ui recipe `heading` (`src/components/text/text.tsx`, index.mjs:12387).
///
/// Used by: MarkdownHeading, PanelHeading, TaskBoardColumnHeading, TaskSectionHeading, TextHeading.
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
    [2378, 1712, 1713, 3013, 2968, 3088, 2349],
    [2378, 1712, 1713, 2968, 3088, 2349, 3013],
    [2378, 1712, 1713, 2968, 3088, 2349, 3044],
    [2378, 1712, 1713, 2968, 3088, 2349, 3036],
    [2378, 1712, 1713, 2968, 3088, 2349, 3018],
    [2378, 1712, 1713, 2968, 3088, 2349, 3021],
    [2378, 1712, 1713, 2968, 3088, 2349, 2989],
    [2378, 1712, 1713, 2968, 3088, 2349, 3055],
    [2378, 1712, 1713, 2968, 3088, 2349, 3064],
    [2378, 1712, 1713, 2968, 3088, 2349, 3009],
    [2378, 1712, 1713, 3013, 2952, 3088, 2348],
    [2378, 1712, 1713, 2952, 3088, 2348, 3013],
    [2378, 1712, 1713, 2952, 3088, 2348, 3044],
    [2378, 1712, 1713, 2952, 3088, 2348, 3036],
    [2378, 1712, 1713, 2952, 3088, 2348, 3018],
    [2378, 1712, 1713, 2952, 3088, 2348, 3021],
    [2378, 1712, 1713, 2952, 3088, 2348, 2989],
    [2378, 1712, 1713, 2952, 3088, 2348, 3055],
    [2378, 1712, 1713, 2952, 3088, 2348, 3064],
    [2378, 1712, 1713, 2952, 3088, 2348, 3009],
    [2378, 1712, 1713, 3013, 2966, 3088, 2347],
    [2378, 1712, 1713, 2966, 3088, 2347, 3013],
    [2378, 1712, 1713, 2966, 3088, 2347, 3044],
    [2378, 1712, 1713, 2966, 3088, 2347, 3036],
    [2378, 1712, 1713, 2966, 3088, 2347, 3018],
    [2378, 1712, 1713, 2966, 3088, 2347, 3021],
    [2378, 1712, 1713, 2966, 3088, 2347, 2989],
    [2378, 1712, 1713, 2966, 3088, 2347, 3055],
    [2378, 1712, 1713, 2966, 3088, 2347, 3064],
    [2378, 1712, 1713, 2966, 3088, 2347, 3009],
    [2378, 1712, 1713, 3013, 2965, 3087, 2346],
    [2378, 1712, 1713, 2965, 3087, 2346, 3013],
    [2378, 1712, 1713, 2965, 3087, 2346, 3044],
    [2378, 1712, 1713, 2965, 3087, 2346, 3036],
    [2378, 1712, 1713, 2965, 3087, 2346, 3018],
    [2378, 1712, 1713, 2965, 3087, 2346, 3021],
    [2378, 1712, 1713, 2965, 3087, 2346, 2989],
    [2378, 1712, 1713, 2965, 3087, 2346, 3055],
    [2378, 1712, 1713, 2965, 3087, 2346, 3064],
    [2378, 1712, 1713, 2965, 3087, 2346, 3009],
    [2378, 1712, 1713, 3013, 2951, 2358],
    [2378, 1712, 1713, 2951, 2358, 3013],
    [2378, 1712, 1713, 2951, 2358, 3044],
    [2378, 1712, 1713, 2951, 2358, 3036],
    [2378, 1712, 1713, 2951, 2358, 3018],
    [2378, 1712, 1713, 2951, 2358, 3021],
    [2378, 1712, 1713, 2951, 2358, 2989],
    [2378, 1712, 1713, 2951, 2358, 3055],
    [2378, 1712, 1713, 2951, 2358, 3064],
    [2378, 1712, 1713, 2951, 2358, 3009],
    [2378, 1712, 1713, 3013, 3072, 2357],
    [2378, 1712, 1713, 3072, 2357, 3013],
    [2378, 1712, 1713, 3072, 2357, 3044],
    [2378, 1712, 1713, 3072, 2357, 3036],
    [2378, 1712, 1713, 3072, 2357, 3018],
    [2378, 1712, 1713, 3072, 2357, 3021],
    [2378, 1712, 1713, 3072, 2357, 2989],
    [2378, 1712, 1713, 3072, 2357, 3055],
    [2378, 1712, 1713, 3072, 2357, 3064],
    [2378, 1712, 1713, 3072, 2357, 3009],
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
