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
    [965, 1197, 1465, 966, 967, 595, 1818],
    [1736, 623, 634, 595, 1658, 1669],
    [1465, 966, 1583, 1593, 595, 1650, 1638, 1604],
    [618, 1427, 1658, 1641, 1015, 1817, 1820],
    [1427],
    [1667, 965, 1318, 1022, 1658, 1645, 1602, 1015, 1817, 1007, 1820],
    [965, 967, 1018],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6],
  ];
}
