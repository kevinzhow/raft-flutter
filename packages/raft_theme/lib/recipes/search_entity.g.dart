// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
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

/// raft-ui recipe `searchEntity` (`src/components/search/search-entity.recipe.ts`, index.mjs:16437).
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
      965,
      1484,
      1929,
      1319,
      1025,
      1596,
      1836,
      1893,
      1682,
      1714,
      621,
      615,
      1662,
      1673,
      1822,
      1738,
      1385,
      1543,
      1550,
      1549,
      1548,
      1546,
      1545,
      1272,
      427,
      927,
      929,
      921,
      738,
      743,
      1577,
      979,
      980,
    ],
    [1682, 965, 1740],
    [965, 1319, 1324, 1583, 1764, 1716, 581, 1827, 279],
    [422, 1304, 1740, 1692, 648, 1768, 1704, 622, 637, 606, 1736],
    [1484, 966, 965, 967, 1020],
    [965, 1484, 1319, 1023],
    [1897, 1016, 1810, 1017, 1822, 877],
    [618, 1897, 1813, 1827, 877],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7],
  ];
}
