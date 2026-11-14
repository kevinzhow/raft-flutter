// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `messageList`.
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
    required this.endFade,
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

  /// Slot `endFade`.
  final RaftSlotStyle endFade;

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
    'endFade': endFade,
    'notice': notice,
    'historyLimited': historyLimited,
  };
}

/// raft-ui recipe `messageList` (`dist/components/message-list/message-list.recipe.mjs`, index.mjs:14909).
///
/// Used by: MessageList, MessageListDateDivider, MessageListEndFade, MessageListHistoryLimited, MessageListNotice.
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
    'endFade',
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
      endFade: s[6],
      notice: s[7],
      historyLimited: s[8],
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
    [2433, 1678, 2098],
    [2538, 2098, 2116, 2259],
    [1400, 2112, 2725, 2116, 1404],
    [1400, 2483, 1864, 1466, 2405, 2389, 2286],
    [1401, 2117, 960, 953],
    [1847, 1864, 1454, 2616, 2729, 2600],
    [2346, 691, 1858, 965, 2747, 1681, 919, 1459, 2638],
    [2590, 2392, 2291, 1454, 2616, 2600],
    [1847, 1864, 1666, 1464, 2461, 2400, 1454, 2616, 2603, 1851, 1854, 476],
    [2590, 2392, 2291, 1454, 2616, 2603],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8],
    [0, 1, 2, 3, 4, 5, 6, 9, 8],
  ];
}
