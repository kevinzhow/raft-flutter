// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `resizable`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftResizableRecipe].
class RaftResizableRecipeStyle {
  const RaftResizableRecipeStyle({
    required this.group,
    required this.panel,
    required this.handle,
  });

  /// Slot `group`.
  final RaftSlotStyle group;

  /// Slot `panel`.
  final RaftSlotStyle panel;

  /// Slot `handle`.
  final RaftSlotStyle handle;

  Map<String, RaftSlotStyle> get slots => {
    'group': group,
    'panel': panel,
    'handle': handle,
  };
}

/// raft-ui recipe `resizable` (`src/components/resizable/resizable.recipe.ts`, index.mjs:13927).
///
/// Used by: ResizableGroup, ResizableHandle, ResizablePanel.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftResizableRecipe {
  static const String recipeName = 'resizable';
  static const List<String> slotNames = ['group', 'panel', 'handle'];
  static const List<RaftRecipeAxis> axes = [];

  static RaftResizableRecipeStyle resolve({
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
    return RaftResizableRecipeStyle(group: s[0], panel: s[1], handle: s[2]);
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
    [965, 1768, 1467, 1483, 721],
    [1467, 1483],
    [
      1684,
      1937,
      661,
      1868,
      1725,
      1680,
      95,
      97,
      965,
      1906,
      1738,
      1319,
      1324,
      545,
      513,
      559,
      529,
      986,
      973,
      976,
      974,
      705,
      704,
      718,
      719,
      715,
      720,
      710,
      615,
      554,
      542,
      535,
      564,
      560,
      551,
      521,
      1269,
      750,
      977,
      972,
      975,
      708,
      707,
      706,
      709,
      714,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2],
  ];
}
