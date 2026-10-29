// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
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
  const RaftDescriptionListRecipeStyle({
    required this.root,
    required this.item,
    required this.term,
    required this.details,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `item`.
  final RaftSlotStyle item;

  /// Slot `term`.
  final RaftSlotStyle term;

  /// Slot `details`.
  final RaftSlotStyle details;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'item': item,
    'term': term,
    'details': details,
  };
}

/// raft-ui recipe `descriptionList` (`src/components/description-list/description-list.tsx`, index.mjs:6330).
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
  ];

  static RaftDescriptionListRecipeStyle resolve({
    RaftDescriptionListRecipeDirection? direction,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [direction?.css],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftDescriptionListRecipeStyle(
      root: s[0],
      item: s[1],
      term: s[2],
      details: s[3],
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
    [1357],
    [113],
    [965, 1319, 68, 1429, 1022, 1016, 1821, 1013, 1824],
    [1357, 965, 1478, 1484, 971, 1319, 1022, 1016, 1813, 1822],
    [
      1357,
      1040,
      1318,
      1401,
      1400,
      70,
      131,
      130,
      132,
      133,
      128,
      129,
      1047,
      1035,
      1037,
      127,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3],
    [4, 1, 2, 3],
  ];
}
