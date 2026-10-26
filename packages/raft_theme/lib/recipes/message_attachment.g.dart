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
    [965, 1410, 971, 1320, 1022],
    [
      1133,
      1678,
      1304,
      1178,
      1905,
      1487,
      1402,
      1736,
      967,
      1579,
      1832,
      1705,
      620,
      633,
      596,
      1667,
      1631,
      1615,
      1818,
      1573,
      1282,
      429,
      995,
      228,
    ],
    [618, 1924, 1422, 1736, 1893, 1630, 1015, 1809, 1016, 1818],
    [1514, 965, 1924, 1481, 1422, 1318, 1322, 1022, 1013, 1835, 1820],
    [1481, 966, 1893],
    [1495, 1304, 1736, 1318, 1020, 287, 277],
    [1506, 1304, 1736, 1318, 1928, 277, 1630, 1013, 1835, 1820, 279],
    [1027],
    [1021],
    [1843],
    [1815],
    [
      1678,
      965,
      1318,
      1323,
      513,
      510,
      529,
      277,
      99,
      1752,
      1706,
      1818,
      1573,
      1271,
      427,
      995,
      280,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
  ];
}
