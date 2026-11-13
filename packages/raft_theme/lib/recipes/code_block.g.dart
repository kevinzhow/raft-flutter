// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `codeBlock`.
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

/// raft-ui recipe `codeBlock` (`dist/components/code-block/code-block.recipe.mjs`, index.mjs:11332).
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
  static const List<RaftRecipeAxis> axes = [];

  static RaftCodeBlockRecipeStyle resolve({
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
    [1599, 2433, 2159, 2116, 507, 2251, 2397, 2272, 2462, 939, 953, 912, 2598],
    [1400, 1631, 1864, 1466, 942, 953, 2367, 2300, 1454, 2616, 2600],
    [2116, 1401, 2681, 1454, 2616],
    [2132, 1400, 1864, 1464, 631, 635, 636, 632, 634, 633],
    [2346, 691, 2747, 2507, 1119, 1118, 1116, 1117, 1776],
    [
      2433,
      1489,
      2116,
      1495,
      1866,
      85,
      2265,
      1454,
      440,
      439,
      436,
      437,
      2403,
      2417,
      2615,
      2598,
      441,
      999,
    ],
    [
      1847,
      2499,
      1864,
      1869,
      2666,
      1432,
      2522,
      2461,
      2082,
      2077,
      2598,
      1785,
      697,
      1435,
      1439,
      461,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6],
  ];
}
