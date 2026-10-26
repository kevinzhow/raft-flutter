// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `toggleGroup`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftToggleGroupRecipe].
class RaftToggleGroupRecipeStyle {
  const RaftToggleGroupRecipeStyle({
    required this.root,
    required this.item,
    required this.label,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `item`.
  final RaftSlotStyle item;

  /// Slot `label`.
  final RaftSlotStyle label;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'item': item,
    'label': label,
  };
}

/// raft-ui recipe `toggleGroup` (`src/components/toggle-group/toggle-group.tsx`, index.mjs:6218).
///
/// Used by: ToggleGroup, ToggleGroupItem, ToggleGroupLabel.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftToggleGroupRecipe {
  static const String recipeName = 'toggleGroup';
  static const List<String> slotNames = ['root', 'item', 'label'];
  static const List<RaftRecipeAxis> axes = [];

  static RaftToggleGroupRecipeStyle resolve({
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
    return RaftToggleGroupRecipeStyle(root: s[0], item: s[1], label: s[2]);
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
    [1304, 1422, 1318, 712, 713, 721, 722, 1019, 1698, 581, 1596],
    [
      1304,
      1187,
      1481,
      1736,
      1318,
      1323,
      1021,
      1928,
      1570,
      1574,
      1576,
      1877,
      941,
      935,
      831,
      275,
      277,
      1706,
      622,
      641,
      615,
      1656,
      1015,
      1809,
      1016,
      1823,
      265,
      1271,
      891,
      890,
      892,
      897,
      895,
      896,
      893,
      894,
      888,
      995,
      833,
      836,
      832,
    ],
    [1893],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2],
  ];
}
