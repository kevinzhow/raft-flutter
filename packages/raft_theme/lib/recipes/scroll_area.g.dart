// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `scrollArea`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftScrollAreaRecipe].
class RaftScrollAreaRecipeStyle {
  const RaftScrollAreaRecipeStyle({
    required this.root,
    required this.viewport,
    required this.content,
    required this.scrollbar,
    required this.thumb,
    required this.corner,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `viewport`.
  final RaftSlotStyle viewport;

  /// Slot `content`.
  final RaftSlotStyle content;

  /// Slot `scrollbar`.
  final RaftSlotStyle scrollbar;

  /// Slot `thumb`.
  final RaftSlotStyle thumb;

  /// Slot `corner`.
  final RaftSlotStyle corner;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'viewport': viewport,
    'content': content,
    'scrollbar': scrollbar,
    'thumb': thumb,
    'corner': corner,
  };
}

/// raft-ui recipe `scrollArea` (`src/components/scroll-area/scroll-area.recipe.ts`, index.mjs:3065).
///
/// Used by: ScrollArea, ScrollAreaContent, ScrollAreaCorner, ScrollAreaScrollbar, ScrollAreaThumb, ScrollAreaViewport.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftScrollAreaRecipe {
  static const String recipeName = 'scrollArea';
  static const List<String> slotNames = [
    'root',
    'viewport',
    'content',
    'scrollbar',
    'thumb',
    'corner',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftScrollAreaRecipeStyle resolve({
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
    return RaftScrollAreaRecipeStyle(
      root: s[0],
      viewport: s[1],
      content: s[2],
      scrollbar: s[3],
      thumb: s[4],
      corner: s[5],
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
    [2804, 2583],
    [2925, 2583, 2687, 2672, 583, 560],
    [2595],
    [
      1931,
      3183,
      1644,
      3086,
      2868,
      2692,
      2649,
      3126,
      1626,
      2739,
      1584,
      1583,
      1582,
      1320,
      1317,
      1307,
      1303,
      1309,
    ],
    [2804, 2845, 1778, 1777, 773, 2213],
    [863],
    [2804, 2845, 1778, 1777, 809, 2235],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5],
    [0, 1, 2, 3, 6, 5],
  ];
}
