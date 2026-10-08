// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `search`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftSearchRecipe].
class RaftSearchRecipeStyle {
  const RaftSearchRecipeStyle({required this.frame, required this.filtersRow, required this.viewport, required this.summary, required this.section, required this.sectionHeading, required this.list});

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

  Map<String, RaftSlotStyle> get slots => {'frame': frame, 'filtersRow': filtersRow, 'viewport': viewport, 'summary': summary, 'section': section, 'sectionHeading': sectionHeading, 'list': list};
}

/// raft-ui recipe `search` (`src/components/search/search.recipe.ts`, index.mjs:20200).
///
/// Used by: SearchResultsList, SearchResultsSection, SearchResultsSectionHeading, SearchResultsSummary, SearchShellFilters, SearchShellRoot, SearchShellViewport, ThreadPanelSearch.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftSearchRecipe {
  static const String recipeName = 'search';
  static const List<String> slotNames = ['frame', 'filtersRow', 'viewport', 'summary', 'section', 'sectionHeading', 'list'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftSearchRecipeStyle resolve({required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name], states, tokens);
    return RaftSearchRecipeStyle(frame: s[0], filtersRow: s[1], viewport: s[2], summary: s[3], section: s[4], sectionHeading: s[5], list: s[6]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [1620, 1978, 2560, 1621, 1622, 856],
    [2867, 2755, 2767, 875, 876, 856],
    [2560, 1621, 2661, 2673, 856],
    [2494, 862, 2749, 3032, 1684, 3096, 3057, 2963],
    [2494],
    [2749, 2765, 1689, 2918, 1684, 3096, 3051, 2961],
    [1620, 1622, 1698],
    [1620, 1978, 2560, 1621, 1622, 820, 991],
    [2867, 2775, 3138, 873, 896, 825, 2753, 2765, 2440, 2443, 1002],
    [2560, 1621, 2661, 2673, 825, 1002, 2753, 2767, 2440, 2443],
    [2494, 862, 2749, 3032, 1688, 2981],
    [2494, 2807, 740, 2672, 2865, 993],
    [2765, 2747, 2731, 2684, 3032, 1688, 2981],
    [1620, 1622, 1697],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6], [7, 8, 9, 10, 11, 12, 13],
  ];
}
