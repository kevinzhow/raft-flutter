// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `messageAttachment`.
// ignore_for_file: type=lint

import '../recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftMessageAttachmentRecipe].
class RaftMessageAttachmentRecipeStyle {
  const RaftMessageAttachmentRecipeStyle({
    required this.group,
    required this.card,
    required this.title,
    required this.meta,
    required this.metaStart,
    required this.metaEnd,
    required this.summary,
    required this.commentSummary,
    required this.diffSummary,
    required this.diffAddition,
    required this.diffDeletion,
    required this.action,
  });

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

  Map<String, RaftSlotStyle> get slots => {
    'group': group,
    'card': card,
    'title': title,
    'meta': meta,
    'metaStart': metaStart,
    'metaEnd': metaEnd,
    'summary': summary,
    'commentSummary': commentSummary,
    'diffSummary': diffSummary,
    'diffAddition': diffAddition,
    'diffDeletion': diffDeletion,
    'action': action,
  };
}

/// raft-ui recipe `messageAttachment` (`src/components/message-attachment/message-attachment.recipe.ts`, index.mjs:10941).
///
/// Used by: MessageAttachmentAction, MessageAttachmentCard, MessageAttachmentCommentSummary, MessageAttachmentDiffAddition, MessageAttachmentDiffDeletion, MessageAttachmentDiffSummary, MessageAttachmentGroup, MessageAttachmentMeta, MessageAttachmentMetaEnd, MessageAttachmentMetaStart, MessageAttachmentSummary, MessageAttachmentTitle.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftMessageAttachmentRecipe {
  static const String recipeName = 'messageAttachment';
  static const List<String> slotNames = [
    'group',
    'card',
    'title',
    'meta',
    'metaStart',
    'metaEnd',
    'summary',
    'commentSummary',
    'diffSummary',
    'diffAddition',
    'diffDeletion',
    'action',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftMessageAttachmentRecipeStyle resolve({
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
    return RaftMessageAttachmentRecipeStyle(
      group: s[0],
      card: s[1],
      title: s[2],
      meta: s[3],
      metaStart: s[4],
      metaEnd: s[5],
      summary: s[6],
      commentSummary: s[7],
      diffSummary: s[8],
      diffAddition: s[9],
      diffDeletion: s[10],
      action: s[11],
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
    [1644, 2495, 1650, 2333, 1723],
    [
      1910,
      2804,
      2320,
      1959,
      3151,
      2601,
      2488,
      2902,
      1646,
      2679,
      3040,
      876,
      894,
      868,
      2780,
      2792,
      2994,
      3125,
      2262,
      2240,
    ],
    [874, 3168, 2505, 2902, 3133, 3073, 1713, 2994],
    [2628, 1644, 3168, 2597, 2505, 2331, 2335, 1722, 2956, 2997],
    [2597, 1645, 3133],
    [2608, 2320, 2902, 2331, 1721, 435, 425],
    [2620, 2320, 2902, 2331, 3172, 2956, 427, 425, 1713, 2997],
    [1727],
    [1722],
    [3055],
    [3009],
    [2804, 1644, 2913, 2331, 2336, 694, 688, 709, 427, 425, 3000, 1888],
    [
      1910,
      2804,
      2320,
      3151,
      2601,
      2488,
      2902,
      1646,
      2679,
      3040,
      1957,
      2840,
      879,
      913,
      830,
      2780,
      2792,
      3024,
      2899,
      3103,
      1626,
      2265,
      2240,
      596,
      1029,
      1127,
      1113,
      979,
    ],
    [874, 3168, 2505, 2902, 3133, 3073, 1713, 3013],
    [2628, 1644, 3168, 2597, 2505, 2331, 2335, 1722, 2956, 3021],
    [2620, 2320, 2902, 2331, 3172, 2956, 427, 425, 1713, 3021],
    [2804, 1644, 2913, 2331, 2336, 694, 688, 709, 427, 425, 3015, 3125, 1889],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
    [0, 12, 13, 14, 4, 5, 15, 7, 8, 9, 10, 16],
  ];
}
