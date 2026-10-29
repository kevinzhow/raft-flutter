// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `messageAttachment`.
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

/// raft-ui recipe `messageAttachment` (`src/components/message-attachment/message-attachment.recipe.ts`, index.mjs:8688).
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
    [965, 1412, 971, 1321, 1023],
    [
      1134,
      1680,
      1305,
      1179,
      1907,
      1489,
      1404,
      1738,
      967,
      1581,
      1834,
      1707,
      620,
      633,
      596,
      1669,
      1633,
      1617,
      1820,
      1575,
      1283,
      429,
      996,
      228,
    ],
    [618, 1926, 1424, 1738, 1895, 1632, 1016, 1811, 1017, 1820],
    [1516, 965, 1926, 1483, 1424, 1319, 1323, 1023, 1014, 1837, 1822],
    [1483, 966, 1895],
    [1497, 1305, 1738, 1319, 1021, 287, 277],
    [1508, 1305, 1738, 1319, 1930, 277, 1632, 1014, 1837, 1822, 279],
    [1028],
    [1022],
    [1845],
    [1817],
    [
      1680,
      965,
      1319,
      1324,
      513,
      510,
      529,
      277,
      99,
      1754,
      1708,
      1820,
      1575,
      1272,
      427,
      996,
      280,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
  ];
}
