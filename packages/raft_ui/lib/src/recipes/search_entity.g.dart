// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `searchEntity`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftSearchEntityRecipe].
class RaftSearchEntityRecipeStyle {
  const RaftSearchEntityRecipeStyle({required this.entity, required this.entityLeading, required this.entityIcon, required this.entityActivity, required this.entityContent, required this.entityHeader, required this.entityTitle, required this.entityDescription});

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

  Map<String, RaftSlotStyle> get slots => {'entity': entity, 'entityLeading': entityLeading, 'entityIcon': entityIcon, 'entityActivity': entityActivity, 'entityContent': entityContent, 'entityHeader': entityHeader, 'entityTitle': entityTitle, 'entityDescription': entityDescription};
}

/// raft-ui recipe `searchEntity` (`src/components/search/search-entity.recipe.ts`, index.mjs:20317).
///
/// Used by: SearchEntityResult, SearchEntityResultActivity, SearchEntityResultContent, SearchEntityResultDescription, SearchEntityResultHeader, SearchEntityResultIcon, SearchEntityResultLeading, SearchEntityResultTitle.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftSearchEntityRecipe {
  static const String recipeName = 'searchEntity';
  static const List<String> slotNames = ['entity', 'entityLeading', 'entityIcon', 'entityActivity', 'entityContent', 'entityHeader', 'entityTitle', 'entityDescription'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftSearchEntityRecipeStyle resolve({required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name], states, tokens);
    return RaftSearchEntityRecipeStyle(entity: s[0], entityLeading: s[1], entityIcon: s[2], entityActivity: s[3], entityContent: s[4], entityHeader: s[5], entityTitle: s[6], entityDescription: s[7]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [1620, 2574, 3127, 2312, 1700, 2672, 3003, 3084, 866, 880, 856, 2241, 2269, 592, 604, 1316, 1324, 1639, 1648, 1647, 1642],
    [2775, 1620, 2867],
    [1620, 2885, 2312, 2317, 2656, 866, 876, 856, 2956],
    [580, 141, 128, 2300, 2877, 2867, 2815, 864, 876, 776],
    [2574, 1621],
    [1620, 2574, 2312, 1698],
    [3092, 3017, 1684, 2956, 1514],
    [862, 3092, 3032, 2961, 1513],
    [1620, 2574, 3127, 2312, 1700, 2672, 3003, 2817, 867, 896, 825, 2865, 3062, 1602, 2185, 1317, 1318, 1322, 1320, 1321, 1026, 2649, 1652, 1665, 1009, 1063, 1066, 1064],
    [1620, 2885, 2312, 2317, 2656, 2818, 795, 2978],
    [580, 141, 128, 2300, 2877, 2867, 2815, 864, 893, 776, 1000],
    [3092, 3017, 1688, 2987, 1515],
    [862, 3092, 3032, 2982, 1515],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7], [8, 1, 9, 10, 4, 5, 11, 12],
  ];
}
