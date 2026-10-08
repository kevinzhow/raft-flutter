// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `segmentedControl`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftSegmentedControlRecipe].
class RaftSegmentedControlRecipeStyle {
  const RaftSegmentedControlRecipeStyle({required this.root, required this.item, required this.label, required this.count});

  /// Slot `root`.
  final RaftSlotStyle root;
  /// Slot `item`.
  final RaftSlotStyle item;
  /// Slot `label`.
  final RaftSlotStyle label;
  /// Slot `count`.
  final RaftSlotStyle count;

  Map<String, RaftSlotStyle> get slots => {'root': root, 'item': item, 'label': label, 'count': count};
}

/// raft-ui recipe `segmentedControl` (`src/components/segmented-control/segmented-control.tsx`, index.mjs:7757).
///
/// Used by: SegmentedControl, SegmentedControlCount, SegmentedControlItem, SegmentedControlLabel.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftSegmentedControlRecipe {
  static const String recipeName = 'segmentedControl';
  static const List<String> slotNames = ['root', 'item', 'label', 'count'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
    RaftRecipeAxis('disabled', ['true', 'false'], 'false', false),
  ];

  static RaftSegmentedControlRecipeStyle resolve({required RaftRecipeTheme theme, bool? disabled, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name, disabled?.toString()], states, tokens);
    return RaftSegmentedControlRecipeStyle(root: s[0], item: s[1], label: s[2], count: s[3]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [2301, 2484, 1626, 2312, 1696, 2628],
    [2301, 2574, 2867, 2312, 1697, 3032, 2333, 2649, 1590, 425, 427, 416, 866, 900, 825, 2751, 2763, 1692, 2976, 2122, 2103, 447, 462, 2225, 1414, 1429, 1442],
    [3092],
    [1689, 3032, 2333, 1684, 2994, 1832],
    [2301, 2484, 1626, 2312, 1696],
    [2301, 2484, 1626, 2312, 1697, 2628],
    [2301, 2574, 2867, 2312, 1697, 3032, 2333, 2649, 1590, 425, 427, 416, 2822, 825, 2752, 2765, 1688, 2976, 643, 2123, 2104, 2851, 1058, 1060, 1573, 1059, 1414, 1430, 1420, 1423, 1041, 1037, 1653, 1656, 1661, 1663, 1442],
    [1689, 3032, 2333, 2984, 1833],
    [2301, 2484, 1626, 2312, 1697],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3], [4, 1, 2, 3], [5, 6, 2, 7], [8, 6, 2, 7],
  ];
}
