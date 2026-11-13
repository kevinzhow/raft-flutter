// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `messageSystem`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
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

/// raft-ui recipe `messageSystem` (`dist/components/system-message/system-message.recipe.mjs`, index.mjs:12998).
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
  static const List<RaftRecipeAxis> axes = [];

  static RaftMessageSystemRecipeStyle resolve({
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
    [
      1400,
      2116,
      1864,
      1869,
      1466,
      2405,
      2392,
      2291,
      1805,
      1454,
      2616,
      2600,
      846,
      832,
      825,
      823,
      743,
      731,
      728,
      726,
    ],
    [2499, 2729, 1454, 2616, 2600],
    [2116, 2681, 2600],
    [1623],
    [
      1400,
      1869,
      1864,
      1466,
      2405,
      2388,
      1993,
      1569,
      1570,
      846,
      832,
      825,
      823,
      743,
      731,
      728,
      726,
    ],
    [
      1503,
      2433,
      1400,
      1980,
      1864,
      376,
      1659,
      1464,
      2463,
      2401,
      2412,
      1454,
      2616,
      2600,
      1785,
      1798,
      697,
      2247,
      1439,
    ],
    [2681],
    [2515, 2499, 2452, 2678, 2600],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7],
  ];
}
