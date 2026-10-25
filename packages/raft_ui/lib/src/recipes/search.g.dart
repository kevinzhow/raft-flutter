// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
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

/// raft-ui recipe `search` (`src/components/search/search.recipe.ts`, index.mjs:20349).
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
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftSearchRecipeStyle resolve({
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
    [1644, 1980, 2583, 1645, 1646, 868],
    [2902, 2783, 2796, 891, 892, 868],
    [2583, 1645, 2684, 2696, 868],
    [2515, 874, 2777, 3073, 1709, 3137, 3098, 3000],
    [2515],
    [2777, 2794, 1714, 2956, 1709, 3137, 3092, 2998],
    [1644, 1646, 1723],
    [1644, 1980, 2583, 1645, 1646, 825, 1011],
    [2902, 2804, 3179, 889, 912, 830, 2781, 2794, 2460, 2463, 1022],
    [2583, 1645, 2684, 2696, 830, 1022, 2781, 2796, 2460, 2463],
    [2515, 874, 2777, 3073, 1713, 3018],
    [2515, 2837, 746, 2695, 2899, 1013],
    [2794, 2775, 2756, 2707, 3073, 1713, 3018],
    [1644, 1646, 1722],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6],
    [7, 8, 9, 10, 11, 12, 13],
  ];
}
