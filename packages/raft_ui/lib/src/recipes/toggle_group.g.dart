// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `toggleGroup`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftToggleGroupRecipe].
class RaftToggleGroupRecipeStyle {
  const RaftToggleGroupRecipeStyle({required this.root, required this.item, required this.label});

  /// Slot `root`.
  final RaftSlotStyle root;
  /// Slot `item`.
  final RaftSlotStyle item;
  /// Slot `label`.
  final RaftSlotStyle label;

  Map<String, RaftSlotStyle> get slots => {'root': root, 'item': item, 'label': label};
}

/// raft-ui recipe `toggleGroup` (`src/components/toggle-group/toggle-group.tsx`, index.mjs:7850).
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

  static RaftToggleGroupRecipeStyle resolve({required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name], states, tokens);
    return RaftToggleGroupRecipeStyle(root: s[0], item: s[1], label: s[2]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [2301, 2484, 2312, 1282, 1283, 1293, 1294, 1696],
    [2301, 1966, 2574, 2867, 2312, 2317, 1697, 2752, 3032, 2333, 3131, 825, 2976, 2645, 2650, 2652, 3067, 1601, 1590, 1442, 1446, 1546, 1557, 425, 427, 416, 866, 900, 1684, 2225, 1644, 608, 1553],
    [3092],
    [2301, 2484, 2312, 1282, 1283, 1293, 1294, 1697],
    [2301, 1966, 2574, 2867, 2312, 2317, 1697, 2752, 3032, 2333, 1688, 3131, 825, 2976, 2645, 2650, 2652, 3067, 1601, 1590, 1442, 1446, 1546, 1557, 425, 427, 416, 2822, 643, 2851, 1125, 1127, 2618, 1126, 1551, 1552, 1056, 1055, 1653, 1656, 1661, 1663, 601],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2], [3, 4, 2],
  ];
}
