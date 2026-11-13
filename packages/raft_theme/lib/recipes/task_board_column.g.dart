// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `taskBoardColumn`.
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

/// raft-ui recipe `taskBoardColumn` (`dist/components/task-board/task-board-column.recipe.mjs`, index.mjs:20567).
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
    [1503, 1400, 2499, 2489, 1404, 2712, 1628, 2462, 2260, 1019, 1020],
    [
      1503,
      1400,
      2725,
      2650,
      1864,
      1868,
      2613,
      2247,
      2107,
      2052,
      1466,
      2463,
      1456,
      2597,
      1449,
      2603,
      1059,
      1439,
    ],
    [1400, 2116, 1864, 1466],
    [1847, 1864, 1466, 2260, 1456, 2597, 1449, 2603, 348],
    [1454, 2616, 1455, 2600],
    [1847, 2499, 187, 1864, 2678, 477, 1571, 2138, 2600, 1590],
    [1198],
    [1400, 1404, 1466],
    [
      2403,
      1510,
      1400,
      2102,
      1864,
      1869,
      2419,
      2462,
      939,
      945,
      954,
      2590,
      2597,
      2600,
      1513,
    ],
    [1510, 1512],
    [1776, 1509],
    [1776, 1511],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
  ];
}
