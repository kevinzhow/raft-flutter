// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `descriptionList`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `direction` axis of `descriptionList` (default `vertical`).
enum RaftDescriptionListRecipeDirection {
  vertical('vertical'),
  horizontal('horizontal'),
  inline('inline');

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

/// raft-ui recipe `descriptionList` (`dist/components/description-list/description-list.mjs`, index.mjs:10946).
///
/// Used by: DescriptionDetails, DescriptionItem, DescriptionList, DescriptionTerm.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftDescriptionListRecipe {
  static const String recipeName = 'descriptionList';
  static const List<String> slotNames = ['root', 'item', 'term', 'details'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis(
      'direction',
      ['vertical', 'horizontal', 'inline'],
      'vertical',
      false,
    ),
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
    [1907],
    [252],
    [1400, 1864, 98, 1986, 1465, 1456, 2597, 1453, 2600],
    [1907, 1400, 2106, 2116, 1408, 1864, 1465, 1456, 2587, 2598],
    [
      1907,
      2725,
      1489,
      1863,
      378,
      379,
      377,
      104,
      282,
      281,
      283,
      285,
      279,
      280,
      1498,
      1482,
      1485,
      278,
    ],
    [
      1907,
      1400,
      1408,
      1863,
      1483,
      1487,
      105,
      109,
      107,
      106,
      108,
      279,
      271,
      284,
      274,
      275,
      273,
      272,
      276,
      277,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3],
    [4, 1, 2, 3],
    [5, 1, 2, 3],
  ];
}
