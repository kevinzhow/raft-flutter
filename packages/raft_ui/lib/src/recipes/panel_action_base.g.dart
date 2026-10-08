// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `panelActionBase`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftPanelActionBaseRecipe].
class RaftPanelActionBaseRecipeStyle {
  const RaftPanelActionBaseRecipeStyle({required this.base});

  /// Slot `base`.
  final RaftSlotStyle base;

  Map<String, RaftSlotStyle> get slots => {'base': base};
}

/// raft-ui recipe `panelActionBase` (`src/components/panel/panel-action.recipe.ts`, index.mjs:16299).
///
/// Used by: PanelAction, PanelToggleAction.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftPanelActionBaseRecipe {
  static const String recipeName = 'panelActionBase';
  static const List<String> slotNames = ['base'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftPanelActionBaseRecipeStyle resolve({required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name], states, tokens);
    return RaftPanelActionBaseRecipeStyle(base: s[0]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [2775, 2301, 3125, 2867, 2312, 2317, 2657, 1691, 2344, 2911, 2834, 2649, 3083, 1601, 298, 302, 2819, 866, 876, 856, 2749, 2772, 2956, 2863, 2176, 2237, 2268, 1639, 1647, 1642, 304],
    [2775, 2301, 3125, 2867, 2312, 2317, 2657, 1691, 2344, 2911, 2834, 2649, 3083, 1601, 298, 302, 2818, 865, 850, 2751, 2765, 2214, 2280, 1654, 1667, 305],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0], [1],
  ];
}
