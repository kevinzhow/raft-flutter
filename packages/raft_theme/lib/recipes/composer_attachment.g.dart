// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `composerAttachment`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `side` axis of `composerAttachment`.
enum RaftComposerAttachmentRecipeSide {
  prev('prev'),
  next('next');

  const RaftComposerAttachmentRecipeSide(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftComposerAttachmentRecipe].
class RaftComposerAttachmentRecipeStyle {
  const RaftComposerAttachmentRecipeStyle({
    required this.attachments,
    required this.attachmentsScrollArea,
    required this.attachmentsViewport,
    required this.attachmentsNav,
    required this.attachment,
    required this.attachmentFile,
    required this.attachmentImage,
    required this.attachmentBody,
    required this.attachmentTitle,
    required this.attachmentMeta,
    required this.attachmentUploadingOverlay,
    required this.attachmentUploadProgressBar,
    required this.attachmentUploadProgressBarIndicator,
    required this.attachmentFailedOverlay,
    required this.attachmentRemove,
  });

  /// Slot `attachments`.
  final RaftSlotStyle attachments;

  /// Slot `attachmentsScrollArea`.
  final RaftSlotStyle attachmentsScrollArea;

  /// Slot `attachmentsViewport`.
  final RaftSlotStyle attachmentsViewport;

  /// Slot `attachmentsNav`.
  final RaftSlotStyle attachmentsNav;

  /// Slot `attachment`.
  final RaftSlotStyle attachment;

  /// Slot `attachmentFile`.
  final RaftSlotStyle attachmentFile;

  /// Slot `attachmentImage`.
  final RaftSlotStyle attachmentImage;

  /// Slot `attachmentBody`.
  final RaftSlotStyle attachmentBody;

  /// Slot `attachmentTitle`.
  final RaftSlotStyle attachmentTitle;

  /// Slot `attachmentMeta`.
  final RaftSlotStyle attachmentMeta;

  /// Slot `attachmentUploadingOverlay`.
  final RaftSlotStyle attachmentUploadingOverlay;

  /// Slot `attachmentUploadProgressBar`.
  final RaftSlotStyle attachmentUploadProgressBar;

  /// Slot `attachmentUploadProgressBarIndicator`.
  final RaftSlotStyle attachmentUploadProgressBarIndicator;

  /// Slot `attachmentFailedOverlay`.
  final RaftSlotStyle attachmentFailedOverlay;

  /// Slot `attachmentRemove`.
  final RaftSlotStyle attachmentRemove;

  Map<String, RaftSlotStyle> get slots => {
    'attachments': attachments,
    'attachmentsScrollArea': attachmentsScrollArea,
    'attachmentsViewport': attachmentsViewport,
    'attachmentsNav': attachmentsNav,
    'attachment': attachment,
    'attachmentFile': attachmentFile,
    'attachmentImage': attachmentImage,
    'attachmentBody': attachmentBody,
    'attachmentTitle': attachmentTitle,
    'attachmentMeta': attachmentMeta,
    'attachmentUploadingOverlay': attachmentUploadingOverlay,
    'attachmentUploadProgressBar': attachmentUploadProgressBar,
    'attachmentUploadProgressBarIndicator':
        attachmentUploadProgressBarIndicator,
    'attachmentFailedOverlay': attachmentFailedOverlay,
    'attachmentRemove': attachmentRemove,
  };
}

/// raft-ui recipe `composerAttachment` (`src/components/composer/composer-attachment.recipe.ts`, index.mjs:11230).
///
/// Used by: ComposerAttachment, ComposerAttachmentBody, ComposerAttachmentFailedOverlay, ComposerAttachmentFile, ComposerAttachmentImage, ComposerAttachmentMeta, ComposerAttachmentRemove, ComposerAttachmentTitle, ComposerAttachmentUploadProgressBar, ComposerAttachmentUploadingOverlay, ComposerAttachments, ComposerAttachmentsScrollArea.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftComposerAttachmentRecipe {
  static const String recipeName = 'composerAttachment';
  static const List<String> slotNames = [
    'attachments',
    'attachmentsScrollArea',
    'attachmentsViewport',
    'attachmentsNav',
    'attachment',
    'attachmentFile',
    'attachmentImage',
    'attachmentBody',
    'attachmentTitle',
    'attachmentMeta',
    'attachmentUploadingOverlay',
    'attachmentUploadProgressBar',
    'attachmentUploadProgressBarIndicator',
    'attachmentFailedOverlay',
    'attachmentRemove',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('side', ['prev', 'next'], null, true),
  ];

  static RaftComposerAttachmentRecipeStyle resolve({
    RaftComposerAttachmentRecipeSide? side,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [side?.css],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftComposerAttachmentRecipeStyle(
      attachments: s[0],
      attachmentsScrollArea: s[1],
      attachmentsViewport: s[2],
      attachmentsNav: s[3],
      attachment: s[4],
      attachmentFile: s[5],
      attachmentImage: s[6],
      attachmentBody: s[7],
      attachmentTitle: s[8],
      attachmentMeta: s[9],
      attachmentUploadingOverlay: s[10],
      attachmentUploadProgressBar: s[11],
      attachmentUploadProgressBarIndicator: s[12],
      attachmentFailedOverlay: s[13],
      attachmentRemove: s[14],
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
    [965, 971, 1022, 1246, 1245, 1219, 1257, 1237, 1640, 1610, 1220, 1238],
    [1678, 1924, 1481],
    [965, 969, 1022, 1581, 1584, 1587, 1665, 1722, 114, 11, 1610],
    [422, 1861, 1937, 110, 1753, 1734, 266],
    [1139, 1678, 299],
    [
      1678,
      965,
      1176,
      1905,
      280,
      277,
      1318,
      1023,
      1706,
      620,
      633,
      581,
      1654,
      1818,
      294,
    ],
    [1678, 618, 1745, 1736, 1579, 26, 25, 22, 21, 24, 23, 1706, 620, 633, 581],
    [1481, 966, 965, 967, 1323, 1019],
    [618, 1893, 1015, 1817, 1016, 1818],
    [618, 1924, 1893, 1832, 1013, 1835, 1820],
    [
      422,
      1306,
      1935,
      965,
      967,
      1318,
      1323,
      1652,
      1812,
      1706,
      597,
      1013,
      1835,
      1007,
      1818,
    ],
    [422, 1936, 1171, 1579, 1683, 645, 1349, 1922, 1700, 596],
    [618, 1197, 1702, 592],
    [
      422,
      1306,
      1935,
      965,
      967,
      1318,
      1323,
      1652,
      412,
      1812,
      1706,
      625,
      598,
      1015,
      1810,
      1016,
      1815,
    ],
    [
      422,
      1936,
      965,
      1318,
      1323,
      1890,
      1125,
      381,
      277,
      106,
      103,
      1750,
      1712,
      622,
      635,
      596,
      1818,
      1555,
      1282,
      429,
      1573,
      995,
      928,
      925,
      922,
      938,
      442,
      434,
      450,
      382,
      278,
    ],
    [422, 1861, 1937, 110, 1753, 1734, 266, 1349],
    [422, 1861, 1937, 110, 1753, 1734, 266, 1683],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14],
    [0, 1, 2, 15, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14],
    [0, 1, 2, 16, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14],
  ];
}
