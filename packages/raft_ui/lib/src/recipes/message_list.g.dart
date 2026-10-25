// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
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

/// raft-ui recipe `messageList` (`src/components/message-list/message-list.recipe.ts`, index.mjs:12237).
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
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
    RaftRecipeAxis('tone', ['faint', 'muted'], 'faint', false),
  ];

  static RaftMessageListRecipeStyle resolve({
    required RaftRecipeTheme theme,
    RaftMessageListRecipeTone? tone,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [theme.name, tone?.css],
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
    [2804, 1980, 2583],
    [2597, 2688],
    [1644, 2595, 3168, 2597, 1646],
    [1644, 2868, 2331, 2781, 2794],
    [1645, 3132, 927, 894],
    [2320, 2331, 2779, 2956, 1709, 3137, 3098, 2998],
    [3007, 2706, 1714, 3073, 3027],
    [2320, 2331, 1722, 876, 895, 870, 2779, 2791, 427],
    [3007, 2706, 1714, 3073, 3029],
    [1644, 2595, 3168, 2597, 1646, 2566],
    [1644, 2868, 2331, 2781, 2794, 2653],
    [1645, 925, 911, 1026],
    [2320, 2331, 2779, 1714, 2958, 1715, 3137, 3098, 3018],
    [3007, 2706, 1716, 3073, 3027],
    [2320, 2331, 1722, 2852, 876, 912, 832, 2779, 2791, 427],
    [3007, 2706, 1716, 3073, 3029],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7],
    [0, 1, 2, 3, 4, 5, 8, 7],
    [0, 1, 9, 10, 11, 12, 13, 14],
    [0, 1, 9, 10, 11, 12, 15, 14],
  ];
}
