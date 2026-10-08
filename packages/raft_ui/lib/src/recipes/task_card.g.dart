// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `taskCard`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftTaskCardRecipe].
class RaftTaskCardRecipeStyle {
  const RaftTaskCardRecipeStyle({required this.root, required this.row, required this.body, required this.meta, required this.channel, required this.number, required this.legacy, required this.title, required this.description});

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

  Map<String, RaftSlotStyle> get slots => {'root': root, 'row': row, 'body': body, 'meta': meta, 'channel': channel, 'number': number, 'legacy': legacy, 'title': title, 'description': description};
}

/// raft-ui recipe `taskCard` (`src/components/task-card/task-card.recipe.ts`, index.mjs:18323).
///
/// Used by: TaskCard, TaskCardBody, TaskCardChannel, TaskCardDescription, TaskCardLegacy, TaskCardMeta, TaskCardNumber, TaskCardRow, TaskCardTitle.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftTaskCardRecipe {
  static const String recipeName = 'taskCard';
  static const List<String> slotNames = ['root', 'row', 'body', 'meta', 'channel', 'number', 'legacy', 'title', 'description'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftTaskCardRecipeStyle resolve({required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name], states, tokens);
    return RaftTaskCardRecipeStyle(root: s[0], row: s[1], body: s[2], meta: s[3], channel: s[4], number: s[5], legacy: s[6], title: s[7], description: s[8]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [2775, 3127, 2753, 2766, 3003, 3083, 1601, 1237, 1201, 1200, 1208, 1730, 1729, 2592, 2593, 866, 900, 825, 2863, 2176, 2268],
    [1620, 2574, 2314, 1698],
    [2574, 1621],
    [2492, 1620, 2574, 2312, 1698, 1624],
    [3032, 2333, 2574, 3092, 1684, 2993],
    [2867, 2920, 1689, 2989],
    [2867, 2750, 2761, 2918, 864, 896, 1687, 1684, 2992],
    [2356, 3136, 3017, 2335, 1684, 2987],
    [2600, 2355, 3136, 3032, 2333, 2995],
    [2775, 3127, 2753, 2766, 3003, 3083, 1601, 1237, 1201, 1200, 1208, 1730, 1729, 2592, 2593, 2817, 867, 896, 825, 2865, 2185, 1731, 1236, 1009],
    [2492, 1620, 2574, 1624, 2312, 1697],
    [3032, 2333, 2574, 3092, 1688, 2981],
    [2867, 2920, 1691, 2332, 1688, 2911, 2984],
    [2867, 2750, 2761, 2918, 2822, 864, 896, 795, 1691, 2331, 1688, 3052, 2981],
    [2356, 3136, 3017, 2335, 1688, 2976],
    [2600, 2355, 3136, 2924, 2334, 2981],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8], [9, 1, 2, 10, 11, 12, 13, 14, 15],
  ];
}
