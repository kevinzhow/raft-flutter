// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `copyableCode`.
// ignore_for_file: type=lint

import '../recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `size` axis of `copyableCode` (default `md`).
enum RaftCopyableCodeRecipeSize {
  sm('sm'),
  md('md');

  const RaftCopyableCodeRecipeSize(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftCopyableCodeRecipe].
class RaftCopyableCodeRecipeStyle {
  const RaftCopyableCodeRecipeStyle({
    required this.root,
    required this.code,
    required this.codeInner,
    required this.action,
    required this.iconSwap,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `code`.
  final RaftSlotStyle code;

  /// Slot `codeInner`.
  final RaftSlotStyle codeInner;

  /// Slot `action`.
  final RaftSlotStyle action;

  /// Slot `iconSwap`.
  final RaftSlotStyle iconSwap;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'code': code,
    'codeInner': codeInner,
    'action': action,
    'iconSwap': iconSwap,
  };
}

/// raft-ui recipe `copyableCode` (`src/components/copyable-code/copyable-code.tsx`, index.mjs:2415).
///
/// Used by: CopyableCode, CopyableCodeAction, CopyableCodeRoot.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftCopyableCodeRecipe {
  static const String recipeName = 'copyableCode';
  static const List<String> slotNames = [
    'root',
    'code',
    'codeInner',
    'action',
    'iconSwap',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
    RaftRecipeAxis('size', ['sm', 'md'], 'md', false),
  ];

  static RaftCopyableCodeRecipeStyle resolve({
    required RaftRecipeTheme theme,
    RaftCopyableCodeRecipeSize? size,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [theme.name, size?.css],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftCopyableCodeRecipeStyle(
      root: s[0],
      code: s[1],
      codeInner: s[2],
      action: s[3],
      iconSwap: s[4],
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
    [1918, 1644, 3168, 2597, 2331, 1723],
    [2597, 1645, 1714, 3073, 878, 916, 769, 2984, 2897, 2781, 2792, 2354],
    [874, 3168, 2597, 2505, 945],
    [2902, 22, 13, 376],
    [
      2804,
      2321,
      2913,
      25,
      29,
      28,
      30,
      26,
      27,
      31,
      2609,
      1388,
      1387,
      1389,
      1386,
      1385,
      1384,
      1379,
      1378,
      1383,
      1382,
      1381,
      1380,
    ],
    [2597, 1645, 1714, 3073, 878, 916, 769, 2984, 2897, 2781, 2794, 2354],
    [
      2597,
      1645,
      1714,
      3073,
      829,
      2978,
      2823,
      2825,
      1151,
      1168,
      2354,
      2779,
      2789,
    ],
    [
      874,
      3168,
      2597,
      2505,
      945,
      934,
      902,
      905,
      1025,
      830,
      2777,
      987,
      2792,
      2354,
    ],
    [2902, 22, 13, 376, 21, 19, 16, 18, 14],
    [
      874,
      3168,
      2597,
      2505,
      945,
      934,
      902,
      905,
      1025,
      830,
      2777,
      987,
      2794,
      2354,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4],
    [0, 5, 2, 3, 4],
    [0, 6, 7, 8, 4],
    [0, 6, 9, 8, 4],
  ];
}
