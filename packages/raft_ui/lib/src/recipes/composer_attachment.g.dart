// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
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
  const RaftComposerAttachmentRecipeStyle({required this.attachments, required this.attachmentsScrollArea, required this.attachmentsViewport, required this.attachmentsNav, required this.attachment, required this.attachmentFile, required this.attachmentImage, required this.attachmentBody, required this.attachmentTitle, required this.attachmentMeta, required this.attachmentUploadingOverlay, required this.attachmentUploadProgressBar, required this.attachmentUploadProgressBarIndicator, required this.attachmentFailedOverlay, required this.attachmentRemove});

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

  Map<String, RaftSlotStyle> get slots => {'attachments': attachments, 'attachmentsScrollArea': attachmentsScrollArea, 'attachmentsViewport': attachmentsViewport, 'attachmentsNav': attachmentsNav, 'attachment': attachment, 'attachmentFile': attachmentFile, 'attachmentImage': attachmentImage, 'attachmentBody': attachmentBody, 'attachmentTitle': attachmentTitle, 'attachmentMeta': attachmentMeta, 'attachmentUploadingOverlay': attachmentUploadingOverlay, 'attachmentUploadProgressBar': attachmentUploadProgressBar, 'attachmentUploadProgressBarIndicator': attachmentUploadProgressBarIndicator, 'attachmentFailedOverlay': attachmentFailedOverlay, 'attachmentRemove': attachmentRemove};
}

/// raft-ui recipe `composerAttachment` (`src/components/composer/composer-attachment.recipe.ts`, index.mjs:13188).
///
/// Used by: ComposerAttachment, ComposerAttachmentBody, ComposerAttachmentFailedOverlay, ComposerAttachmentFile, ComposerAttachmentImage, ComposerAttachmentMeta, ComposerAttachmentRemove, ComposerAttachmentTitle, ComposerAttachmentUploadProgressBar, ComposerAttachmentUploadingOverlay, ComposerAttachments, ComposerAttachmentsScrollArea.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftComposerAttachmentRecipe {
  static const String recipeName = 'composerAttachment';
  static const List<String> slotNames = ['attachments', 'attachmentsScrollArea', 'attachmentsViewport', 'attachmentsNav', 'attachment', 'attachmentFile', 'attachmentImage', 'attachmentBody', 'attachmentTitle', 'attachmentMeta', 'attachmentUploadingOverlay', 'attachmentUploadProgressBar', 'attachmentUploadProgressBarIndicator', 'attachmentFailedOverlay', 'attachmentRemove'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('side', ['prev', 'next'], null, true),
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftComposerAttachmentRecipeStyle resolve({RaftComposerAttachmentRecipeSide? side, required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [side?.css, theme.name], states, tokens);
    return RaftComposerAttachmentRecipeStyle(attachments: s[0], attachmentsScrollArea: s[1], attachmentsViewport: s[2], attachmentsNav: s[3], attachment: s[4], attachmentFile: s[5], attachmentImage: s[6], attachmentBody: s[7], attachmentTitle: s[8], attachmentMeta: s[9], attachmentUploadingOverlay: s[10], attachmentUploadProgressBar: s[11], attachmentUploadProgressBarIndicator: s[12], attachmentFailedOverlay: s[13], attachmentRemove: s[14]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [1620, 1626, 1698, 2138, 2137, 2075, 2160, 2105],
    [2775, 3127, 2574],
    [1620, 1624, 1698, 2658, 2662, 2666, 2763, 2833, 173, 24, 2695],
    [580, 3039, 3140, 155, 2863, 2175, 2269, 595, 596, 604],
    [1916, 2775, 2073, 2135, 2136, 2134],
    [2775, 1620, 1954, 3110, 1698, 866, 2751, 431, 427, 2312, 876, 856, 448],
    [2775, 862, 2867, 2656, 37, 36, 33, 32, 35, 34, 2890, 2289],
    [2574, 1621, 1620, 1971, 1622, 2316],
    [862, 3092, 3032, 1684, 2598, 2344, 2956],
    [862, 3127, 3092, 3012, 2918, 2344, 2961],
    [580, 2303, 3138, 1620, 1622, 2312, 2317, 2749, 2970, 2918, 1684, 2331, 861, 2956],
    [580, 924, 2350, 3139, 1949, 3127, 2656, 764, 989],
    [862, 1978, 780],
    [580, 2303, 3138, 1620, 1622, 2312, 2317, 866, 2749, 2970, 2918, 1684, 2331, 876, 779, 2956],
    [580, 149, 143, 3139, 1620, 2880, 2312, 2317, 2815, 2626, 3085, 1895, 560, 562, 561, 428, 427, 763, 3026, 2645, 2651, 2653],
    [1620, 1626, 1698, 2138, 2137, 2075, 2160, 2105, 2732, 2074],
    [1620, 1624, 1698, 2658, 2662, 2666, 2763, 2833, 173, 24, 2749],
    [580, 3039, 3140, 155, 2815, 2862],
    [1916, 2775],
    [2775, 1620, 1954, 3110, 2751, 431, 427, 2314, 1700, 2656, 2818, 865, 825, 2734, 2722, 2698, 2791, 2794, 451, 99, 100],
    [2775, 862, 2875, 2867, 2656, 37, 36, 33, 32, 35, 34, 2818, 2791, 2794],
    [862, 2574, 1621],
    [862, 3092, 3032, 3089, 1688, 2976],
    [862, 3127, 3092, 3012, 2918, 580, 2784, 927, 2984],
    [580, 2303, 3138, 1620, 1622, 2312, 2317, 2749, 2970, 2918, 1684, 2331, 2818, 861, 2987, 992],
    [580, 924, 2350, 3139, 1949, 3127, 2656, 764, 989, 2813],
    [862, 1978, 758],
    [580, 2303, 3138, 1620, 1622, 2312, 2317, 2749, 2970, 2918, 1684, 2331, 2818, 865, 861, 2972, 992, 1162],
    [580, 149, 143, 3139, 1620, 2880, 2312, 2317, 2815, 2626, 3085, 1895, 560, 562, 561, 428, 427, 801, 2979, 2645, 2651, 2648],
    [580, 3039, 3140, 155, 2351, 2863, 2175, 2269, 595, 596, 604],
    [580, 3039, 3140, 155, 2351, 2815, 2862],
    [580, 3039, 3140, 155, 2782, 2863, 2175, 2269, 595, 596, 604],
    [580, 3039, 3140, 155, 2782, 2815, 2862],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14], [15, 1, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28], [0, 1, 2, 29, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14], [15, 1, 16, 30, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28], [0, 1, 2, 31, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14], [15, 1, 16, 32, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28],
  ];
}
