// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
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
  const RaftMessageListRecipeStyle({required this.root, required this.viewport, required this.content, required this.dateDividerRoot, required this.dateDividerRule, required this.dateDividerChip, required this.notice, required this.historyLimited});

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

  Map<String, RaftSlotStyle> get slots => {'root': root, 'viewport': viewport, 'content': content, 'dateDividerRoot': dateDividerRoot, 'dateDividerRule': dateDividerRule, 'dateDividerChip': dateDividerChip, 'notice': notice, 'historyLimited': historyLimited};
}

/// raft-ui recipe `messageList` (`src/components/message-list/message-list.recipe.ts`, index.mjs:12194).
///
/// Used by: MessageList, MessageListDateDivider, MessageListHistoryLimited, MessageListNotice.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftMessageListRecipe {
  static const String recipeName = 'messageList';
  static const List<String> slotNames = ['root', 'viewport', 'content', 'dateDividerRoot', 'dateDividerRule', 'dateDividerChip', 'notice', 'historyLimited'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
    RaftRecipeAxis('tone', ['faint', 'muted'], 'faint', false),
  ];

  static RaftMessageListRecipeStyle resolve({required RaftRecipeTheme theme, RaftMessageListRecipeTone? tone, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name, tone?.css], states, tokens);
    return RaftMessageListRecipeStyle(root: s[0], viewport: s[1], content: s[2], dateDividerRoot: s[3], dateDividerRule: s[4], dateDividerChip: s[5], notice: s[6], historyLimited: s[7]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [2775, 1978, 2560],
    [2574, 2665],
    [1620, 2572, 3127, 2574, 1622],
    [1620, 2834, 2312, 2753, 2765],
    [1621, 3091, 913, 878],
    [2301, 2312, 2751, 2918, 1684, 3096, 3057, 2961],
    [2970, 2683, 1689, 3032, 2990],
    [2301, 2312, 1697, 864, 879, 858, 2751, 2762, 429],
    [2970, 2683, 1689, 3032, 2992],
    [1620, 2572, 3127, 2574, 1622, 2543],
    [1620, 2834, 2312, 2753, 2765, 2630],
    [1621, 911, 895, 1006],
    [2301, 2312, 2751, 1689, 2920, 1690, 3096, 3057, 2981],
    [2970, 2683, 1691, 3032, 2990],
    [2301, 2312, 1697, 2822, 864, 896, 827, 2751, 2762, 429],
    [2970, 2683, 1691, 3032, 2992],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7], [0, 1, 2, 3, 4, 5, 8, 7], [0, 1, 9, 10, 11, 12, 13, 14], [0, 1, 9, 10, 11, 12, 15, 14],
  ];
}
