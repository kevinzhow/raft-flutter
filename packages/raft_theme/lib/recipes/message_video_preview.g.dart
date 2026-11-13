// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `messageVideoPreview`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftMessageVideoPreviewRecipe].
class RaftMessageVideoPreviewRecipeStyle {
  const RaftMessageVideoPreviewRecipeStyle({
    required this.root,
    required this.media,
    required this.fallback,
    required this.failureContent,
    required this.failureIcon,
    required this.failureTitle,
    required this.failureAction,
    required this.action,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `media`.
  final RaftSlotStyle media;

  /// Slot `fallback`.
  final RaftSlotStyle fallback;

  /// Slot `failureContent`.
  final RaftSlotStyle failureContent;

  /// Slot `failureIcon`.
  final RaftSlotStyle failureIcon;

  /// Slot `failureTitle`.
  final RaftSlotStyle failureTitle;

  /// Slot `failureAction`.
  final RaftSlotStyle failureAction;

  /// Slot `action`.
  final RaftSlotStyle action;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'media': media,
    'fallback': fallback,
    'failureContent': failureContent,
    'failureIcon': failureIcon,
    'failureTitle': failureTitle,
    'failureAction': failureAction,
    'action': action,
  };
}

/// raft-ui recipe `messageVideoPreview` (`dist/components/message-attachment/message-video-preview.recipe.mjs`, index.mjs:14512).
///
/// Used by: MessageVideoPreview, MessageVideoPreviewAction, MessageVideoPreviewFailureAction, MessageVideoPreviewFailureContent, MessageVideoPreviewFailureIcon, MessageVideoPreviewFailureTitle, MessageVideoPreviewFallback, MessageVideoPreviewMedia.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftMessageVideoPreviewRecipe {
  static const String recipeName = 'messageVideoPreview';
  static const List<String> slotNames = [
    'root',
    'media',
    'fallback',
    'failureContent',
    'failureIcon',
    'failureTitle',
    'failureAction',
    'action',
  ];
  static const List<RaftRecipeAxis> axes = [];

  static RaftMessageVideoPreviewRecipeStyle resolve({
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
    return RaftMessageVideoPreviewRecipeStyle(
      root: s[0],
      media: s[1],
      fallback: s[2],
      failureContent: s[3],
      failureIcon: s[4],
      failureTitle: s[5],
      failureAction: s[6],
      action: s[7],
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
    [1627, 2433, 796, 2725, 2252, 887, 2613, 1978, 2462, 939, 953, 890],
    [937, 2538, 887, 2223],
    [1400, 2538, 1864, 1869, 887, 2634],
    [1400, 1962, 1404, 1864, 2405, 2590, 1466, 1456, 2588, 1457],
    [482, 490],
    [],
    [
      1847,
      997,
      1864,
      1464,
      940,
      933,
      2260,
      2635,
      680,
      1338,
      2684,
      1799,
      1800,
      2243,
      2248,
      2250,
      1430,
      487,
    ],
    [
      691,
      1400,
      1864,
      1869,
      2675,
      1366,
      2245,
      2248,
      2250,
      1425,
      1352,
      474,
      2648,
      2443,
      2522,
      2461,
      941,
      955,
      911,
      2598,
      1794,
      699,
      2247,
      1439,
      1350,
      1347,
      1348,
      1363,
      478,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7],
  ];
}
