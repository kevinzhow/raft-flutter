// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `taskCard`.
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

/// raft-ui recipe `taskCard` (`dist/components/task-card/task-card.recipe.mjs`, index.mjs:20805).
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
      2433,
      2725,
      2613,
      2674,
      1365,
      1035,
      1012,
      1015,
      1508,
      2137,
      2138,
      2462,
      939,
      953,
      911,
      2264,
      2598,
      2497,
      1036,
      1034,
      1008,
      1011,
      1507,
    ],
    [1400, 2116, 1866, 1466],
    [2116, 1401],
    [1400, 2116, 1406, 1864, 1466, 1989],
    [2116, 2681, 1454, 2616, 1455, 2600],
    [2499, 1454, 2616, 1455, 2600],
    [
      2499,
      1847,
      1666,
      1864,
      2461,
      2400,
      2412,
      1851,
      1854,
      1454,
      2616,
      1455,
      2603,
    ],
    [1902, 2734, 2585, 1457, 2598, 1802],
    [1901, 2734, 2145, 2587, 2603, 1802],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8],
  ];
}
