// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `messageAttachment`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftMessageAttachmentRecipe].
class RaftMessageAttachmentRecipeStyle {
  const RaftMessageAttachmentRecipeStyle({required this.group, required this.card, required this.title, required this.meta, required this.metaStart, required this.metaEnd, required this.summary, required this.commentSummary, required this.diffSummary, required this.diffAddition, required this.diffDeletion, required this.action});

  /// Slot `group`.
  final RaftSlotStyle group;
  /// Slot `card`.
  final RaftSlotStyle card;
  /// Slot `title`.
  final RaftSlotStyle title;
  /// Slot `meta`.
  final RaftSlotStyle meta;
  /// Slot `metaStart`.
  final RaftSlotStyle metaStart;
  /// Slot `metaEnd`.
  final RaftSlotStyle metaEnd;
  /// Slot `summary`.
  final RaftSlotStyle summary;
  /// Slot `commentSummary`.
  final RaftSlotStyle commentSummary;
  /// Slot `diffSummary`.
  final RaftSlotStyle diffSummary;
  /// Slot `diffAddition`.
  final RaftSlotStyle diffAddition;
  /// Slot `diffDeletion`.
  final RaftSlotStyle diffDeletion;
  /// Slot `action`.
  final RaftSlotStyle action;

  Map<String, RaftSlotStyle> get slots => {'group': group, 'card': card, 'title': title, 'meta': meta, 'metaStart': metaStart, 'metaEnd': metaEnd, 'summary': summary, 'commentSummary': commentSummary, 'diffSummary': diffSummary, 'diffAddition': diffAddition, 'diffDeletion': diffDeletion, 'action': action};
}

/// raft-ui recipe `messageAttachment` (`src/components/message-attachment/message-attachment.recipe.ts`, index.mjs:10898).
///
/// Used by: MessageAttachmentAction, MessageAttachmentCard, MessageAttachmentCommentSummary, MessageAttachmentDiffAddition, MessageAttachmentDiffDeletion, MessageAttachmentDiffSummary, MessageAttachmentGroup, MessageAttachmentMeta, MessageAttachmentMetaEnd, MessageAttachmentMetaStart, MessageAttachmentSummary, MessageAttachmentTitle.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftMessageAttachmentRecipe {
  static const String recipeName = 'messageAttachment';
  static const List<String> slotNames = ['group', 'card', 'title', 'meta', 'metaStart', 'metaEnd', 'summary', 'commentSummary', 'diffSummary', 'diffAddition', 'diffDeletion', 'action'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftMessageAttachmentRecipeStyle resolve({required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name], states, tokens);
    return RaftMessageAttachmentRecipeStyle(group: s[0], card: s[1], title: s[2], meta: s[3], metaStart: s[4], metaEnd: s[5], summary: s[6], commentSummary: s[7], diffSummary: s[8], diffAddition: s[9], diffDeletion: s[10], action: s[11]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [1620, 2474, 1626, 2314, 1698],
    [1909, 2775, 2301, 1957, 3110, 2578, 2467, 2867, 1622, 2656, 3003, 864, 878, 856, 2752, 2763, 2956, 3084, 2243, 2221],
    [862, 3127, 2484, 2867, 3092, 3032, 1688, 2956],
    [2605, 1620, 3127, 2574, 2484, 2312, 2316, 1697, 2918, 2960],
    [2574, 1621, 3092],
    [2585, 2301, 2867, 2312, 1696, 437, 427],
    [2597, 2301, 2867, 2312, 3131, 2918, 429, 427, 1688, 2960],
    [1702],
    [1697],
    [3019],
    [2972],
    [2775, 1620, 2878, 2312, 2317, 688, 682, 703, 429, 427, 2963, 1883],
    [1909, 2775, 2301, 3110, 2578, 2467, 2867, 1622, 2656, 3003, 1955, 2810, 867, 897, 825, 2752, 2763, 2987, 2865, 3062, 1602, 2246, 2221, 590, 1009, 1107, 1093, 959],
    [862, 3127, 2484, 2867, 3092, 3032, 1688, 2976],
    [2605, 1620, 3127, 2574, 2484, 2312, 2316, 1697, 2918, 2984],
    [2597, 2301, 2867, 2312, 3131, 2918, 429, 427, 1688, 2984],
    [2775, 1620, 2878, 2312, 2317, 688, 682, 703, 429, 427, 2978, 3084, 1884],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], [0, 12, 13, 14, 4, 5, 15, 7, 8, 9, 10, 16],
  ];
}
