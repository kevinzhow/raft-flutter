// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
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

/// raft-ui recipe `codeBlock` (`src/components/code-block/code-block.recipe.ts`, index.mjs:6670).
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
    [1138, 1678, 1520, 1481, 301, 1578, 1650, 1598, 1705, 620, 633, 599, 1818],
    [965, 1164, 1318, 1022, 623, 633, 1630, 1616, 1013, 1835, 1820],
    [1481, 966, 1893, 1013, 1835],
    [1495, 965, 1318, 1022, 395, 397, 396, 398],
    [1626, 422, 1936, 1740, 793, 792, 790, 791, 1264],
    [1678, 1481, 1581, 1593, 1013, 1656, 1667, 1834, 1818, 246, 666],
    [
      1304,
      1736,
      1318,
      1323,
      1881,
      986,
      1753,
      1706,
      1818,
      1271,
      427,
      991,
      995,
      266,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6],
  ];
}
