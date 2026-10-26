// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `messageList`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `tone` axis of `messageList` (default `faint`).
enum RaftMessageListRecipeTone {
  faint('faint'),
  muted('muted');

  const RaftMessageListRecipeTone(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftMessageListRecipe].
class RaftMessageListRecipeStyle {
  const RaftMessageListRecipeStyle({
    required this.root,
    required this.viewport,
    required this.content,
    required this.dateDividerRoot,
    required this.dateDividerRule,
    required this.dateDividerChip,
    required this.notice,
    required this.historyLimited,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `viewport`.
  final RaftSlotStyle viewport;

  /// Slot `content`.
  final RaftSlotStyle content;

  /// Slot `dateDividerRoot`.
  final RaftSlotStyle dateDividerRoot;

  /// Slot `dateDividerRule`.
  final RaftSlotStyle dateDividerRule;

  /// Slot `dateDividerChip`.
  final RaftSlotStyle dateDividerChip;

  /// Slot `notice`.
  final RaftSlotStyle notice;

  /// Slot `historyLimited`.
  final RaftSlotStyle historyLimited;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'viewport': viewport,
    'content': content,
    'dateDividerRoot': dateDividerRoot,
    'dateDividerRule': dateDividerRule,
    'dateDividerChip': dateDividerChip,
    'notice': notice,
    'historyLimited': historyLimited,
  };
}

/// raft-ui recipe `messageList` (`src/components/message-list/message-list.recipe.ts`, index.mjs:9806).
///
/// Used by: MessageList, MessageListDateDivider, MessageListHistoryLimited, MessageListNotice.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftMessageListRecipe {
  static const String recipeName = 'messageList';
  static const List<String> slotNames = [
    'root',
    'viewport',
    'content',
    'dateDividerRoot',
    'dateDividerRule',
    'dateDividerChip',
    'notice',
    'historyLimited',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('tone', ['faint', 'muted'], 'faint', false),
  ];

  static RaftMessageListRecipeStyle resolve({
    RaftMessageListRecipeTone? tone,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [tone?.css],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftMessageListRecipeStyle(
      root: s[0],
      viewport: s[1],
      content: s[2],
      dateDividerRoot: s[3],
      dateDividerRule: s[4],
      dateDividerChip: s[5],
      notice: s[6],
      historyLimited: s[7],
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
    [1678, 1197, 1465],
    [1481, 1586],
    [965, 1480, 1924, 1481, 967],
    [965, 1723, 1318, 1022, 1658, 1669],
    [966, 1483, 639, 633],
    [1304, 1318, 1013, 1835, 1928, 1820],
    [1812, 1602, 1013, 1835, 1820],
    [1304, 1318, 1190, 1020, 1704, 1653, 1013, 1835, 1823, 1308, 1310, 278],
    [1812, 1602, 1013, 1835, 1823],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7],
    [0, 1, 2, 3, 4, 5, 8, 7],
  ];
}
