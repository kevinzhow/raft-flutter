// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `taskBoardColumn`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftTaskBoardColumnRecipe].
class RaftTaskBoardColumnRecipeStyle {
  const RaftTaskBoardColumnRecipeStyle({
    required this.root,
    required this.trigger,
    required this.heading,
    required this.badge,
    required this.count,
    required this.chevron,
    required this.panel,
    required this.items,
    required this.empty,
    required this.emptyIdle,
    required this.emptyAllowed,
    required this.emptyBlocked,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `trigger`.
  final RaftSlotStyle trigger;

  /// Slot `heading`.
  final RaftSlotStyle heading;

  /// Slot `badge`.
  final RaftSlotStyle badge;

  /// Slot `count`.
  final RaftSlotStyle count;

  /// Slot `chevron`.
  final RaftSlotStyle chevron;

  /// Slot `panel`.
  final RaftSlotStyle panel;

  /// Slot `items`.
  final RaftSlotStyle items;

  /// Slot `empty`.
  final RaftSlotStyle empty;

  /// Slot `emptyIdle`.
  final RaftSlotStyle emptyIdle;

  /// Slot `emptyAllowed`.
  final RaftSlotStyle emptyAllowed;

  /// Slot `emptyBlocked`.
  final RaftSlotStyle emptyBlocked;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'trigger': trigger,
    'heading': heading,
    'badge': badge,
    'count': count,
    'chevron': chevron,
    'panel': panel,
    'items': items,
    'empty': empty,
    'emptyIdle': emptyIdle,
    'emptyAllowed': emptyAllowed,
    'emptyBlocked': emptyBlocked,
  };
}

/// raft-ui recipe `taskBoardColumn` (`src/components/task-board/task-board-column.recipe.ts`, index.mjs:14619).
///
/// Used by: TaskBoardColumn, TaskBoardColumnBadge, TaskBoardColumnChevron, TaskBoardColumnCount, TaskBoardColumnEmpty, TaskBoardColumnEmptyAllowed, TaskBoardColumnEmptyBlocked, TaskBoardColumnEmptyIdle, TaskBoardColumnHeading, TaskBoardColumnItems, TaskBoardColumnPanel, TaskBoardColumnTrigger.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftTaskBoardColumnRecipe {
  static const String recipeName = 'taskBoardColumn';
  static const List<String> slotNames = [
    'root',
    'trigger',
    'heading',
    'badge',
    'count',
    'chevron',
    'panel',
    'items',
    'empty',
    'emptyIdle',
    'emptyAllowed',
    'emptyBlocked',
  ];
  static const List<RaftRecipeAxis> axes = [];

  static RaftTaskBoardColumnRecipeStyle resolve({
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
    return RaftTaskBoardColumnRecipeStyle(
      root: s[0],
      trigger: s[1],
      heading: s[2],
      badge: s[3],
      count: s[4],
      chevron: s[5],
      panel: s[6],
      items: s[7],
      empty: s[8],
      emptyIdle: s[9],
      emptyAllowed: s[10],
      emptyBlocked: s[11],
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
    [1049, 965, 1736, 1727, 967, 1911, 1163, 1705, 1588, 687, 688],
    [
      1049,
      965,
      1924,
      1865,
      1318,
      1322,
      1832,
      1573,
      1476,
      1022,
      1706,
      1015,
      1817,
      1007,
      1823,
      730,
      995,
    ],
    [965, 1481, 1318, 1022],
    [1304, 1318, 1022, 1588, 1015, 1817, 1007, 1823, 177],
    [1013, 1835, 1014, 1820],
    [1304, 1736, 104, 1318, 1892, 279, 1119, 1501, 1820, 1130],
    [846],
    [965, 967, 1022],
    [
      1656,
      1053,
      965,
      1470,
      1318,
      1323,
      1669,
      1705,
      620,
      626,
      634,
      1812,
      1817,
      1820,
      1056,
    ],
    [1053, 1055],
    [1264, 1052],
    [1264, 1054],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
  ];
}
