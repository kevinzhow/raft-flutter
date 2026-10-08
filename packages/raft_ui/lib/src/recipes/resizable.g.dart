// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `resizable`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftResizableRecipe].
class RaftResizableRecipeStyle {
  const RaftResizableRecipeStyle({required this.group, required this.panel, required this.handle});

  /// Slot `group`.
  final RaftSlotStyle group;
  /// Slot `panel`.
  final RaftSlotStyle panel;
  /// Slot `handle`.
  final RaftSlotStyle handle;

  Map<String, RaftSlotStyle> get slots => {'group': group, 'panel': panel, 'handle': handle};
}

/// raft-ui recipe `resizable` (`src/components/resizable/resizable.recipe.ts`, index.mjs:16570).
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

  static RaftResizableRecipeStyle resolve({required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name], states, tokens);
    return RaftResizableRecipeStyle(group: s[0], panel: s[1], handle: s[2]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [1620, 2890, 2560, 2574, 1293],
    [2560, 2574],
    [2780, 3138, 940, 3045, 2834, 2775, 131, 133, 1620, 3108, 2867, 2312, 2317, 718, 688, 724, 712, 708, 728, 683, 721, 727, 703, 1645, 1631, 1633, 1632, 1273, 1272, 1288, 1289, 1285, 1290, 1280, 1276, 1275, 1274, 1277, 850, 697, 2182, 1331, 1629],
    [2780, 3138, 940, 3045, 2834, 2775, 131, 133, 1620, 3108, 2867, 2312, 2317, 718, 688, 724, 712, 708, 728, 683, 721, 727, 703, 1645, 1631, 1633, 1632, 1273, 1272, 1288, 1289, 1285, 1290, 1280, 1276, 1275, 1274, 1277, 850, 698, 2183, 1332, 1630],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2], [0, 1, 3],
  ];
}
