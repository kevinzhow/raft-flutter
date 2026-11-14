// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `pickerTriggerButton`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftPickerTriggerButtonRecipe].
class RaftPickerTriggerButtonRecipeStyle {
  const RaftPickerTriggerButtonRecipeStyle({required this.base});

  /// Slot `base`.
  final RaftSlotStyle base;

  Map<String, RaftSlotStyle> get slots => {'base': base};
}

/// raft-ui recipe `pickerTriggerButton` (`dist/components/picker-trigger-button/picker-trigger-button.mjs`, index.mjs:8454).
///
/// Used by: PickerTriggerButton.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftPickerTriggerButtonRecipe {
  static const String recipeName = 'pickerTriggerButton';
  static const List<String> slotNames = ['base'];
  static const List<RaftRecipeAxis> axes = [];

  static RaftPickerTriggerButtonRecipeStyle resolve({
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftPickerTriggerButtonRecipeStyle(base: s[0]);
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
    [
      2433,
      1847,
      1661,
      2042,
      2499,
      1864,
      1869,
      723,
      738,
      714,
      2029,
      2729,
      2483,
      2245,
      2248,
      2250,
      2675,
      1365,
      1434,
      1360,
      1364,
      1731,
      1729,
      472,
      474,
      74,
      1465,
      2463,
      940,
      933,
      2402,
      2412,
      1456,
      2591,
      1457,
      2603,
      1851,
      1855,
      1785,
      697,
      1231,
      1235,
      1234,
      1232,
      1233,
      1230,
      1257,
      1258,
      1439,
      1347,
      1363,
      1356,
      1355,
      459,
      467,
      81,
      80,
      1342,
      1173,
      382,
      383,
      384,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0],
  ];
}
