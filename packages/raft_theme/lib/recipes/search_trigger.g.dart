// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `searchTrigger`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftSearchTriggerRecipe].
class RaftSearchTriggerRecipeStyle {
  const RaftSearchTriggerRecipeStyle({
    required this.root,
    required this.label,
    required this.shortcut,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `label`.
  final RaftSlotStyle label;

  /// Slot `shortcut`.
  final RaftSlotStyle shortcut;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'label': label,
    'shortcut': shortcut,
  };
}

/// raft-ui recipe `searchTrigger` (`dist/components/search/search-trigger.mjs`, index.mjs:24820).
///
/// Used by: SearchTrigger, SearchTriggerLabel, SearchTriggerShortcut.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftSearchTriggerRecipe {
  static const String recipeName = 'searchTrigger';
  static const List<String> slotNames = ['root', 'label', 'shortcut'];
  static const List<RaftRecipeAxis> axes = [];

  static RaftSearchTriggerRecipeStyle resolve({
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
    return RaftSearchTriggerRecipeStyle(
      root: s[0],
      label: s[1],
      shortcut: s[2],
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
      2433,
      1847,
      1634,
      2720,
      1980,
      2116,
      2499,
      1864,
      1466,
      2403,
      2463,
      941,
      952,
      911,
      2613,
      1456,
      2585,
      1455,
      2600,
      2483,
      2247,
      2675,
      1365,
      699,
      1439,
      1353,
      1350,
      1347,
      1348,
      1363,
      777,
      775,
      772,
      773,
      783,
      472,
      474,
      329,
    ],
    [2116, 1401, 2681],
    [2132, 2499],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2],
  ];
}
