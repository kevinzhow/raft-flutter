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
    [965, 971, 1023, 1247, 1246, 1220, 1258, 1238, 1644, 1614, 1221, 1239],
    [1682, 1929, 1484],
    [965, 969, 1023, 1585, 1588, 1591, 1669, 1726, 114, 11, 1614],
    [422, 1865, 1942, 110, 1757, 1738, 266],
    [1140, 1682, 299],
    [
      1682,
      965,
      1177,
      1909,
      280,
      277,
      1319,
      1024,
      1710,
      620,
      633,
      581,
      1658,
      1822,
      294,
    ],
    [1682, 618, 1749, 1740, 1583, 26, 25, 22, 21, 24, 23, 1710, 620, 633, 581],
    [1484, 966, 965, 967, 1324, 1020],
    [618, 1897, 1016, 1821, 1017, 1822],
    [618, 1929, 1897, 1836, 1014, 1839, 1824],
    [
      422,
      1307,
      1940,
      965,
      967,
      1319,
      1324,
      1656,
      1816,
      1710,
      597,
      1014,
      1839,
      1008,
      1822,
    ],
    [422, 1941, 1172, 1583, 1687, 645, 1350, 1927, 1704, 596],
    [618, 1198, 1706, 592],
    [
      422,
      1307,
      1940,
      965,
      967,
      1319,
      1324,
      1656,
      412,
      1816,
      1710,
      625,
      598,
      1016,
      1814,
      1017,
      1819,
    ],
    [
      422,
      1941,
      965,
      1319,
      1324,
      1894,
      1126,
      381,
      277,
      106,
      103,
      1754,
      1716,
      622,
      635,
      596,
      1822,
      1559,
      1283,
      429,
      1577,
      996,
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
    [422, 1865, 1942, 110, 1757, 1738, 266, 1350],
    [422, 1865, 1942, 110, 1757, 1738, 266, 1687],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14],
    [0, 1, 2, 15, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14],
    [0, 1, 2, 16, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14],
  ];
}
