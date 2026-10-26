// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `pickerTriggerButton`.
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

/// raft-ui recipe `pickerTriggerButton` (`src/components/picker-trigger-button/picker-trigger-button.tsx`, index.mjs:5729).
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
      1678,
      1304,
      1187,
      1736,
      1318,
      1323,
      1928,
      1723,
      1571,
      1574,
      1576,
      1889,
      941,
      989,
      935,
      939,
      1242,
      1240,
      275,
      277,
      55,
      1021,
      1706,
      621,
      615,
      1655,
      1662,
      1015,
      1817,
      1016,
      1823,
      1308,
      1311,
      1271,
      427,
      857,
      861,
      860,
      858,
      859,
      856,
      874,
      875,
      995,
      922,
      938,
      931,
      930,
      264,
      271,
      62,
      61,
      207,
      208,
      209,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0],
  ];
}
