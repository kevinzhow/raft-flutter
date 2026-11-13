// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `composerDropOverlay`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftComposerDropOverlayRecipe].
class RaftComposerDropOverlayRecipeStyle {
  const RaftComposerDropOverlayRecipeStyle({
    required this.dropOverlay,
    required this.dropOverlayLabel,
    required this.dropOverlayIconCluster,
    required this.dropOverlayIcon,
  });

  /// Slot `dropOverlay`.
  final RaftSlotStyle dropOverlay;

  /// Slot `dropOverlayLabel`.
  final RaftSlotStyle dropOverlayLabel;

  /// Slot `dropOverlayIconCluster`.
  final RaftSlotStyle dropOverlayIconCluster;

  /// Slot `dropOverlayIcon`.
  final RaftSlotStyle dropOverlayIcon;

  Map<String, RaftSlotStyle> get slots => {
    'dropOverlay': dropOverlay,
    'dropOverlayLabel': dropOverlayLabel,
    'dropOverlayIconCluster': dropOverlayIconCluster,
    'dropOverlayIcon': dropOverlayIcon,
  };
}

/// raft-ui recipe `composerDropOverlay` (`dist/components/composer/composer-drop-overlay.recipe.mjs`, index.mjs:16487).
///
/// Used by: ComposerDropOverlay, ComposerDropOverlayLabel, ComposerDropOverlayPrompt.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftComposerDropOverlayRecipe {
  static const String recipeName = 'composerDropOverlay';
  static const List<String> slotNames = [
    'dropOverlay',
    'dropOverlayLabel',
    'dropOverlayIconCluster',
    'dropOverlayIcon',
  ];
  static const List<RaftRecipeAxis> axes = [];

  static RaftComposerDropOverlayRecipeStyle resolve({
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
    return RaftComposerDropOverlayRecipeStyle(
      dropOverlay: s[0],
      dropOverlayLabel: s[1],
      dropOverlayIconCluster: s[2],
      dropOverlayIcon: s[3],
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
    [691, 1849, 2744, 1400, 1864, 1869, 2462, 941, 945, 954, 911, 882],
    [1400, 1404, 1864, 940, 2260, 2590, 1468, 1456, 2587, 1457, 2598],
    [2433, 1400, 1864, 1869, 1647, 2699],
    [2463, 2263, 911, 2497, 2445, 2448, 478],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3],
  ];
}
