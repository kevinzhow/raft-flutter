// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `copyableCode`.
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

/// raft-ui recipe `copyableCode` (`dist/components/copyable-code/copyable-code.mjs`, index.mjs:4138).
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
    [1601, 1400, 2725, 2116, 1864, 1466],
    [2116, 1401, 1454, 2463, 939, 953, 912, 2615, 2598, 2403, 1883, 2425],
    [937, 2725, 2116, 1980, 977],
    [2499, 17, 11, 396],
    [
      2433,
      1848,
      21,
      25,
      24,
      28,
      22,
      23,
      29,
      2133,
      1108,
      1107,
      1109,
      1106,
      1105,
      1104,
      1099,
      1098,
      1103,
      1102,
      1101,
      1100,
      2517,
      26,
      27,
    ],
    [2116, 1401, 1454, 2463, 939, 953, 912, 2615, 2598, 2403, 1883, 2099, 2426],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4],
    [0, 5, 2, 3, 4],
  ];
}
