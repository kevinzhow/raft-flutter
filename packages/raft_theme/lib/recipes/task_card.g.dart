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
      1678,
      1924,
      1832,
      1888,
      941,
      699,
      680,
      683,
      1051,
      1500,
      1501,
      1705,
      620,
      633,
      596,
      1592,
      1818,
      1734,
      700,
      698,
      676,
      679,
      1050,
    ],
    [965, 1481, 1320, 1022],
    [1481, 966],
    [965, 1481, 969, 1318, 1022, 1430],
    [1481, 1893, 1013, 1835, 1014, 1820],
    [1736, 1013, 1835, 1014, 1820],
    [
      1736,
      1304,
      1190,
      1318,
      1704,
      1653,
      1662,
      1308,
      1310,
      1013,
      1835,
      1014,
      1823,
    ],
    [1353, 1933, 1806, 1016, 1818, 1289],
    [1352, 1933, 1507, 1809, 1823, 1289],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8],
  ];
}
