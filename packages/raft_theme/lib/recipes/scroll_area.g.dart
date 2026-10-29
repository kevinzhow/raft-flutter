// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
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

/// raft-ui recipe `scrollArea` (`src/components/scroll-area/scroll-area.recipe.ts`, index.mjs:2548).
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
  static const List<RaftRecipeAxis> axes = [];

  static RaftScrollAreaRecipeStyle resolve({
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
    [1682, 1468],
    [1770, 1468, 1589, 1577, 420, 380],
    [1483],
    [
      1156,
      1944,
      965,
      1870,
      1727,
      1593,
      1558,
      1894,
      942,
      1630,
      900,
      899,
      898,
      725,
      723,
      715,
      711,
      717,
    ],
    [1682, 1060, 1059, 1704, 588, 1273],
    [615],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5],
  ];
}
