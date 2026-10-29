// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `messageTranslation`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
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

/// raft-ui recipe `messageTranslation` (`src/components/message-translation/message-translation.recipe.ts`, index.mjs:9720).
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
  static const List<RaftRecipeAxis> axes = [];

  static RaftMessageTranslationRecipeStyle resolve({
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
    [1551, 1511],
    [1430, 1014, 1839, 1824],
    [1305, 1319, 1022, 1511, 1014, 1839, 1824, 278],
    [1305, 1319, 1022, 1511, 1014, 1839, 1856, 278],
    [1172],
    [
      1305,
      1319,
      1021,
      1898,
      1704,
      1016,
      1814,
      1017,
      1822,
      915,
      1900,
      1281,
      1577,
      996,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 5],
  ];
}
