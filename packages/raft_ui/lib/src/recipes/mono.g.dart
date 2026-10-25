// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `mono`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `size` axis of `mono` (default `code`).
enum RaftMonoRecipeSize {
  code('code'),
  meta('meta'),
  eyebrow('eyebrow'),
  tabular('tabular');

  const RaftMonoRecipeSize(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// `variant` axis of `mono`.
enum RaftMonoRecipeVariant {
  default_('default'),
  primary('primary'),
  information('information'),
  muted('muted'),
  placeholder('placeholder'),
  accent('accent'),
  success('success'),
  warning('warning'),
  danger('danger');

  const RaftMonoRecipeVariant(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftMonoRecipe].
class RaftMonoRecipeStyle {
  const RaftMonoRecipeStyle({required this.base});

  /// Slot `base`.
  final RaftSlotStyle base;

  Map<String, RaftSlotStyle> get slots => {'base': base};
}

/// raft-ui recipe `mono` (`src/components/text/text.tsx`, index.mjs:12415).
///
/// Used by: TextMono.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftMonoRecipe {
  static const String recipeName = 'mono';
  static const List<String> slotNames = ['base'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis(
      'size',
      ['code', 'meta', 'eyebrow', 'tabular'],
      'code',
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

  static RaftMonoRecipeStyle resolve({
    RaftMonoRecipeSize? size,
    RaftMonoRecipeVariant? variant,
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
    return RaftMonoRecipeStyle(base: s[0]);
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
    [2378, 1714, 1715, 3053, 2354, 3024],
    [2378, 1714, 1715, 3053, 2354, 3013],
    [2378, 1714, 1715, 3053, 2354, 3044],
    [2378, 1714, 1715, 3053, 2354, 3036],
    [2378, 1714, 1715, 3053, 2354, 3018],
    [2378, 1714, 1715, 3053, 2354, 3021],
    [2378, 1714, 1715, 3053, 2354, 2989],
    [2378, 1714, 1715, 3053, 2354, 3055],
    [2378, 1714, 1715, 3053, 2354, 3064],
    [2378, 1714, 1715, 3053, 2354, 3009],
    [2378, 1714, 1715, 3073, 2352, 3018],
    [2378, 1714, 1715, 3073, 2352, 3013],
    [2378, 1714, 1715, 3073, 2352, 3044],
    [2378, 1714, 1715, 3073, 2352, 3036],
    [2378, 1714, 1715, 3073, 2352, 3021],
    [2378, 1714, 1715, 3073, 2352, 2989],
    [2378, 1714, 1715, 3073, 2352, 3055],
    [2378, 1714, 1715, 3073, 2352, 3064],
    [2378, 1714, 1715, 3073, 2352, 3009],
    [2378, 1714, 2956, 1713, 3137, 3096, 2363, 3021],
    [2378, 1714, 2956, 1713, 3137, 3096, 2363, 3013],
    [2378, 1714, 2956, 1713, 3137, 3096, 2363, 3044],
    [2378, 1714, 2956, 1713, 3137, 3096, 2363, 3036],
    [2378, 1714, 2956, 1713, 3137, 3096, 2363, 3018],
    [2378, 1714, 2956, 1713, 3137, 3096, 2363, 2989],
    [2378, 1714, 2956, 1713, 3137, 3096, 2363, 3055],
    [2378, 1714, 2956, 1713, 3137, 3096, 2363, 3064],
    [2378, 1714, 2956, 1713, 3137, 3096, 2363, 3009],
    [2378, 1714, 1715, 3053, 2946, 2354, 3024],
    [2378, 1714, 1715, 3053, 2946, 2354, 3013],
    [2378, 1714, 1715, 3053, 2946, 2354, 3044],
    [2378, 1714, 1715, 3053, 2946, 2354, 3036],
    [2378, 1714, 1715, 3053, 2946, 2354, 3018],
    [2378, 1714, 1715, 3053, 2946, 2354, 3021],
    [2378, 1714, 1715, 3053, 2946, 2354, 2989],
    [2378, 1714, 1715, 3053, 2946, 2354, 3055],
    [2378, 1714, 1715, 3053, 2946, 2354, 3064],
    [2378, 1714, 1715, 3053, 2946, 2354, 3009],
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
    [10],
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
    [19],
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
  ];
}
