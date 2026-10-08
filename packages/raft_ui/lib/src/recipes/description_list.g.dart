// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `descriptionList`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `direction` axis of `descriptionList` (default `vertical`).
enum RaftDescriptionListRecipeDirection {
  vertical('vertical'),
  horizontal('horizontal');

  const RaftDescriptionListRecipeDirection(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftDescriptionListRecipe].
class RaftDescriptionListRecipeStyle {
  const RaftDescriptionListRecipeStyle({required this.root, required this.item, required this.term, required this.details});

  /// Slot `root`.
  final RaftSlotStyle root;
  /// Slot `item`.
  final RaftSlotStyle item;
  /// Slot `term`.
  final RaftSlotStyle term;
  /// Slot `details`.
  final RaftSlotStyle details;

  Map<String, RaftSlotStyle> get slots => {'root': root, 'item': item, 'term': term, 'details': details};
}

/// raft-ui recipe `descriptionList` (`src/components/description-list/description-list.tsx`, index.mjs:8021).
///
/// Used by: DescriptionDetails, DescriptionItem, DescriptionList, DescriptionTerm.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftDescriptionListRecipe {
  static const String recipeName = 'descriptionList';
  static const List<String> slotNames = ['root', 'item', 'term', 'details'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('direction', ['vertical', 'horizontal'], 'vertical', false),
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftDescriptionListRecipeStyle resolve({RaftDescriptionListRecipeDirection? direction, required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [direction?.css, theme.name], states, tokens);
    return RaftDescriptionListRecipeStyle(root: s[0], item: s[1], term: s[2], details: s[3]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [2359],
    [],
    [2491, 1620, 2312, 1698, 3032, 96, 2992],
    [2359, 3017, 2976],
    [1620, 2312, 96, 2492, 1697, 1691, 2920, 1688, 2344, 2984],
    [2359, 3017, 1691, 2335, 2981],
    [2359, 1717, 1720, 2311, 2464, 2463, 98, 227, 226, 228, 229, 224, 225, 1708, 1714],
    [2359, 1717, 1720, 2311, 2464, 2463, 98, 227, 226, 228, 229, 224, 225, 1711, 1716],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3], [0, 1, 4, 5], [6, 1, 2, 3], [7, 1, 4, 5],
  ];
}
