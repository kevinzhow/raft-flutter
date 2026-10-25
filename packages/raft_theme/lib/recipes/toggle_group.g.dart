// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
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

/// raft-ui recipe `toggleGroup` (`src/components/toggle-group/toggle-group.tsx`, index.mjs:7867).
///
/// Used by: ToggleGroup, ToggleGroupItem, ToggleGroupLabel.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftToggleGroupRecipe {
  static const String recipeName = 'toggleGroup';
  static const List<String> slotNames = ['root', 'item', 'label'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftToggleGroupRecipeStyle resolve({
    required RaftRecipeTheme theme,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [theme.name],
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
    [2320, 2505, 2331, 1304, 1305, 1315, 1316, 1721],
    [
      2320,
      1968,
      2597,
      2902,
      2331,
      2336,
      1722,
      2780,
      3073,
      2352,
      3172,
      830,
      3013,
      2668,
      2673,
      2675,
      3108,
      1625,
      1614,
      1464,
      1468,
      1570,
      1581,
      423,
      425,
      414,
      878,
      916,
      1709,
      2244,
      1668,
      614,
      1577,
    ],
    [3133],
    [2320, 2505, 2331, 1304, 1305, 1315, 1316, 1722],
    [
      2320,
      1968,
      2597,
      2902,
      2331,
      2336,
      1722,
      2780,
      3073,
      2352,
      1713,
      3172,
      830,
      3013,
      2668,
      2673,
      2675,
      3108,
      1625,
      1614,
      1464,
      1468,
      1570,
      1581,
      423,
      425,
      414,
      2852,
      649,
      2885,
      1144,
      1146,
      2640,
      1145,
      1575,
      1576,
      1076,
      1075,
      1677,
      1680,
      1685,
      1687,
      607,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2],
    [3, 4, 2],
  ];
}
