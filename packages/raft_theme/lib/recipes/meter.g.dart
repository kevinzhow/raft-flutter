// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `meter`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `size` axis of `meter` (default `md`).
enum RaftMeterRecipeSize {
  sm('sm'),
  md('md');

  const RaftMeterRecipeSize(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftMeterRecipe].
class RaftMeterRecipeStyle {
  const RaftMeterRecipeStyle({
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

/// raft-ui recipe `meter` (`dist/components/meter/meter.mjs`, index.mjs:28147).
///
/// Used by: Meter, MeterHeader, MeterIndicator, MeterLabel, MeterTrack, MeterValue.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftMeterRecipe {
  static const String recipeName = 'meter';
  static const List<String> slotNames = [
    'root',
    'header',
    'label',
    'value',
    'track',
    'indicator',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('warning', ['true', 'false'], 'false', false),
    RaftRecipeAxis('size', ['sm', 'md'], 'md', false),
  ];

  static RaftMeterRecipeStyle resolve({
    bool? warning,
    RaftMeterRecipeSize? size,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [warning?.toString(), size?.css],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftMeterRecipeStyle(
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
    [1615, 1489, 2725, 2116, 1465, 1456, 562, 564],
    [1400, 2116, 1408, 1863, 1868, 1481, 1485],
    [2116, 2681, 2597, 1457, 2598],
    [2499, 2618, 2556, 2597, 2564],
    [2433, 2725, 2252, 873, 1650, 1538, 2471],
    [937, 1678, 874, 2673, 1367, 1376, 2459, 1853, 1856],
    [1615, 1489, 2725, 2116, 1465, 561, 563, 1456],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5],
    [0, 1, 2, 3, 4, 5],
    [6, 1, 2, 3, 4, 5],
    [6, 1, 2, 3, 4, 5],
  ];
}
