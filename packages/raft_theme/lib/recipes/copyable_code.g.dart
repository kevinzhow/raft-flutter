// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `copyableCode`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
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

/// raft-ui recipe `copyableCode` (`src/components/copyable-code/copyable-code.tsx`, index.mjs:2299).
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
    RaftRecipeAxis('size', ['sm', 'md'], 'md', false),
  ];

  static RaftCopyableCodeRecipeStyle resolve({
    RaftCopyableCodeRecipeSize? size,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [size?.css],
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
    [1141, 965, 1929, 1484, 1319, 1023],
    [1484, 966, 1014, 1710, 620, 633, 599, 1838, 1822, 1660, 1338, 1678],
    [618, 1929, 1484, 1424, 651],
    [1740, 8, 7, 221],
    [
      1682,
      1306,
      12,
      16,
      15,
      19,
      13,
      14,
      20,
      1500,
      783,
      782,
      784,
      781,
      780,
      779,
      774,
      773,
      778,
      777,
      776,
      775,
      1753,
      17,
      18,
    ],
    [1484, 966, 1014, 1710, 620, 633, 599, 1838, 1822, 1660, 1338, 1469, 1680],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4],
    [0, 5, 2, 3, 4],
  ];
}
