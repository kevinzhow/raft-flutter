// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `codeBlock`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftCodeBlockRecipe].
class RaftCodeBlockRecipeStyle {
  const RaftCodeBlockRecipeStyle({
    required this.root,
    required this.header,
    required this.title,
    required this.actions,
    required this.corner,
    required this.body,
    required this.action,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `header`.
  final RaftSlotStyle header;

  /// Slot `title`.
  final RaftSlotStyle title;

  /// Slot `actions`.
  final RaftSlotStyle actions;

  /// Slot `corner`.
  final RaftSlotStyle corner;

  /// Slot `body`.
  final RaftSlotStyle body;

  /// Slot `action`.
  final RaftSlotStyle action;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'header': header,
    'title': title,
    'actions': actions,
    'corner': corner,
    'body': body,
    'action': action,
  };
}

/// raft-ui recipe `codeBlock` (`src/components/code-block/code-block.recipe.ts`, index.mjs:8510).
///
/// Used by: CodeBlock, CodeBlockAction, CodeBlockActions, CodeBlockBody, CodeBlockHeader, CodeBlockTitle.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftCodeBlockRecipe {
  static const String recipeName = 'codeBlock';
  static const List<String> slotNames = [
    'root',
    'header',
    'title',
    'actions',
    'corner',
    'body',
    'action',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftCodeBlockRecipeStyle resolve({
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
    return RaftCodeBlockRecipeStyle(
      root: s[0],
      header: s[1],
      title: s[2],
      actions: s[3],
      corner: s[4],
      body: s[5],
      action: s[6],
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
    [1916, 2804, 2631, 2597, 472, 2775, 2702, 878, 916, 769, 2897],
    [1644, 1943, 2331, 1725, 2781, 3053, 1709, 3096, 3016, 3137],
    [2597, 1645, 3133, 1714, 3073, 722, 729, 710],
    [2608, 1644, 2331, 1723, 572, 574, 573, 575],
    [
      2739,
      586,
      3180,
      2904,
      1405,
      1403,
      1399,
      1401,
      903,
      1404,
      1402,
      1398,
      1400,
    ],
    [2804, 2597, 2681, 2696, 1714, 3053, 769, 2984, 2667, 140, 2670, 408],
    [
      2320,
      2902,
      2331,
      2336,
      3114,
      1669,
      1677,
      2918,
      808,
      3017,
      2234,
      2297,
      1681,
    ],
    [
      1916,
      2804,
      2631,
      2597,
      471,
      2678,
      2849,
      2781,
      2702,
      829,
      2823,
      2825,
      1151,
    ],
    [
      1644,
      1943,
      2331,
      1725,
      2780,
      934,
      889,
      902,
      905,
      1025,
      830,
      3054,
      1713,
      3018,
      1022,
    ],
    [2597, 1645, 3133, 1714, 3073],
    [2739, 586, 3180, 2904, 1405, 1403, 1399, 1401, 2189],
    [
      2804,
      2597,
      2681,
      2696,
      1714,
      3053,
      2796,
      2750,
      2723,
      2364,
      830,
      3013,
      987,
      934,
      902,
      905,
      1025,
      409,
      973,
    ],
    [2320, 2902, 2331, 2336, 3114, 1669, 1677],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6],
    [7, 8, 9, 3, 10, 11, 12],
  ];
}
