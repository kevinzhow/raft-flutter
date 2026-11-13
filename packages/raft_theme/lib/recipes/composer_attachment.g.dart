// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `composerAttachment`.
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
    required this.attachmentsRow,
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

  /// Slot `attachmentsRow`.
  final RaftSlotStyle attachmentsRow;

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
    'attachmentsRow': attachmentsRow,
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

/// raft-ui recipe `composerAttachment` (`dist/components/composer/composer-attachment.recipe.mjs`, index.mjs:16188).
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
    'attachmentsRow',
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
      attachmentsRow: s[2],
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
    [1400, 1408, 1466, 1735, 1734, 1710, 1762, 1725, 2380, 2292, 1711, 1726],
    [2433, 2725, 2116],
    [1400, 1406, 1466, 2415, 20, 2292],
    [691, 2642, 2739, 193, 2522, 2461, 2497, 461],
    [1600, 2433, 501],
    [
      2433,
      1400,
      1649,
      2702,
      478,
      474,
      1864,
      1467,
      2463,
      939,
      953,
      895,
      2401,
      2598,
      492,
    ],
    [2433, 937, 2512, 2499, 2252, 35, 34, 31, 30, 33, 32, 2463, 939, 953, 895],
    [2116, 1401, 1400, 1404, 1869, 1463],
    [937, 2681, 1456, 2597, 1457, 2598],
    [937, 2725, 2681, 2613, 1454, 2616, 2600],
    [
      691,
      1849,
      2747,
      1400,
      1404,
      1864,
      1869,
      2399,
      2590,
      2463,
      917,
      1454,
      2616,
      1449,
      2598,
    ],
    [691, 2747, 1646, 2252, 2438, 967, 1896, 2723, 2457, 911],
    [937, 1678, 2459, 906],
    [
      691,
      1849,
      2747,
      1400,
      1404,
      1864,
      1869,
      2399,
      660,
      2590,
      2463,
      944,
      917,
      1456,
      2588,
      1457,
      2594,
    ],
    [
      691,
      2739,
      1400,
      1864,
      1869,
      2676,
      1582,
      605,
      474,
      189,
      184,
      2519,
      2471,
      941,
      955,
      911,
      2598,
      2229,
      1794,
      699,
      2247,
      1439,
      1353,
      1350,
      1347,
      1363,
      723,
      703,
      729,
      606,
      476,
    ],
    [691, 2642, 2739, 193, 2522, 2461, 2497, 461, 1896],
    [691, 2642, 2739, 193, 2522, 2461, 2497, 461, 2438],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14],
    [0, 1, 2, 15, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14],
    [0, 1, 2, 16, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14],
  ];
}
