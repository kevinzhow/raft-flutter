// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `mono`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `size` axis of `mono` (default `code`).
enum RaftMonoRecipeSize {
  code('code'),
  meta('meta'),
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

/// raft-ui recipe `mono` (`dist/components/text/text.mjs`, index.mjs:15155).
///
/// Used by: TextMono.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftMonoRecipe {
  static const String recipeName = 'mono';
  static const List<String> slotNames = ['base'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('size', ['code', 'meta', 'tabular'], 'code', false),
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
    [1907, 1454, 1455, 2619, 1883, 2598],
    [1907, 1454, 1455, 2619, 1883, 2586],
    [1907, 1454, 1455, 2619, 1883, 2610],
    [1907, 1454, 1455, 2619, 1883, 2603],
    [1907, 1454, 1455, 2619, 1883, 2600],
    [1907, 1454, 1455, 2619, 1883, 2581],
    [1907, 1454, 1455, 2619, 1883, 2623],
    [1907, 1454, 1455, 2619, 1883, 2632],
    [1907, 1454, 1455, 2619, 1883, 2593],
    [1907, 1454, 1455, 2637, 1882, 2603],
    [1907, 1454, 1455, 2637, 1882, 2598],
    [1907, 1454, 1455, 2637, 1882, 2586],
    [1907, 1454, 1455, 2637, 1882, 2610],
    [1907, 1454, 1455, 2637, 1882, 2600],
    [1907, 1454, 1455, 2637, 1882, 2581],
    [1907, 1454, 1455, 2637, 1882, 2623],
    [1907, 1454, 1455, 2637, 1882, 2632],
    [1907, 1454, 1455, 2637, 1882, 2593],
    [1907, 1454, 1455, 2619, 2556, 1883, 2598],
    [1907, 1454, 1455, 2619, 2556, 1883, 2586],
    [1907, 1454, 1455, 2619, 2556, 1883, 2610],
    [1907, 1454, 1455, 2619, 2556, 1883, 2603],
    [1907, 1454, 1455, 2619, 2556, 1883, 2600],
    [1907, 1454, 1455, 2619, 2556, 1883, 2581],
    [1907, 1454, 1455, 2619, 2556, 1883, 2623],
    [1907, 1454, 1455, 2619, 2556, 1883, 2632],
    [1907, 1454, 1455, 2619, 2556, 1883, 2593],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0],
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
    [9],
    [13],
    [14],
    [15],
    [16],
    [17],
    [18],
    [18],
    [19],
    [20],
    [21],
    [22],
    [23],
    [24],
    [25],
    [26],
  ];
}
