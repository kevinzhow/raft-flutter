// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `composerDropOverlay`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftComposerDropOverlayRecipe].
class RaftComposerDropOverlayRecipeStyle {
  const RaftComposerDropOverlayRecipeStyle({required this.dropOverlay, required this.dropOverlayLabel, required this.dropOverlayIconCluster, required this.dropOverlayIcon});

  /// Slot `dropOverlay`.
  final RaftSlotStyle dropOverlay;
  /// Slot `dropOverlayLabel`.
  final RaftSlotStyle dropOverlayLabel;
  /// Slot `dropOverlayIconCluster`.
  final RaftSlotStyle dropOverlayIconCluster;
  /// Slot `dropOverlayIcon`.
  final RaftSlotStyle dropOverlayIcon;

  Map<String, RaftSlotStyle> get slots => {'dropOverlay': dropOverlay, 'dropOverlayLabel': dropOverlayLabel, 'dropOverlayIconCluster': dropOverlayIconCluster, 'dropOverlayIcon': dropOverlayIcon};
}

/// raft-ui recipe `composerDropOverlay` (`src/components/composer/composer-drop-overlay.recipe.ts`, index.mjs:13728).
///
/// Used by: ComposerDropOverlay, ComposerDropOverlayLabel, ComposerDropOverlayPrompt.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftComposerDropOverlayRecipe {
  static const String recipeName = 'composerDropOverlay';
  static const List<String> slotNames = ['dropOverlay', 'dropOverlayLabel', 'dropOverlayIconCluster', 'dropOverlayIcon'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftComposerDropOverlayRecipeStyle resolve({required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name], states, tokens);
    return RaftComposerDropOverlayRecipeStyle(dropOverlay: s[0], dropOverlayLabel: s[1], dropOverlayIconCluster: s[2], dropOverlayIcon: s[3]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [580, 2303, 3140, 1620, 2312, 2317, 866, 886, 876, 819],
    [1620, 1622, 2312, 1701, 865, 2667, 2970, 1688, 2979, 1168, 3017],
    [2775, 1620, 2312, 2317, 1967, 3104],
    [825, 2862, 2791, 2800, 1133, 2819, 2670, 430],
    [580, 3140, 1620, 2312, 2317, 129, 2824, 865, 755],
    [1620, 1622, 2312, 1701, 865, 2667, 2970, 1688, 2979, 1168, 2955],
    [2775, 1620, 2312, 2317, 1951, 3107],
    [825, 2862, 2791, 2800, 1133, 2818, 2671, 431],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3], [4, 5, 6, 7],
  ];
}
