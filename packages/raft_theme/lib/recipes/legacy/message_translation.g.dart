// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `messageTranslation`.
// ignore_for_file: type=lint

import '../recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftMessageTranslationRecipe].
class RaftMessageTranslationRecipeStyle {
  const RaftMessageTranslationRecipeStyle({
    required this.translationOriginal,
    required this.translationOriginalLabel,
    required this.translationStatus,
    required this.translationFailedStatus,
    required this.translationProgressTrack,
    required this.translationAction,
    required this.translationRetryAction,
  });

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

  Map<String, RaftSlotStyle> get slots => {
    'translationOriginal': translationOriginal,
    'translationOriginalLabel': translationOriginalLabel,
    'translationStatus': translationStatus,
    'translationFailedStatus': translationFailedStatus,
    'translationProgressTrack': translationProgressTrack,
    'translationAction': translationAction,
    'translationRetryAction': translationRetryAction,
  };
}

/// raft-ui recipe `messageTranslation` (`src/components/message-translation/message-translation.recipe.ts`, index.mjs:12137).
///
/// Used by: MessageItemTranslationAction, MessageItemTranslationFailedStatus, MessageItemTranslationOriginal, MessageItemTranslationOriginalLabel, MessageItemTranslationProgressTrack, MessageItemTranslationRetryAction, MessageItemTranslationStatus.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftMessageTranslationRecipe {
  static const String recipeName = 'messageTranslation';
  static const List<String> slotNames = [
    'translationOriginal',
    'translationOriginalLabel',
    'translationStatus',
    'translationFailedStatus',
    'translationProgressTrack',
    'translationAction',
    'translationRetryAction',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftMessageTranslationRecipeStyle resolve({
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
    return RaftMessageTranslationRecipeStyle(
      translationOriginal: s[0],
      translationOriginalLabel: s[1],
      translationStatus: s[2],
      translationFailedStatus: s[3],
      translationProgressTrack: s[4],
      translationAction: s[5],
      translationRetryAction: s[6],
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
    [2641],
    [2511, 2956, 1709, 3137, 3094, 2996],
    [2320, 2331, 1722, 1714, 2958, 2997],
    [2320, 2331, 1722, 1714, 2958, 3004],
    [],
    [2320, 2331, 1721, 1713, 3134, 3135, 1604, 2280],
    [2320, 2331, 1721, 3134, 3135, 1709, 3004, 1604, 2280],
    [2511, 2956, 1713, 3094, 3019],
    [2320, 2331, 1722, 2958, 2363, 3018],
    [2320, 2331, 1722, 2958, 2363, 3064],
    [1952],
    [2320, 2331, 1721, 1713, 3135, 3019, 2633, 2298],
    [
      2320,
      2331,
      1721,
      1713,
      3135,
      2852,
      2777,
      2790,
      3064,
      2633,
      3125,
      2255,
      2302,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6],
    [0, 7, 8, 9, 10, 11, 12],
  ];
}
