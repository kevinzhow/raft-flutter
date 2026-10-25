// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `searchEntity`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftSearchEntityRecipe].
class RaftSearchEntityRecipeStyle {
  const RaftSearchEntityRecipeStyle({
    required this.entity,
    required this.entityLeading,
    required this.entityIcon,
    required this.entityActivity,
    required this.entityContent,
    required this.entityHeader,
    required this.entityTitle,
    required this.entityDescription,
  });

  /// Slot `entity`.
  final RaftSlotStyle entity;

  /// Slot `entityLeading`.
  final RaftSlotStyle entityLeading;

  /// Slot `entityIcon`.
  final RaftSlotStyle entityIcon;

  /// Slot `entityActivity`.
  final RaftSlotStyle entityActivity;

  /// Slot `entityContent`.
  final RaftSlotStyle entityContent;

  /// Slot `entityHeader`.
  final RaftSlotStyle entityHeader;

  /// Slot `entityTitle`.
  final RaftSlotStyle entityTitle;

  /// Slot `entityDescription`.
  final RaftSlotStyle entityDescription;

  Map<String, RaftSlotStyle> get slots => {
    'entity': entity,
    'entityLeading': entityLeading,
    'entityIcon': entityIcon,
    'entityActivity': entityActivity,
    'entityContent': entityContent,
    'entityHeader': entityHeader,
    'entityTitle': entityTitle,
    'entityDescription': entityDescription,
  };
}

/// raft-ui recipe `searchEntity` (`src/components/search/search-entity.recipe.ts`, index.mjs:20466).
///
/// Used by: SearchEntityResult, SearchEntityResultActivity, SearchEntityResultContent, SearchEntityResultDescription, SearchEntityResultHeader, SearchEntityResultIcon, SearchEntityResultLeading, SearchEntityResultTitle.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftSearchEntityRecipe {
  static const String recipeName = 'searchEntity';
  static const List<String> slotNames = [
    'entity',
    'entityLeading',
    'entityIcon',
    'entityActivity',
    'entityContent',
    'entityHeader',
    'entityTitle',
    'entityDescription',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftSearchEntityRecipeStyle resolve({
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
    return RaftSearchEntityRecipeStyle(
      entity: s[0],
      entityLeading: s[1],
      entityIcon: s[2],
      entityActivity: s[3],
      entityContent: s[4],
      entityHeader: s[5],
      entityTitle: s[6],
      entityDescription: s[7],
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
    [
      1644,
      2597,
      3168,
      2331,
      1725,
      2695,
      3040,
      3125,
      878,
      896,
      868,
      2260,
      2288,
      598,
      610,
      1338,
      1346,
      1663,
      1672,
      1671,
      1666,
    ],
    [2804, 1644, 2902],
    [1644, 2920, 2331, 2336, 2679, 878, 892, 868, 2994],
    [586, 141, 128, 2319, 2912, 2902, 2845, 876, 892, 782],
    [2597, 1645],
    [1644, 2597, 2331, 1723],
    [3133, 3053, 1709, 2994, 1538],
    [874, 3133, 3073, 2998, 1537],
    [
      1644,
      2597,
      3168,
      2331,
      1725,
      2695,
      3040,
      2847,
      879,
      912,
      830,
      2899,
      3103,
      1626,
      2204,
      1339,
      1340,
      1344,
      1342,
      1343,
      1046,
      2672,
      1676,
      1689,
      1029,
      1083,
      1086,
      1084,
    ],
    [1644, 2920, 2331, 2336, 2679, 2848, 801, 3015],
    [586, 141, 128, 2319, 2912, 2902, 2845, 876, 909, 782, 1020],
    [3133, 3053, 1713, 3024, 1539],
    [874, 3133, 3073, 3019, 1539],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7],
    [8, 1, 9, 10, 4, 5, 11, 12],
  ];
}
