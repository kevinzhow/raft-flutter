// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `progress`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `variant` axis of `progress` (default `primary`).
enum RaftProgressRecipeVariant {
  primary('primary'),
  information('information'),
  accent('accent'),
  success('success'),
  warning('warning'),
  danger('danger');

  const RaftProgressRecipeVariant(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// `size` axis of `progress` (default `md`).
enum RaftProgressRecipeSize {
  sm('sm'),
  md('md'),
  lg('lg');

  const RaftProgressRecipeSize(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftProgressRecipe].
class RaftProgressRecipeStyle {
  const RaftProgressRecipeStyle({
    required this.root,
    required this.header,
    required this.label,
    required this.value,
    required this.track,
    required this.indicator,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `header`.
  final RaftSlotStyle header;

  /// Slot `label`.
  final RaftSlotStyle label;

  /// Slot `value`.
  final RaftSlotStyle value;

  /// Slot `track`.
  final RaftSlotStyle track;

  /// Slot `indicator`.
  final RaftSlotStyle indicator;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'header': header,
    'label': label,
    'value': value,
    'track': track,
    'indicator': indicator,
  };
}

/// raft-ui recipe `progress` (`dist/components/progress/progress.mjs`, index.mjs:14717).
///
/// Used by: Progress, ProgressHeader, ProgressIndicator, ProgressLabel, ProgressTrack, ProgressValue.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftProgressRecipe {
  static const String recipeName = 'progress';
  static const List<String> slotNames = [
    'root',
    'header',
    'label',
    'value',
    'track',
    'indicator',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis(
      'variant',
      ['primary', 'information', 'accent', 'success', 'warning', 'danger'],
      'primary',
      false,
    ),
    RaftRecipeAxis('size', ['sm', 'md', 'lg'], 'md', false),
  ];

  static RaftProgressRecipeStyle resolve({
    RaftProgressRecipeVariant? variant,
    RaftProgressRecipeSize? size,
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
    return RaftProgressRecipeStyle(
      root: s[0],
      header: s[1],
      label: s[2],
      value: s[3],
      track: s[4],
      indicator: s[5],
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
    [1618, 1489, 2725, 2116, 1465, 573, 574, 1456, 1169, 570],
    [1400, 2116, 1864, 1868, 1468],
    [2116, 2681, 2597, 1457, 2598],
    [2499, 2556, 1454, 2616, 2600],
    [2433, 2725, 2252, 877, 1650, 1539, 1530, 2471],
    [
      937,
      1678,
      876,
      2673,
      1367,
      1376,
      1243,
      1033,
      1247,
      1245,
      1244,
      2459,
      1853,
      1856,
    ],
    [1618, 1489, 2725, 2116, 1465, 573, 574, 1456, 1169, 571],
    [1618, 1489, 2725, 2116, 1465, 573, 574, 1456, 1169, 572],
    [1618, 1489, 2725, 2116, 1465, 573, 574, 1456, 1169, 568],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5],
    [0, 1, 2, 3, 4, 5],
    [0, 1, 2, 3, 4, 5],
    [0, 1, 2, 3, 4, 5],
    [0, 1, 2, 3, 4, 5],
    [0, 1, 2, 3, 4, 5],
    [0, 1, 2, 3, 4, 5],
    [0, 1, 2, 3, 4, 5],
    [0, 1, 2, 3, 4, 5],
    [6, 1, 2, 3, 4, 5],
    [6, 1, 2, 3, 4, 5],
    [6, 1, 2, 3, 4, 5],
    [7, 1, 2, 3, 4, 5],
    [7, 1, 2, 3, 4, 5],
    [7, 1, 2, 3, 4, 5],
    [8, 1, 2, 3, 4, 5],
    [8, 1, 2, 3, 4, 5],
    [8, 1, 2, 3, 4, 5],
  ];
}
