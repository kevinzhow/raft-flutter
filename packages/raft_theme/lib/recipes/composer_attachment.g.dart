// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
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

/// raft-ui recipe `composerAttachment` (`src/components/composer/composer-attachment.recipe.ts`, index.mjs:13409).
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
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftComposerAttachmentRecipeStyle resolve({
    RaftComposerAttachmentRecipeSide? side,
    required RaftRecipeTheme theme,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [side?.css, theme.name],
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
    [1644, 1650, 1723, 2149, 2148, 2081, 2171, 2115],
    [2804, 3168, 2597],
    [1644, 1648, 1723, 2681, 2685, 2689, 2792, 2867, 173, 24, 2718],
    [586, 3080, 3181, 155, 2897, 2190, 2288, 601, 602, 610],
    [1917, 2804, 2079, 2146, 2147, 2145],
    [2804, 1644, 1956, 3151, 1723, 878, 2779, 429, 425, 2331, 892, 868, 446],
    [2804, 874, 2902, 2679, 37, 36, 33, 32, 35, 34, 2925, 2308],
    [2597, 1645, 1644, 1973, 1646, 2335],
    [874, 3133, 3073, 1709, 2621, 2363, 2994],
    [874, 3168, 3133, 3048, 2956, 2363, 2998],
    [
      586,
      2322,
      3179,
      1644,
      1646,
      2331,
      2336,
      2777,
      3007,
      2956,
      1709,
      2350,
      873,
      2994,
    ],
    [586, 937, 2369, 3180, 1951, 3168, 2679, 770, 1009],
    [874, 1980, 786],
    [
      586,
      2322,
      3179,
      1644,
      1646,
      2331,
      2336,
      2777,
      578,
      3007,
      2956,
      1709,
      2350,
      892,
      785,
      2994,
    ],
    [
      586,
      149,
      143,
      3180,
      1644,
      2915,
      2331,
      2336,
      2845,
      2649,
      3126,
      1900,
      561,
      563,
      562,
      426,
      425,
      769,
      3067,
      2668,
      2674,
      2676,
    ],
    [1644, 1650, 1723, 2149, 2148, 2081, 2171, 2115, 2757, 2080],
    [1644, 1648, 1723, 2681, 2685, 2689, 2792, 2867, 173, 24, 2777],
    [586, 3080, 3181, 155, 2845, 2896],
    [1917, 2804, 469],
    [
      2804,
      1644,
      1956,
      3151,
      2779,
      429,
      425,
      2333,
      1725,
      2679,
      2848,
      877,
      830,
      2759,
      2748,
      2721,
      2821,
      2824,
      450,
      99,
      100,
    ],
    [2804, 874, 2910, 2902, 2679, 37, 36, 33, 32, 35, 34, 2848, 2821, 2824],
    [874, 2597, 1645],
    [874, 3133, 3073, 3130, 1713, 3013],
    [874, 3168, 3133, 3048, 2956, 586, 2813, 940, 3021],
    [
      586,
      2322,
      3179,
      1644,
      1646,
      2331,
      2336,
      2777,
      3007,
      2956,
      1709,
      2350,
      2848,
      873,
      3024,
      1012,
    ],
    [586, 937, 2369, 3180, 1951, 3168, 2679, 770, 1009, 2843],
    [874, 1980, 764],
    [
      586,
      2322,
      3179,
      1644,
      1646,
      2331,
      2336,
      2777,
      578,
      3007,
      2956,
      1709,
      2350,
      2848,
      873,
      3009,
      1012,
      1181,
    ],
    [
      586,
      149,
      143,
      3180,
      1644,
      2915,
      2331,
      2336,
      2845,
      2649,
      3126,
      1900,
      561,
      563,
      562,
      426,
      425,
      807,
      3016,
      2668,
      2674,
      2671,
    ],
    [586, 3080, 3181, 155, 2370, 2897, 2190, 2288, 601, 602, 610],
    [586, 3080, 3181, 155, 2370, 2845, 2896],
    [586, 3080, 3181, 155, 2811, 2897, 2190, 2288, 601, 602, 610],
    [586, 3080, 3181, 155, 2811, 2845, 2896],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14],
    [15, 1, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28],
    [0, 1, 2, 29, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14],
    [15, 1, 16, 30, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28],
    [0, 1, 2, 31, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14],
    [15, 1, 16, 32, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28],
  ];
}
