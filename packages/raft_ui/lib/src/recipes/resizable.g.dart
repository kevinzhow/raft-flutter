// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
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

/// raft-ui recipe `resizable` (`src/components/resizable/resizable.recipe.ts`, index.mjs:16824).
///
/// Used by: ResizableGroup, ResizableHandle, ResizablePanel.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftResizableRecipe {
  static const String recipeName = 'resizable';
  static const List<String> slotNames = ['group', 'panel', 'handle'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftResizableRecipeStyle resolve({
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
    [1644, 2925, 2583, 2597, 1315],
    [2583, 2597],
    [
      2809,
      3179,
      960,
      3086,
      2868,
      2804,
      131,
      133,
      1644,
      3149,
      2902,
      2331,
      2336,
      724,
      694,
      730,
      718,
      714,
      734,
      689,
      727,
      733,
      709,
      1669,
      1655,
      1657,
      1656,
      1295,
      1294,
      1310,
      1311,
      1307,
      1312,
      1302,
      1298,
      1297,
      1296,
      1299,
      863,
      703,
      2201,
      1353,
      1653,
    ],
    [
      2809,
      3179,
      960,
      3086,
      2868,
      2804,
      131,
      133,
      1644,
      3149,
      2902,
      2331,
      2336,
      724,
      694,
      730,
      718,
      714,
      734,
      689,
      727,
      733,
      709,
      1669,
      1655,
      1657,
      1656,
      1295,
      1294,
      1310,
      1311,
      1307,
      1312,
      1302,
      1298,
      1297,
      1296,
      1299,
      863,
      704,
      2202,
      1354,
      1654,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2],
    [0, 1, 3],
  ];
}
