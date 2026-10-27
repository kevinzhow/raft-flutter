// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `taskCard`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftTaskCardRecipe].
class RaftTaskCardRecipeStyle {
  const RaftTaskCardRecipeStyle({
    required this.root,
    required this.row,
    required this.body,
    required this.meta,
    required this.channel,
    required this.number,
    required this.legacy,
    required this.title,
    required this.description,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `row`.
  final RaftSlotStyle row;

  /// Slot `body`.
  final RaftSlotStyle body;

  /// Slot `meta`.
  final RaftSlotStyle meta;

  /// Slot `channel`.
  final RaftSlotStyle channel;

  /// Slot `number`.
  final RaftSlotStyle number;

  /// Slot `legacy`.
  final RaftSlotStyle legacy;

  /// Slot `title`.
  final RaftSlotStyle title;

  /// Slot `description`.
  final RaftSlotStyle description;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'row': row,
    'body': body,
    'meta': meta,
    'channel': channel,
    'number': number,
    'legacy': legacy,
    'title': title,
    'description': description,
  };
}

/// raft-ui recipe `taskCard` (`src/components/task-card/task-card.recipe.ts`, index.mjs:14856).
///
/// Used by: TaskCard, TaskCardBody, TaskCardChannel, TaskCardDescription, TaskCardLegacy, TaskCardMeta, TaskCardNumber, TaskCardRow, TaskCardTitle.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftTaskCardRecipe {
  static const String recipeName = 'taskCard';
  static const List<String> slotNames = [
    'root',
    'row',
    'body',
    'meta',
    'channel',
    'number',
    'legacy',
    'title',
    'description',
  ];
  static const List<RaftRecipeAxis> axes = [];

  static RaftTaskCardRecipeStyle resolve({
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
    return RaftTaskCardRecipeStyle(
      root: s[0],
      row: s[1],
      body: s[2],
      meta: s[3],
      channel: s[4],
      number: s[5],
      legacy: s[6],
      title: s[7],
      description: s[8],
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
      1680,
      1926,
      1834,
      1890,
      941,
      699,
      680,
      683,
      1052,
      1502,
      1503,
      1707,
      620,
      633,
      596,
      1594,
      1820,
      1736,
      700,
      698,
      676,
      679,
      1051,
    ],
    [965, 1483, 1321, 1023],
    [1483, 966],
    [965, 1483, 969, 1319, 1023, 1432],
    [1483, 1895, 1014, 1837, 1015, 1822],
    [1738, 1014, 1837, 1015, 1822],
    [
      1738,
      1305,
      1191,
      1319,
      1706,
      1655,
      1664,
      1309,
      1311,
      1014,
      1837,
      1015,
      1825,
    ],
    [1354, 1935, 1808, 1017, 1820, 1290],
    [1353, 1935, 1509, 1811, 1825, 1290],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8],
  ];
}
