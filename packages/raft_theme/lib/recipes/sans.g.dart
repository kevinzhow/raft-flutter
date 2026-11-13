// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `sans`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `size` axis of `sans` (default `body`).
enum RaftSansRecipeSize {
  large('large'),
  body('body'),
  small('small'),
  caption('caption'),
  group('group');

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

/// raft-ui recipe `sans` (`dist/components/text/text.mjs`, index.mjs:15141).
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
      ['large', 'body', 'small', 'caption', 'group'],
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
    [1907, 1456, 1455, 2614, 1885, 2598],
    [1907, 1456, 1455, 2614, 1885, 2586],
    [1907, 1456, 1455, 2614, 1885, 2610],
    [1907, 1456, 1455, 2614, 1885, 2603],
    [1907, 1456, 1455, 2614, 1885, 2600],
    [1907, 1456, 1455, 2614, 1885, 2581],
    [1907, 1456, 1455, 2614, 1885, 2623],
    [1907, 1456, 1455, 2614, 1885, 2632],
    [1907, 1456, 1455, 2614, 1885, 2593],
    [1907, 1456, 1455, 2584, 1884, 2598],
    [1907, 1456, 1455, 2584, 1884, 2586],
    [1907, 1456, 1455, 2584, 1884, 2610],
    [1907, 1456, 1455, 2584, 1884, 2603],
    [1907, 1456, 1455, 2584, 1884, 2600],
    [1907, 1456, 1455, 2584, 1884, 2581],
    [1907, 1456, 1455, 2584, 1884, 2623],
    [1907, 1456, 1455, 2584, 1884, 2632],
    [1907, 1456, 1455, 2584, 1884, 2593],
    [1907, 1456, 1455, 2619, 1883, 2603],
    [1907, 1456, 1455, 2619, 1883, 2598],
    [1907, 1456, 1455, 2619, 1883, 2586],
    [1907, 1456, 1455, 2619, 1883, 2610],
    [1907, 1456, 1455, 2619, 1883, 2600],
    [1907, 1456, 1455, 2619, 1883, 2581],
    [1907, 1456, 1455, 2619, 1883, 2623],
    [1907, 1456, 1455, 2619, 1883, 2632],
    [1907, 1456, 1455, 2619, 1883, 2593],
    [1907, 1456, 1455, 2637, 1882, 2603],
    [1907, 1456, 1455, 2637, 1882, 2598],
    [1907, 1456, 1455, 2637, 1882, 2586],
    [1907, 1456, 1455, 2637, 1882, 2610],
    [1907, 1456, 1455, 2637, 1882, 2600],
    [1907, 1456, 1455, 2637, 1882, 2581],
    [1907, 1456, 1455, 2637, 1882, 2623],
    [1907, 1456, 1455, 2637, 1882, 2632],
    [1907, 1456, 1455, 2637, 1882, 2593],
    [1907, 1456, 2597, 1449, 2600],
    [1907, 1456, 2597, 1449, 2598],
    [1907, 1456, 2597, 1449, 2586],
    [1907, 1456, 2597, 1449, 2610],
    [1907, 1456, 2597, 1449, 2603],
    [1907, 1456, 2597, 1449, 2581],
    [1907, 1456, 2597, 1449, 2623],
    [1907, 1456, 2597, 1449, 2632],
    [1907, 1456, 2597, 1449, 2593],
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
    [18],
    [22],
    [23],
    [24],
    [25],
    [26],
    [27],
    [28],
    [29],
    [30],
    [27],
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
    [36],
    [41],
    [42],
    [43],
    [44],
  ];
}
