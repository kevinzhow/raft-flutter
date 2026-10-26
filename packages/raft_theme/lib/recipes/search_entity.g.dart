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
      1481,
      1924,
      1318,
      1024,
      1592,
      1832,
      1889,
      1678,
      1710,
      621,
      615,
      1658,
      1669,
      1818,
      1734,
      1383,
      1539,
      1546,
      1545,
      1544,
      1542,
      1541,
      1271,
      427,
      927,
      929,
      921,
      738,
      743,
      1573,
      979,
      980,
    ],
    [1678, 965, 1736],
    [965, 1318, 1323, 1579, 1760, 1712, 581, 1823, 279],
    [422, 1303, 1736, 1688, 648, 1764, 1700, 622, 637, 606, 1732],
    [1481, 966, 965, 967, 1019],
    [965, 1481, 1318, 1022],
    [1893, 1015, 1806, 1016, 1818, 877],
    [618, 1893, 1809, 1823, 877],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7],
  ];
}
