// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `scrollArea`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftScrollAreaRecipe].
class RaftScrollAreaRecipeStyle {
  const RaftScrollAreaRecipeStyle({required this.root, required this.viewport, required this.content, required this.scrollbar, required this.thumb, required this.corner});

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

  Map<String, RaftSlotStyle> get slots => {'root': root, 'viewport': viewport, 'content': content, 'scrollbar': scrollbar, 'thumb': thumb, 'corner': corner};
}

/// raft-ui recipe `scrollArea` (`src/components/scroll-area/scroll-area.recipe.ts`, index.mjs:3054).
///
/// Used by: ScrollArea, ScrollAreaContent, ScrollAreaCorner, ScrollAreaScrollbar, ScrollAreaThumb, ScrollAreaViewport.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftScrollAreaRecipe {
  static const String recipeName = 'scrollArea';
  static const List<String> slotNames = ['root', 'viewport', 'content', 'scrollbar', 'thumb', 'corner'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftScrollAreaRecipeStyle resolve({required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name], states, tokens);
    return RaftScrollAreaRecipeStyle(root: s[0], viewport: s[1], content: s[2], scrollbar: s[3], thumb: s[4], corner: s[5]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [2775, 2560],
    [2890, 2560, 2664, 2649, 578, 559],
    [2572],
    [1930, 3142, 1620, 3045, 2834, 2669, 2626, 3085, 1602, 2716, 1560, 1559, 1558, 1298, 1295, 1285, 1281, 1287],
    [2775, 2815, 1753, 1752, 767, 2194],
    [850],
    [2775, 2815, 1753, 1752, 803, 2216],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5], [0, 1, 2, 3, 6, 5],
  ];
}
