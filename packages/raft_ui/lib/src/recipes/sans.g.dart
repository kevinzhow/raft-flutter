// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `sans`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `size` axis of `sans` (default `body`).
enum RaftSansRecipeSize {
  large('large'),
  body('body'),
  small('small'),
  caption('caption');

  const RaftSansRecipeSize(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// `variant` axis of `sans`.
enum RaftSansRecipeVariant {
  default_('default'),
  primary('primary'),
  information('information'),
  muted('muted'),
  placeholder('placeholder'),
  accent('accent'),
  success('success'),
  warning('warning'),
  danger('danger');

  const RaftSansRecipeVariant(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftSansRecipe].
class RaftSansRecipeStyle {
  const RaftSansRecipeStyle({required this.base});

  /// Slot `base`.
  final RaftSlotStyle base;

  Map<String, RaftSlotStyle> get slots => {'base': base};
}

/// raft-ui recipe `sans` (`src/components/text/text.tsx`, index.mjs:12402).
///
/// Used by: TextSans.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftSansRecipe {
  static const String recipeName = 'sans';
  static const List<String> slotNames = ['base'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis(
      'size',
      ['large', 'body', 'small', 'caption'],
      'body',
      false,
    ),
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

  static RaftSansRecipeStyle resolve({
    RaftSansRecipeSize? size,
    RaftSansRecipeVariant? variant,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [size?.css, variant?.css],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftSansRecipeStyle(base: s[0]);
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
    [2378, 1716, 1715, 3041, 2357, 3024],
    [2378, 1716, 1715, 3041, 2357, 3013],
    [2378, 1716, 1715, 3041, 2357, 3044],
    [2378, 1716, 1715, 3041, 2357, 3036],
    [2378, 1716, 1715, 3041, 2357, 3018],
    [2378, 1716, 1715, 3041, 2357, 3021],
    [2378, 1716, 1715, 3041, 2357, 2989],
    [2378, 1716, 1715, 3041, 2357, 3055],
    [2378, 1716, 1715, 3041, 2357, 3064],
    [2378, 1716, 1715, 3041, 2357, 3009],
    [2378, 1716, 1715, 2993, 2356, 3024],
    [2378, 1716, 1715, 2993, 2356, 3013],
    [2378, 1716, 1715, 2993, 2356, 3044],
    [2378, 1716, 1715, 2993, 2356, 3036],
    [2378, 1716, 1715, 2993, 2356, 3018],
    [2378, 1716, 1715, 2993, 2356, 3021],
    [2378, 1716, 1715, 2993, 2356, 2989],
    [2378, 1716, 1715, 2993, 2356, 3055],
    [2378, 1716, 1715, 2993, 2356, 3064],
    [2378, 1716, 1715, 2993, 2356, 3009],
    [2378, 1716, 1715, 3053, 2354, 3018],
    [2378, 1716, 1715, 3053, 2354, 3013],
    [2378, 1716, 1715, 3053, 2354, 3044],
    [2378, 1716, 1715, 3053, 2354, 3036],
    [2378, 1716, 1715, 3053, 2354, 3021],
    [2378, 1716, 1715, 3053, 2354, 2989],
    [2378, 1716, 1715, 3053, 2354, 3055],
    [2378, 1716, 1715, 3053, 2354, 3064],
    [2378, 1716, 1715, 3053, 2354, 3009],
    [2378, 1716, 1715, 3073, 2352, 3018],
    [2378, 1716, 1715, 3073, 2352, 3013],
    [2378, 1716, 1715, 3073, 2352, 3044],
    [2378, 1716, 1715, 3073, 2352, 3036],
    [2378, 1716, 1715, 3073, 2352, 3021],
    [2378, 1716, 1715, 3073, 2352, 2989],
    [2378, 1716, 1715, 3073, 2352, 3055],
    [2378, 1716, 1715, 3073, 2352, 3064],
    [2378, 1716, 1715, 3073, 2352, 3009],
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
    [20],
    [24],
    [25],
    [26],
    [27],
    [28],
    [29],
    [30],
    [31],
    [32],
    [29],
    [33],
    [34],
    [35],
    [36],
    [37],
  ];
}
