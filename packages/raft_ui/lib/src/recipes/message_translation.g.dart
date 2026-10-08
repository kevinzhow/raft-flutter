// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `messageTranslation`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftMessageTranslationRecipe].
class RaftMessageTranslationRecipeStyle {
  const RaftMessageTranslationRecipeStyle({required this.translationOriginal, required this.translationOriginalLabel, required this.translationStatus, required this.translationFailedStatus, required this.translationProgressTrack, required this.translationAction, required this.translationRetryAction});

  /// Slot `translationOriginal`.
  final RaftSlotStyle translationOriginal;
  /// Slot `translationOriginalLabel`.
  final RaftSlotStyle translationOriginalLabel;
  /// Slot `translationStatus`.
  final RaftSlotStyle translationStatus;
  /// Slot `translationFailedStatus`.
  final RaftSlotStyle translationFailedStatus;
  /// Slot `translationProgressTrack`.
  final RaftSlotStyle translationProgressTrack;
  /// Slot `translationAction`.
  final RaftSlotStyle translationAction;
  /// Slot `translationRetryAction`.
  final RaftSlotStyle translationRetryAction;

  Map<String, RaftSlotStyle> get slots => {'translationOriginal': translationOriginal, 'translationOriginalLabel': translationOriginalLabel, 'translationStatus': translationStatus, 'translationFailedStatus': translationFailedStatus, 'translationProgressTrack': translationProgressTrack, 'translationAction': translationAction, 'translationRetryAction': translationRetryAction};
}

/// raft-ui recipe `messageTranslation` (`src/components/message-translation/message-translation.recipe.ts`, index.mjs:12094).
///
/// Used by: MessageItemTranslationAction, MessageItemTranslationFailedStatus, MessageItemTranslationOriginal, MessageItemTranslationOriginalLabel, MessageItemTranslationProgressTrack, MessageItemTranslationRetryAction, MessageItemTranslationStatus.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftMessageTranslationRecipe {
  static const String recipeName = 'messageTranslation';
  static const List<String> slotNames = ['translationOriginal', 'translationOriginalLabel', 'translationStatus', 'translationFailedStatus', 'translationProgressTrack', 'translationAction', 'translationRetryAction'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftMessageTranslationRecipeStyle resolve({required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name], states, tokens);
    return RaftMessageTranslationRecipeStyle(translationOriginal: s[0], translationOriginalLabel: s[1], translationStatus: s[2], translationFailedStatus: s[3], translationProgressTrack: s[4], translationAction: s[5], translationRetryAction: s[6]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [2619],
    [2490, 2918, 1684, 3096, 3053, 2959],
    [2301, 2312, 1697, 1689, 2920, 2960],
    [2301, 2312, 1697, 1689, 2920, 2967],
    [],
    [2301, 2312, 1696, 1688, 3093, 3094, 1580, 2261],
    [2301, 2312, 1696, 3093, 3094, 1684, 2967, 1580, 2261],
    [2490, 2918, 1688, 3053, 2982],
    [2301, 2312, 1697, 2920, 2344, 2981],
    [2301, 2312, 1697, 2920, 2344, 3023],
    [1950],
    [2301, 2312, 1696, 1688, 3094, 2982, 2611, 2279],
    [2301, 2312, 1696, 1688, 3094, 2822, 2749, 2761, 3023, 2611, 3084, 2236, 2283],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6], [0, 7, 8, 9, 10, 11, 12],
  ];
}
