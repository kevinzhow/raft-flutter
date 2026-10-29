// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `search`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftSearchRecipe].
class RaftSearchRecipeStyle {
  const RaftSearchRecipeStyle({
    required this.frame,
    required this.filtersRow,
    required this.viewport,
    required this.summary,
    required this.section,
    required this.sectionHeading,
    required this.list,
  });

  /// Slot `frame`.
  final RaftSlotStyle frame;

  /// Slot `filtersRow`.
  final RaftSlotStyle filtersRow;

  /// Slot `viewport`.
  final RaftSlotStyle viewport;

  /// Slot `summary`.
  final RaftSlotStyle summary;

  /// Slot `section`.
  final RaftSlotStyle section;

  /// Slot `sectionHeading`.
  final RaftSlotStyle sectionHeading;

  /// Slot `list`.
  final RaftSlotStyle list;

  Map<String, RaftSlotStyle> get slots => {
    'frame': frame,
    'filtersRow': filtersRow,
    'viewport': viewport,
    'summary': summary,
    'section': section,
    'sectionHeading': sectionHeading,
    'list': list,
  };
}

/// raft-ui recipe `search` (`src/components/search/search.recipe.ts`, index.mjs:16347).
///
/// Used by: SearchResultsList, SearchResultsSection, SearchResultsSectionHeading, SearchResultsSummary, SearchShellFilters, SearchShellRoot, SearchShellViewport, ThreadPanelSearch.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftSearchRecipe {
  static const String recipeName = 'search';
  static const List<String> slotNames = [
    'frame',
    'filtersRow',
    'viewport',
    'summary',
    'section',
    'sectionHeading',
    'list',
  ];
  static const List<RaftRecipeAxis> axes = [];

  static RaftSearchRecipeStyle resolve({
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
    return RaftSearchRecipeStyle(
      frame: s[0],
      filtersRow: s[1],
      viewport: s[2],
      summary: s[3],
      section: s[4],
      sectionHeading: s[5],
      list: s[6],
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
    [965, 1198, 1468, 966, 967, 595, 1822],
    [1740, 623, 634, 595, 1662, 1673],
    [1468, 966, 1587, 1597, 595, 1654, 1642, 1608],
    [618, 1429, 1662, 1645, 1016, 1821, 1824],
    [1429],
    [1671, 965, 1319, 1023, 1662, 1649, 1606, 1016, 1821, 1008, 1824],
    [965, 967, 1019],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6],
  ];
}
