// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `searchEntity`.
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

/// raft-ui recipe `searchEntity` (`dist/components/search/search-entity.recipe.mjs`, index.mjs:24441).
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
  static const List<RaftRecipeAxis> axes = [];

  static RaftSearchEntityRecipeStyle resolve({
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
      1400,
      2116,
      2725,
      1864,
      1468,
      2613,
      2468,
      940,
      2419,
      2598,
      2073,
      2336,
      2342,
      1904,
      2433,
      1862,
      933,
      2497,
      2247,
      503,
      504,
      505,
      2017,
      502,
      2366,
      2308,
      849,
      810,
      872,
      820,
      828,
      840,
      850,
      841,
      853,
      821,
      865,
      830,
      831,
      2183,
      2182,
      694,
      2180,
      2181,
      1352,
      1064,
      1418,
      1419,
    ],
    [2433, 1400, 2499],
    [1400, 1864, 1869, 2252, 2528, 2461, 895, 2603, 477],
    [691, 1846, 2499, 2442, 970, 2532, 2457, 941, 958, 923, 2495],
    [2116, 1401, 1400, 1404, 1463],
    [1400, 2116, 1864, 1466],
    [2681, 1456, 2585, 1457, 2598, 1260],
    [937, 2681, 2587, 2603, 1260],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7],
  ];
}
