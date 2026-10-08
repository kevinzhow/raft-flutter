// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `messageVideoPreview`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftMessageVideoPreviewRecipe].
class RaftMessageVideoPreviewRecipeStyle {
  const RaftMessageVideoPreviewRecipeStyle({required this.root, required this.media, required this.fallback, required this.failureContent, required this.failureIcon, required this.failureTitle, required this.failureAction, required this.action});

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

  Map<String, RaftSlotStyle> get slots => {'root': root, 'media': media, 'fallback': fallback, 'failureContent': failureContent, 'failureIcon': failureIcon, 'failureTitle': failureTitle, 'failureAction': failureAction, 'action': action};
}

/// raft-ui recipe `messageVideoPreview` (`src/components/message-attachment/message-video-preview.recipe.ts`, index.mjs:11320).
///
/// Used by: MessageVideoPreview, MessageVideoPreviewAction, MessageVideoPreviewFailureAction, MessageVideoPreviewFailureContent, MessageVideoPreviewFailureIcon, MessageVideoPreviewFailureTitle, MessageVideoPreviewFallback, MessageVideoPreviewMedia.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftMessageVideoPreviewRecipe {
  static const String recipeName = 'messageVideoPreview';
  static const List<String> slotNames = ['root', 'media', 'fallback', 'failureContent', 'failureIcon', 'failureTitle', 'failureAction', 'action'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftMessageVideoPreviewRecipeStyle resolve({required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name], states, tokens);
    return RaftMessageVideoPreviewRecipeStyle(root: s[0], media: s[1], fallback: s[2], failureContent: s[3], failureIcon: s[4], failureTitle: s[5], failureAction: s[6], action: s[7]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [1939, 2775, 672, 3127, 2483, 2656, 763, 3003, 866, 876],
    [862, 2890, 763, 2622],
    [1620, 2890, 2312, 2317, 763, 3026],
    [1620, 2469, 1622, 2312, 2755, 2970, 3032, 1698, 1684],
    [434, 441],
    [],
    [2301, 942, 2312, 1696, 865, 850, 2667, 3030, 577, 2284, 2644, 2650, 2652, 1650, 439],
    [580, 2782, 3038, 1620, 2883, 2312, 2317, 864, 876, 860, 2963, 2237, 2272, 3084, 1602, 2646, 2650, 2652, 1643, 1583, 429, 427, 2819],
    [1939, 2775, 672, 3127, 2483, 2656, 763, 3003, 2817, 864, 896, 2865, 1009],
    [1620, 2469, 1622, 2312, 2755, 2970, 3032, 1700],
    [434, 444],
    [1688],
    [580, 2782, 3038, 1620, 2883, 2312, 2317, 876, 1583, 429, 427, 2815, 865, 859, 2981, 2860, 680, 1147, 1112, 3068, 1602, 2240, 2276, 600, 2646, 2650, 2652, 1643],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7], [8, 1, 2, 9, 10, 11, 6, 12],
  ];
}
