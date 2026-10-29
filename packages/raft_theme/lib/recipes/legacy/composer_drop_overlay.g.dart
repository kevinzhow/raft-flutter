// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `composerDropOverlay`.
// ignore_for_file: type=lint

import '../recipe_runtime.dart';
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

/// raft-ui recipe `composerDropOverlay` (`src/components/composer/composer-drop-overlay.recipe.ts`, index.mjs:13954).
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
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftComposerDropOverlayRecipeStyle resolve({
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
    [586, 2322, 3181, 1644, 2331, 2336, 878, 902, 892, 824],
    [1644, 1646, 2331, 1726, 877, 2690, 3007, 1713, 3016, 1187, 3053],
    [2804, 1644, 2331, 2336, 1969, 3145],
    [830, 2896, 2821, 2830, 1152, 2849, 2693, 428],
    [586, 3181, 1644, 2331, 2336, 129, 2854, 877, 761],
    [1644, 1646, 2331, 1726, 877, 2690, 3007, 1713, 3016, 1187, 2993],
    [2804, 1644, 2331, 2336, 1953, 3148],
    [830, 2896, 2821, 2830, 1152, 2848, 2694, 429],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3],
    [4, 5, 6, 7],
  ];
}
