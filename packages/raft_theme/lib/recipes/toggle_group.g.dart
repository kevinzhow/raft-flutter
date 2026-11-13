// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `toggleGroup`.
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

/// raft-ui recipe `toggleGroup` (`dist/components/toggle-group/toggle-group.mjs`, index.mjs:10716).
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
    [1847, 1980, 1864, 1048, 1049, 1055, 1056, 1472, 2455, 895, 2268],
    [
      1847,
      1661,
      2042,
      2116,
      2499,
      1864,
      1869,
      1465,
      2729,
      2244,
      2248,
      2250,
      2662,
      1365,
      1360,
      1181,
      472,
      474,
      2463,
      941,
      963,
      933,
      2403,
      1456,
      2587,
      1457,
      2603,
      460,
      1785,
      697,
      1289,
      1288,
      1290,
      1294,
      1292,
      1293,
      1291,
      1285,
      1286,
      1439,
      1184,
      1187,
      1183,
    ],
    [2681],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2],
  ];
}
