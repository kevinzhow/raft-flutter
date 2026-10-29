// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `messageVideoPreview`.
// ignore_for_file: type=lint

import '../recipe_runtime.dart';
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

/// raft-ui recipe `messageVideoPreview` (`src/components/message-attachment/message-video-preview.recipe.ts`, index.mjs:11363).
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
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftMessageVideoPreviewRecipeStyle resolve({
    required RaftRecipeTheme theme,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [theme.name],
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
    [1941, 2804, 678, 3168, 2504, 2679, 769, 3040, 878, 892],
    [874, 2925, 769, 2644],
    [1644, 2925, 2331, 2336, 769, 3067],
    [1644, 2490, 1646, 2331, 2783, 3007, 3073, 1723, 1709],
    [432, 439],
    [],
    [
      2320,
      962,
      2331,
      1721,
      877,
      863,
      2690,
      3071,
      582,
      2303,
      2667,
      2673,
      2675,
      1674,
      437,
    ],
    [
      586,
      2811,
      3079,
      1644,
      2918,
      2331,
      2336,
      876,
      892,
      872,
      3000,
      2256,
      2291,
      3125,
      1626,
      2669,
      2673,
      2675,
      1667,
      1607,
      427,
      425,
      2849,
    ],
    [1941, 2804, 678, 3168, 2504, 2679, 769, 3040, 2847, 876, 912, 2899, 1029],
    [1644, 2490, 1646, 2331, 2783, 3007, 3073, 1725],
    [432, 442],
    [1713],
    [
      586,
      2811,
      3079,
      1644,
      2918,
      2331,
      2336,
      892,
      1607,
      427,
      425,
      2845,
      877,
      871,
      3018,
      2894,
      686,
      1166,
      1132,
      3109,
      1626,
      2259,
      2295,
      606,
      2669,
      2673,
      2675,
      1667,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7],
    [8, 1, 2, 9, 10, 11, 6, 12],
  ];
}
