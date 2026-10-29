// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `composerDropOverlay`.
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

/// raft-ui recipe `composerDropOverlay` (`src/components/composer/composer-drop-overlay.recipe.ts`, index.mjs:11744).
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
    [422, 1307, 1942, 965, 1319, 1324, 1709, 622, 626, 634, 596, 569],
    [965, 967, 1319, 621, 1592, 1816, 1025, 1016, 1813, 1017, 1822],
    [1682, 965, 1319, 1324, 1173, 1907],
    [1710, 1595, 596, 1738, 1694, 1697, 280],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3],
  ];
}
