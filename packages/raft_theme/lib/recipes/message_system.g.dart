// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `messageSystem`.
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

/// raft-ui recipe `messageSystem` (`src/components/system-message/system-message.recipe.ts`, index.mjs:7882).
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
      965,
      1483,
      1319,
      1324,
      1023,
      1660,
      1671,
      1291,
      1014,
      1837,
      1822,
      543,
      530,
      526,
      524,
      457,
      451,
      448,
      446,
    ],
    [1738, 1930, 1014, 1837, 1822],
    [1483, 1895, 1822],
    [],
    [965, 1324, 1319, 1023, 1660, 1667, 543, 530, 526, 524, 457, 451, 448, 446],
    [
      1050,
      1680,
      965,
      1424,
      1319,
      203,
      1186,
      1021,
      1708,
      1656,
      1664,
      1014,
      1837,
      1822,
      1272,
      1285,
      1575,
      996,
    ],
    [1895],
    [1749, 1738, 1699, 1894, 1822],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7],
  ];
}
