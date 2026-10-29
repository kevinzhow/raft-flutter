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
    [1050, 965, 1738, 1729, 967, 1913, 1164, 1707, 1590, 687, 688],
    [
      1050,
      965,
      1926,
      1867,
      1319,
      1323,
      1834,
      1575,
      1478,
      1023,
      1708,
      1016,
      1819,
      1008,
      1825,
      730,
      996,
    ],
    [965, 1483, 1319, 1023],
    [1305, 1319, 1023, 1590, 1016, 1819, 1008, 1825, 177],
    [1014, 1837, 1015, 1822],
    [1305, 1738, 104, 1319, 1894, 279, 1120, 1503, 1822, 1131],
    [846],
    [965, 967, 1023],
    [
      1658,
      1054,
      965,
      1472,
      1319,
      1324,
      1671,
      1707,
      620,
      626,
      634,
      1814,
      1819,
      1822,
      1057,
    ],
    [1054, 1056],
    [1265, 1053],
    [1265, 1055],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
  ];
}
