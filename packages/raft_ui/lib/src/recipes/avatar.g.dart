// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `avatar`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `type` axis of `avatar`.
enum RaftAvatarRecipeType {
  agent('agent'),
  human('human');

  const RaftAvatarRecipeType(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// `size` axis of `avatar`.
enum RaftAvatarRecipeSize {
  xl('xl'),
  lg('lg'),
  md('md'),
  sm('sm'),
  xs('xs'),
  v2xs('2xs'),
  v3xs('3xs');

  const RaftAvatarRecipeSize(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftAvatarRecipe].
class RaftAvatarRecipeStyle {
  const RaftAvatarRecipeStyle({
    required this.root,
    required this.image,
    required this.fallback,
    required this.badge,
    required this.dot,
    required this.group,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `image`.
  final RaftSlotStyle image;

  /// Slot `fallback`.
  final RaftSlotStyle fallback;

  /// Slot `badge`.
  final RaftSlotStyle badge;

  /// Slot `dot`.
  final RaftSlotStyle dot;

  /// Slot `group`.
  final RaftSlotStyle group;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'image': image,
    'fallback': fallback,
    'badge': badge,
    'dot': dot,
    'group': group,
  };
}

/// raft-ui recipe `avatar` (`src/components/avatar/avatar.tsx`, index.mjs:8134).
///
/// Used by: Avatar, AvatarBadge, AvatarFallback, AvatarGroup, AvatarGroupCount, AvatarImage, LiveAgentActivityBarAvatar.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftAvatarRecipe {
  static const String recipeName = 'avatar';
  static const List<String> slotNames = [
    'root',
    'image',
    'fallback',
    'badge',
    'dot',
    'group',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
    RaftRecipeAxis('type', ['agent', 'human'], null, true),
    RaftRecipeAxis(
      'size',
      ['xl', 'lg', 'md', 'sm', 'xs', '2xs', '3xs'],
      null,
      true,
    ),
  ];

  static RaftAvatarRecipeStyle resolve({
    required RaftRecipeTheme theme,
    RaftAvatarRecipeType? type_,
    RaftAvatarRecipeSize? size,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [theme.name, type_?.css, size?.css],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftAvatarRecipeStyle(
      root: s[0],
      image: s[1],
      fallback: s[2],
      badge: s[3],
      dot: s[4],
      group: s[5],
    );
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
    [1911, 2804, 1644, 2902, 2331, 2336, 2868, 892, 2994],
    [2925, 2645],
    [
      1644,
      2925,
      2331,
      2336,
      301,
      1835,
      1795,
      1812,
      1817,
      1840,
      1779,
      1786,
      2994,
    ],
    [
      586,
      3179,
      2911,
      2868,
      1838,
      1798,
      1815,
      1820,
      1844,
      1783,
      1790,
      2809,
      937,
      3129,
      1839,
      1799,
      1816,
      1821,
      1822,
      1846,
      1785,
      1792,
    ],
    [
      2320,
      2331,
      2336,
      2845,
      2668,
      2676,
      292,
      1834,
      1833,
      1794,
      1793,
      1811,
      1810,
      1842,
      1781,
      1788,
      849,
      3013,
    ],
    [1912, 1644, 2331, 146, 93, 95, 88, 90],
    [1911, 2804, 1644, 2902, 2331, 2336, 2868, 892, 2994, 2910, 878],
    [1911, 2804, 1644, 2902, 2331, 2336, 2868, 892, 2994, 2908, 878],
    [1911, 2804, 1644, 2902, 2331, 2336, 2868, 892, 2994, 2921, 878],
    [1911, 2804, 1644, 2902, 2331, 2336, 2868, 892, 2994, 2920, 878],
    [1911, 2804, 1644, 2902, 2331, 2336, 2868, 892, 2994, 2917, 876],
    [1911, 2804, 1644, 2902, 2331, 2336, 2868, 892, 2994, 2916, 876],
    [1911, 2804, 1644, 2902, 2331, 2336, 2868, 892, 2994, 2914, 876],
    [1911, 2804, 1644, 2902, 2331, 2336, 2868, 892, 2994, 778],
    [1911, 2804, 1644, 2902, 2331, 2336, 2868, 892, 2994, 2910, 878, 778],
    [1911, 2804, 1644, 2902, 2331, 2336, 2868, 892, 2994, 2908, 878, 778],
    [1911, 2804, 1644, 2902, 2331, 2336, 2868, 892, 2994, 2921, 878, 778],
    [1911, 2804, 1644, 2902, 2331, 2336, 2868, 892, 2994, 2920, 878, 778],
    [1911, 2804, 1644, 2902, 2331, 2336, 2868, 892, 2994, 2917, 876, 778],
    [1911, 2804, 1644, 2902, 2331, 2336, 2868, 892, 2994, 2916, 876, 778],
    [1911, 2804, 1644, 2902, 2331, 2336, 2868, 892, 2994, 2914, 876, 778],
    [1911, 2804, 1644, 2902, 2331, 2336, 2868, 892, 781, 2994],
    [1911, 2804, 1644, 2902, 2331, 2336, 2868, 892, 2910, 878, 781, 2994],
    [1911, 2804, 1644, 2902, 2331, 2336, 2868, 892, 2908, 878, 781, 2994],
    [1911, 2804, 1644, 2902, 2331, 2336, 2868, 892, 2921, 878, 781, 2994],
    [1911, 2804, 1644, 2902, 2331, 2336, 2868, 892, 2920, 878, 781, 2994],
    [1911, 2804, 1644, 2902, 2331, 2336, 2868, 892, 2917, 876, 781, 2994],
    [1911, 2804, 1644, 2902, 2331, 2336, 2868, 892, 2916, 876, 781, 2994],
    [1911, 2804, 1644, 2902, 2331, 2336, 2868, 892, 2914, 876, 781, 2994],
    [1911, 2804, 1644, 2902, 2331, 2336, 2868, 801],
    [2925, 2645, 2845],
    [
      1644,
      2925,
      2331,
      2336,
      301,
      1835,
      1795,
      1812,
      1817,
      1840,
      1779,
      1786,
      2679,
      801,
      3022,
      3053,
      2845,
      1845,
      1784,
      1791,
    ],
    [
      586,
      3179,
      2911,
      2868,
      1838,
      1798,
      1815,
      1820,
      1844,
      1783,
      1790,
      2668,
      2671,
      1837,
      1836,
      1797,
      1796,
      1814,
      1813,
      1819,
      1818,
      1843,
      1841,
      1782,
      1780,
      1789,
      1787,
    ],
    [
      2320,
      2331,
      2336,
      2845,
      2668,
      292,
      1834,
      1833,
      1794,
      1793,
      1811,
      1810,
      1842,
      1781,
      1788,
      849,
      3056,
      2671,
    ],
    [1912, 1644, 2331, 147, 91, 93, 94, 86, 88, 89],
    [1911, 2804, 1644, 2902, 2331, 2336, 2868, 801, 2910, 878, 930, 795, 2845],
    [1911, 2804, 1644, 2902, 2331, 2336, 2868, 801, 2908, 878, 930, 795, 2845],
    [1911, 2804, 1644, 2902, 2331, 2336, 2868, 801, 2921, 878, 930, 795, 2845],
    [1911, 2804, 1644, 2902, 2331, 2336, 2868, 801, 2920, 878, 930, 795, 2845],
    [1911, 2804, 1644, 2902, 2331, 2336, 2868, 801, 2917, 876, 930, 795, 2845],
    [1911, 2804, 1644, 2902, 2331, 2336, 2868, 801, 2916, 876, 930, 795, 2845],
    [1911, 2804, 1644, 2902, 2331, 2336, 2868, 801, 2914, 876, 930, 795, 2845],
    [1911, 2804, 1644, 2902, 2331, 2336, 2868, 801, 3018],
    [
      1911,
      2804,
      1644,
      2902,
      2331,
      2336,
      2868,
      801,
      2910,
      878,
      930,
      795,
      2845,
      3018,
    ],
    [
      1911,
      2804,
      1644,
      2902,
      2331,
      2336,
      2868,
      801,
      2908,
      878,
      930,
      795,
      2845,
      3018,
    ],
    [
      1911,
      2804,
      1644,
      2902,
      2331,
      2336,
      2868,
      801,
      2921,
      878,
      930,
      795,
      2845,
      3018,
    ],
    [
      1911,
      2804,
      1644,
      2902,
      2331,
      2336,
      2868,
      801,
      2920,
      878,
      930,
      795,
      2845,
      3018,
    ],
    [
      1911,
      2804,
      1644,
      2902,
      2331,
      2336,
      2868,
      801,
      2917,
      876,
      930,
      795,
      2845,
      3018,
    ],
    [
      1911,
      2804,
      1644,
      2902,
      2331,
      2336,
      2868,
      801,
      2916,
      876,
      930,
      795,
      2845,
      3018,
    ],
    [
      1911,
      2804,
      1644,
      2902,
      2331,
      2336,
      2868,
      801,
      2914,
      876,
      930,
      795,
      2845,
      3018,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5],
    [6, 1, 2, 3, 4, 5],
    [7, 1, 2, 3, 4, 5],
    [8, 1, 2, 3, 4, 5],
    [9, 1, 2, 3, 4, 5],
    [10, 1, 2, 3, 4, 5],
    [11, 1, 2, 3, 4, 5],
    [12, 1, 2, 3, 4, 5],
    [13, 1, 2, 3, 4, 5],
    [14, 1, 2, 3, 4, 5],
    [15, 1, 2, 3, 4, 5],
    [16, 1, 2, 3, 4, 5],
    [17, 1, 2, 3, 4, 5],
    [18, 1, 2, 3, 4, 5],
    [19, 1, 2, 3, 4, 5],
    [20, 1, 2, 3, 4, 5],
    [21, 1, 2, 3, 4, 5],
    [22, 1, 2, 3, 4, 5],
    [23, 1, 2, 3, 4, 5],
    [24, 1, 2, 3, 4, 5],
    [25, 1, 2, 3, 4, 5],
    [26, 1, 2, 3, 4, 5],
    [27, 1, 2, 3, 4, 5],
    [28, 1, 2, 3, 4, 5],
    [29, 30, 31, 32, 33, 34],
    [35, 30, 31, 32, 33, 34],
    [36, 30, 31, 32, 33, 34],
    [37, 30, 31, 32, 33, 34],
    [38, 30, 31, 32, 33, 34],
    [39, 30, 31, 32, 33, 34],
    [40, 30, 31, 32, 33, 34],
    [41, 30, 31, 32, 33, 34],
    [42, 30, 31, 32, 33, 34],
    [43, 30, 31, 32, 33, 34],
    [44, 30, 31, 32, 33, 34],
    [45, 30, 31, 32, 33, 34],
    [46, 30, 31, 32, 33, 34],
    [47, 30, 31, 32, 33, 34],
    [48, 30, 31, 32, 33, 34],
    [49, 30, 31, 32, 33, 34],
    [42, 30, 31, 32, 33, 34],
    [43, 30, 31, 32, 33, 34],
    [44, 30, 31, 32, 33, 34],
    [45, 30, 31, 32, 33, 34],
    [46, 30, 31, 32, 33, 34],
    [47, 30, 31, 32, 33, 34],
    [48, 30, 31, 32, 33, 34],
    [49, 30, 31, 32, 33, 34],
  ];
}
