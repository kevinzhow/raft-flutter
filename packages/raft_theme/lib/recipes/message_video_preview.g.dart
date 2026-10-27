// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `messageVideoPreview`.
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

/// raft-ui recipe `messageVideoPreview` (`src/components/message-attachment/message-video-preview.recipe.ts`, index.mjs:9065).
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
    [1163, 1680, 503, 1926, 1581, 573, 1834, 1423, 1707, 620, 633, 577],
    [618, 1768, 573, 1551],
    [965, 1768, 1319, 1324, 573, 1855],
    [965, 1407, 967, 1319, 1660, 1814, 1023, 1016, 1812, 1017],
    [284, 292],
    [],
    [
      1305,
      664,
      1319,
      1021,
      621,
      615,
      1590,
      1856,
      418,
      1287,
      1571,
      1576,
      1578,
      990,
      289,
    ],
    [
      422,
      965,
      1319,
      1324,
      1891,
      942,
      1573,
      1576,
      1578,
      983,
      927,
      277,
      1864,
      1686,
      1755,
      1708,
      622,
      635,
      596,
      1820,
      1274,
      1285,
      1283,
      429,
      1575,
      996,
      925,
      922,
      923,
      938,
      280,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7],
  ];
}
