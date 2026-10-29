// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `messageSystem`.
// ignore_for_file: type=lint

import '../recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftMessageSystemRecipe].
class RaftMessageSystemRecipeStyle {
  const RaftMessageSystemRecipeStyle({
    required this.systemRoot,
    required this.systemTime,
    required this.systemContent,
    required this.systemGroup,
    required this.systemGroupHeader,
    required this.systemGroupDisclosure,
    required this.systemGroupSummary,
    required this.systemGroupChevron,
  });

  /// Slot `systemRoot`.
  final RaftSlotStyle systemRoot;

  /// Slot `systemTime`.
  final RaftSlotStyle systemTime;

  /// Slot `systemContent`.
  final RaftSlotStyle systemContent;

  /// Slot `systemGroup`.
  final RaftSlotStyle systemGroup;

  /// Slot `systemGroupHeader`.
  final RaftSlotStyle systemGroupHeader;

  /// Slot `systemGroupDisclosure`.
  final RaftSlotStyle systemGroupDisclosure;

  /// Slot `systemGroupSummary`.
  final RaftSlotStyle systemGroupSummary;

  /// Slot `systemGroupChevron`.
  final RaftSlotStyle systemGroupChevron;

  Map<String, RaftSlotStyle> get slots => {
    'systemRoot': systemRoot,
    'systemTime': systemTime,
    'systemContent': systemContent,
    'systemGroup': systemGroup,
    'systemGroupHeader': systemGroupHeader,
    'systemGroupDisclosure': systemGroupDisclosure,
    'systemGroupSummary': systemGroupSummary,
    'systemGroupChevron': systemGroupChevron,
  };
}

/// raft-ui recipe `messageSystem` (`src/components/system-message/system-message.recipe.ts`, index.mjs:10177).
///
/// Used by: SystemMessage, SystemMessageContent, SystemMessageGroup, SystemMessageGroupChevron, SystemMessageGroupDisclosure, SystemMessageGroupHeader, SystemMessageGroupSummary, SystemMessageTime.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftMessageSystemRecipe {
  static const String recipeName = 'messageSystem';
  static const List<String> slotNames = [
    'systemRoot',
    'systemTime',
    'systemContent',
    'systemGroup',
    'systemGroupHeader',
    'systemGroupDisclosure',
    'systemGroupSummary',
    'systemGroupChevron',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftMessageSystemRecipeStyle resolve({
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
    return RaftMessageSystemRecipeStyle(
      systemRoot: s[0],
      systemTime: s[1],
      systemContent: s[2],
      systemGroup: s[3],
      systemGroupHeader: s[4],
      systemGroupDisclosure: s[5],
      systemGroupSummary: s[6],
      systemGroupChevron: s[7],
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
    [1644, 2597, 2331, 2336, 1723, 2779, 2702, 2756],
    [2902, 3172, 2996, 1714, 3073],
    [2597, 3133, 2998, 3073],
    [],
    [1644, 2336, 2702, 2756],
    [
      1751,
      2804,
      1644,
      2505,
      2331,
      1722,
      2779,
      2702,
      2998,
      2293,
      329,
      2772,
      3073,
    ],
    [3133],
    [2913, 2902, 2836, 2995, 3128],
    [1644, 2597, 2331, 2336, 1723, 2779, 2702, 2769],
    [2902, 3172, 2996, 1716, 2958, 1713, 2946, 1189],
    [2597, 3133, 2998, 1716, 2960, 1190],
    [1644, 2336, 2702, 2772],
    [
      1751,
      2804,
      1644,
      2505,
      2331,
      1722,
      2779,
      2702,
      2998,
      2293,
      329,
      2757,
      2848,
      1716,
      2960,
      3125,
      1190,
      1136,
    ],
    [2913, 2902, 2836, 2995, 3128, 1188],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7],
    [8, 9, 10, 3, 11, 12, 6, 13],
  ];
}
