// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `webDialogCard`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `presentation` axis of `webDialogCard` (default `centered`).
enum RaftWebDialogCardRecipePresentation {
  centered('centered'),
  sheet('sheet');

  const RaftWebDialogCardRecipePresentation(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftWebDialogCardRecipe].
class RaftWebDialogCardRecipeStyle {
  const RaftWebDialogCardRecipeStyle({
    required this.root,
    required this.header,
    required this.scrollArea,
    required this.body,
    required this.description,
    required this.title,
    required this.close,
    required this.defaultWidth,
    required this.glyph,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `header`.
  final RaftSlotStyle header;

  /// Slot `scrollArea`.
  final RaftSlotStyle scrollArea;

  /// Slot `body`.
  final RaftSlotStyle body;

  /// Slot `description`.
  final RaftSlotStyle description;

  /// Slot `title`.
  final RaftSlotStyle title;

  /// Slot `close`.
  final RaftSlotStyle close;

  /// Slot `defaultWidth`.
  final RaftSlotStyle defaultWidth;

  /// Slot `glyph`.
  final RaftSlotStyle glyph;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'header': header,
    'scrollArea': scrollArea,
    'body': body,
    'description': description,
    'title': title,
    'close': close,
    'defaultWidth': defaultWidth,
    'glyph': glyph,
  };
}

/// raft-ui recipe `webDialogCard` (`Web src/components/ui/DialogCard.tsx sha256:142ce8f1b1bbe562da01e14b546362a47409a28bcb28a1638f11f0dc328b529d; src/components/ui/headEdges.ts sha256:aa41d09b463a41ad21f74f21ac0268c502181f553505e06637c22361f0b48d5d; src/components/ui/NarrowDialog.tsx sha256:88cb9e1726cf025bc6694d58ae50c33c1c9c4dbb40a6410cc7cbb7dbd231026c; src/components/ui/narrowSheet.ts sha256:e02d2104a8eecac4aaed307f3440e2524207de8d25e02eef1b81d8d2ab7345b4`, index.mjs:1).
///
/// Used by: DialogCard.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftWebDialogCardRecipe {
  static const String recipeName = 'webDialogCard';
  static const List<String> slotNames = [
    'root',
    'header',
    'scrollArea',
    'body',
    'description',
    'title',
    'close',
    'defaultWidth',
    'glyph',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('presentation', ['centered', 'sheet'], 'centered', false),
    RaftRecipeAxis('description', ['true', 'false'], 'false', false),
  ];

  static RaftWebDialogCardRecipeStyle resolve({
    RaftWebDialogCardRecipePresentation? presentation,
    bool? description,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [presentation?.css, description?.toString()],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftWebDialogCardRecipeStyle(
      root: s[0],
      header: s[1],
      scrollArea: s[2],
      body: s[3],
      description: s[4],
      title: s[5],
      close: s[6],
      defaultWidth: s[7],
      glyph: s[8],
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
      1399,
      2642,
      1897,
      2741,
      1400,
      2717,
      190,
      1404,
      1921,
      2247,
      2251,
      2464,
      915,
      2598,
      2496,
      2445,
      2449,
      1982,
    ],
    [1400, 1866, 1868, 1466],
    [2098, 1401],
    [1400, 2116, 1404, 2266, 2056],
    [1907, 1456, 2622, 2603, 1991, 2145],
    [1907, 1449, 2116, 1456, 2609, 2598],
    [179, 175, 2012, 2499],
    [1982],
    [2526],
    [1991, 1400, 1866, 1868, 1466],
    [],
    [
      2741,
      1399,
      1858,
      2649,
      965,
      1895,
      1668,
      1923,
      2725,
      1983,
      2679,
      2251,
      2468,
      2472,
      915,
      2496,
      2445,
      2449,
      2163,
      1400,
      1404,
      2598,
      2247,
      2368,
      2310,
      400,
      399,
      398,
      397,
      289,
      287,
      293,
      288,
      286,
      291,
      292,
      290,
      1313,
      1311,
      1314,
    ],
    [
      1400,
      1639,
      2499,
      1864,
      1468,
      1937,
      2394,
      265,
      267,
      942,
      954,
      910,
      2598,
      1947,
      1950,
      1951,
    ],
    [2405, 2384, 2288],
    [1907, 1456, 2622, 2603, 1990],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8],
    [0, 9, 2, 3, 10, 5, 6, 7, 8],
    [11, 12, 2, 13, 14, 5, 6, 7, 8],
    [11, 12, 2, 13, 10, 5, 6, 7, 8],
  ];
}
