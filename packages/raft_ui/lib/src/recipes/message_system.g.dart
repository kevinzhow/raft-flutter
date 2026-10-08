// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `messageSystem`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftMessageSystemRecipe].
class RaftMessageSystemRecipeStyle {
  const RaftMessageSystemRecipeStyle({required this.systemRoot, required this.systemTime, required this.systemContent, required this.systemGroup, required this.systemGroupHeader, required this.systemGroupDisclosure, required this.systemGroupSummary, required this.systemGroupChevron});

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

  Map<String, RaftSlotStyle> get slots => {'systemRoot': systemRoot, 'systemTime': systemTime, 'systemContent': systemContent, 'systemGroup': systemGroup, 'systemGroupHeader': systemGroupHeader, 'systemGroupDisclosure': systemGroupDisclosure, 'systemGroupSummary': systemGroupSummary, 'systemGroupChevron': systemGroupChevron};
}

/// raft-ui recipe `messageSystem` (`src/components/system-message/system-message.recipe.ts`, index.mjs:10139).
///
/// Used by: SystemMessage, SystemMessageContent, SystemMessageGroup, SystemMessageGroupChevron, SystemMessageGroupDisclosure, SystemMessageGroupHeader, SystemMessageGroupSummary, SystemMessageTime.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftMessageSystemRecipe {
  static const String recipeName = 'messageSystem';
  static const List<String> slotNames = ['systemRoot', 'systemTime', 'systemContent', 'systemGroup', 'systemGroupHeader', 'systemGroupDisclosure', 'systemGroupSummary', 'systemGroupChevron'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftMessageSystemRecipeStyle resolve({required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name], states, tokens);
    return RaftMessageSystemRecipeStyle(systemRoot: s[0], systemTime: s[1], systemContent: s[2], systemGroup: s[3], systemGroupHeader: s[4], systemGroupDisclosure: s[5], systemGroupSummary: s[6], systemGroupChevron: s[7]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [1620, 2574, 2312, 2317, 2491, 1698, 2751, 2763],
    [2867, 3131, 2959, 1689, 3032],
    [2574, 3092, 2961, 3032],
    [2491],
    [1620, 2317, 2763],
    [1726, 1620, 2484, 2312, 1697, 2751, 2762, 2961, 2274, 331, 3032],
    [3092],
    [2878, 2867, 2806, 2958, 3087],
    [2867, 3131, 2959, 1691, 2920, 1688, 2911, 1170],
    [2574, 3092, 2961, 1691, 2922, 1171],
    [1726, 1620, 2484, 2312, 1697, 2751, 2762, 2961, 2274, 331, 2818, 1691, 2922, 3084, 1171, 1116],
    [2878, 2867, 2806, 2958, 3087, 1169],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7], [0, 8, 9, 3, 4, 10, 6, 11],
  ];
}
