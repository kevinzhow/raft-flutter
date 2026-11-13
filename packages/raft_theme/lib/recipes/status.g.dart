// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `status`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `variant` axis of `status` (default `default`).
enum RaftStatusRecipeVariant {
  default_('default'),
  primary('primary'),
  information('information'),
  muted('muted'),
  accent('accent'),
  success('success'),
  warning('warning'),
  danger('danger');

  const RaftStatusRecipeVariant(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// `size` axis of `status` (default `md`).
enum RaftStatusRecipeSize {
  xs('xs'),
  sm('sm'),
  md('md'),
  lg('lg');

  const RaftStatusRecipeSize(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftStatusRecipe].
class RaftStatusRecipeStyle {
  const RaftStatusRecipeStyle({required this.root});

  /// Slot `root`.
  final RaftSlotStyle root;

  Map<String, RaftSlotStyle> get slots => {'root': root};
}

/// raft-ui recipe `status` (`dist/components/status/status.mjs`, index.mjs:3854).
///
/// Used by: Status.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftStatusRecipe {
  static const String recipeName = 'status';
  static const List<String> slotNames = ['root'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis(
      'variant',
      [
        'default',
        'primary',
        'information',
        'muted',
        'accent',
        'success',
        'warning',
        'danger',
      ],
      'default',
      false,
    ),
    RaftRecipeAxis('size', ['xs', 'sm', 'md', 'lg'], 'md', false),
  ];

  static RaftStatusRecipeStyle resolve({
    RaftStatusRecipeVariant? variant,
    RaftStatusRecipeSize? size,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [variant?.css, size?.css],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftStatusRecipeStyle(root: s[0]);
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
    [2433, 1846, 2499, 880, 958, 590, 2508, 2456, 939],
    [2433, 1846, 2499, 880, 2457, 941, 958, 590, 2513],
    [2433, 1846, 2499, 880, 2457, 941, 958, 590, 2514],
    [2433, 1846, 2499, 880, 2457, 941, 958, 590, 2524],
    [2433, 1846, 2499, 880, 958, 589, 2508, 2456, 939],
    [2433, 1846, 2499, 880, 2457, 941, 958, 589, 2513],
    [2433, 1846, 2499, 880, 2457, 941, 958, 589, 2514],
    [2433, 1846, 2499, 880, 2457, 941, 958, 589, 2524],
    [2433, 1846, 2499, 880, 958, 587, 2508, 2456, 939],
    [2433, 1846, 2499, 880, 2457, 941, 958, 587, 2513],
    [2433, 1846, 2499, 880, 2457, 941, 958, 587, 2514],
    [2433, 1846, 2499, 880, 2457, 941, 958, 587, 2524],
    [2433, 1846, 2499, 880, 958, 588, 2508, 2456, 939],
    [2433, 1846, 2499, 880, 2457, 941, 958, 588, 2513],
    [2433, 1846, 2499, 880, 2457, 941, 958, 588, 2514],
    [2433, 1846, 2499, 880, 2457, 941, 958, 588, 2524],
    [2433, 1846, 2499, 880, 958, 585, 2508, 2456, 939],
    [2433, 1846, 2499, 880, 2457, 941, 958, 585, 2513],
    [2433, 1846, 2499, 880, 2457, 941, 958, 585, 2514],
    [2433, 1846, 2499, 880, 2457, 941, 958, 585, 2524],
    [2433, 1846, 2499, 880, 958, 591, 2508, 2456, 939],
    [2433, 1846, 2499, 880, 2457, 941, 958, 591, 2513],
    [2433, 1846, 2499, 880, 2457, 941, 958, 591, 2514],
    [2433, 1846, 2499, 880, 2457, 941, 958, 591, 2524],
    [2433, 1846, 2499, 880, 958, 592, 2508, 2456, 939],
    [2433, 1846, 2499, 880, 2457, 941, 958, 592, 2513],
    [2433, 1846, 2499, 880, 2457, 941, 958, 592, 2514],
    [2433, 1846, 2499, 880, 2457, 941, 958, 592, 2524],
    [2433, 1846, 2499, 880, 958, 586, 2508, 2456, 939],
    [2433, 1846, 2499, 880, 2457, 941, 958, 586, 2513],
    [2433, 1846, 2499, 880, 2457, 941, 958, 586, 2514],
    [2433, 1846, 2499, 880, 2457, 941, 958, 586, 2524],
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
  ];
}
