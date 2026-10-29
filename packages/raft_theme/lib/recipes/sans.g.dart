// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
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

/// raft-ui recipe `sans` (`src/components/text/text.tsx`, index.mjs:9999).
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
    [1357, 1016, 1015, 1835, 1340, 1820],
    [1357, 1016, 1015, 1835, 1340, 1809],
    [1357, 1016, 1015, 1835, 1340, 1832],
    [1357, 1016, 1015, 1835, 1340, 1825],
    [1357, 1016, 1015, 1835, 1340, 1822],
    [1357, 1016, 1015, 1835, 1340, 1804],
    [1357, 1016, 1015, 1835, 1340, 1844],
    [1357, 1016, 1015, 1835, 1340, 1853],
    [1357, 1016, 1015, 1835, 1340, 1816],
    [1357, 1016, 1015, 1807, 1339, 1820],
    [1357, 1016, 1015, 1807, 1339, 1809],
    [1357, 1016, 1015, 1807, 1339, 1832],
    [1357, 1016, 1015, 1807, 1339, 1825],
    [1357, 1016, 1015, 1807, 1339, 1822],
    [1357, 1016, 1015, 1807, 1339, 1804],
    [1357, 1016, 1015, 1807, 1339, 1844],
    [1357, 1016, 1015, 1807, 1339, 1853],
    [1357, 1016, 1015, 1807, 1339, 1816],
    [1357, 1016, 1015, 1840, 1338, 1825],
    [1357, 1016, 1015, 1840, 1338, 1820],
    [1357, 1016, 1015, 1840, 1338, 1809],
    [1357, 1016, 1015, 1840, 1338, 1832],
    [1357, 1016, 1015, 1840, 1338, 1822],
    [1357, 1016, 1015, 1840, 1338, 1804],
    [1357, 1016, 1015, 1840, 1338, 1844],
    [1357, 1016, 1015, 1840, 1338, 1853],
    [1357, 1016, 1015, 1840, 1338, 1816],
    [1357, 1016, 1015, 1858, 1336, 1825],
    [1357, 1016, 1015, 1858, 1336, 1820],
    [1357, 1016, 1015, 1858, 1336, 1809],
    [1357, 1016, 1015, 1858, 1336, 1832],
    [1357, 1016, 1015, 1858, 1336, 1822],
    [1357, 1016, 1015, 1858, 1336, 1804],
    [1357, 1016, 1015, 1858, 1336, 1844],
    [1357, 1016, 1015, 1858, 1336, 1853],
    [1357, 1016, 1015, 1858, 1336, 1816],
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
  ];
}
