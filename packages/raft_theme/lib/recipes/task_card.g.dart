// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
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

/// raft-ui recipe `taskCard` (`src/components/task-card/task-card.recipe.ts`, index.mjs:18460).
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
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftTaskCardRecipeStyle resolve({
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
      2804,
      3168,
      2781,
      2795,
      3040,
      3124,
      1625,
      1259,
      1220,
      1219,
      1227,
      1755,
      1754,
      2615,
      2616,
      878,
      916,
      830,
      2897,
      2191,
      2287,
    ],
    [1644, 2597, 2333, 1723],
    [2597, 1645],
    [2513, 1644, 2597, 2331, 1723, 1648],
    [3073, 2352, 2597, 3133, 1709, 3030],
    [2902, 2958, 1714, 3026],
    [2902, 2778, 2790, 2956, 876, 912, 1712, 1709, 3029],
    [2375, 3177, 3053, 2354, 1709, 3024],
    [2623, 2374, 3177, 3073, 2352, 3032],
    [
      2804,
      3168,
      2781,
      2795,
      3040,
      3124,
      1625,
      1259,
      1220,
      1219,
      1227,
      1755,
      1754,
      2615,
      2616,
      2847,
      879,
      912,
      830,
      2899,
      2204,
      1756,
      1258,
      1029,
    ],
    [2513, 1644, 2597, 1648, 2331, 1722],
    [3073, 2352, 2597, 3133, 1713, 3018],
    [2902, 2958, 1716, 2351, 1713, 2946, 3021],
    [2902, 2778, 2790, 2956, 2852, 876, 912, 801, 1716, 2350, 1713, 3093, 3018],
    [2375, 3177, 3053, 2354, 1713, 3013],
    [2623, 2374, 3177, 2962, 2353, 3018],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8],
    [9, 1, 2, 10, 11, 12, 13, 14, 15],
  ];
}
