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
    [1305, 1424, 1319, 712, 713, 721, 722, 1020, 1700, 581, 1598],
    [
      1305,
      1188,
      1483,
      1738,
      1319,
      1324,
      1022,
      1930,
      1572,
      1576,
      1578,
      1879,
      941,
      935,
      831,
      275,
      277,
      1708,
      622,
      641,
      615,
      1658,
      1016,
      1811,
      1017,
      1825,
      265,
      1272,
      891,
      890,
      892,
      897,
      895,
      896,
      893,
      894,
      888,
      996,
      833,
      836,
      832,
    ],
    [1895],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2],
  ];
}
