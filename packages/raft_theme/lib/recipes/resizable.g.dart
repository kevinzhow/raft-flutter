// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `resizable`.
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

/// raft-ui recipe `resizable` (`dist/components/resizable/resizable.recipe.mjs`, index.mjs:19960).
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
    [1400, 2538, 2098, 2116, 1055],
    [2098, 2116],
    [
      2437,
      2739,
      994,
      2651,
      2483,
      2433,
      174,
      1400,
      2701,
      2499,
      1864,
      1869,
      2318,
      2344,
      849,
      810,
      865,
      828,
      1432,
      1411,
      1414,
      1412,
      1042,
      1053,
      1051,
      1054,
      1047,
      2330,
      2332,
      2331,
      933,
      860,
      807,
      837,
      870,
      866,
      857,
      818,
      1782,
      1078,
      1420,
      1417,
      1413,
      1043,
      1045,
      1044,
      1046,
      1050,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2],
  ];
}
