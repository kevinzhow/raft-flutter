// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `messageAttachment`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
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

/// raft-ui recipe `messageAttachment` (`dist/components/message-attachment/message-attachment.recipe.mjs`, index.mjs:13828).
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
  static const List<RaftRecipeAxis> axes = [];

  static RaftMessageAttachmentRecipeStyle resolve({
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
    [1400, 1967, 1408, 1866, 1466],
    [
      1594,
      2433,
      1847,
      1651,
      2702,
      2122,
      1958,
      2499,
      1404,
      2252,
      2613,
      2462,
      939,
      953,
      911,
      2417,
      2367,
      2299,
      2598,
      2247,
      1796,
      699,
      1439,
      403,
    ],
    [937, 2725, 1980, 2499, 2681, 2355, 1456, 2587, 1457, 2598],
    [2152, 1400, 2725, 2116, 1980, 1864, 1868, 1466, 1454, 2616, 2600],
    [2116, 1401, 2681],
    [2132, 1847, 2499, 1864, 1464, 2490, 485, 474],
    [2144, 1847, 2499, 1864, 2729, 474, 2355, 1454, 2616, 2600, 477],
    [1471],
    [1465],
    [2624],
    [2594],
    [
      2433,
      1400,
      1864,
      1869,
      810,
      806,
      828,
      474,
      176,
      1992,
      2520,
      2488,
      2461,
      2598,
      2247,
      1785,
      697,
      1439,
      478,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
  ];
}
