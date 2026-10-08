// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `composer`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftComposerRecipe].
class RaftComposerRecipeStyle {
  const RaftComposerRecipeStyle({required this.root, required this.input, required this.toolbar, required this.actions, required this.meta, required this.iconButton});

  /// Slot `root`.
  final RaftSlotStyle root;
  /// Slot `input`.
  final RaftSlotStyle input;
  /// Slot `toolbar`.
  final RaftSlotStyle toolbar;
  /// Slot `actions`.
  final RaftSlotStyle actions;
  /// Slot `meta`.
  final RaftSlotStyle meta;
  /// Slot `iconButton`.
  final RaftSlotStyle iconButton;

  Map<String, RaftSlotStyle> get slots => {'root': root, 'input': input, 'toolbar': toolbar, 'actions': actions, 'meta': meta, 'iconButton': iconButton};
}

/// raft-ui recipe `composer` (`src/components/composer/composer.recipe.ts`, index.mjs:13057).
///
/// Used by: Composer, ComposerActions, ComposerIconButton, ComposerInput, ComposerMeta, ComposerToolbar.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftComposerRecipe {
  static const String recipeName = 'composer';
  static const List<String> slotNames = ['root', 'input', 'toolbar', 'actions', 'meta', 'iconButton'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftComposerRecipeStyle resolve({required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name], states, tokens);
    return RaftComposerRecipeStyle(root: s[0], input: s[1], toolbar: s[2], actions: s[3], meta: s[4], iconButton: s[5]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [1620, 3127, 1622, 1698, 866, 2671, 876, 856, 2863, 1673],
    [2564, 2362, 3127, 2776, 850, 2955, 2335, 2649, 2557, 1617, 2661, 1691, 2956, 2710],
    [1620, 2312, 2316, 1700],
    [1620, 2312, 1698],
    [1620, 2312, 1700],
    [2888, 2669, 876, 856, 2956, 2863, 2176, 2241, 2237, 2268, 608, 605],
    [1620, 3127, 1622, 1698, 2656, 2817, 865, 2667, 825, 2863, 2791, 2796, 1144, 1133, 1068, 1069],
    [2362, 3127, 2776, 850, 2955, 2335, 2649, 2557, 1617, 2661, 2562, 2753, 2737, 1691, 2987, 2711],
    [1620, 2312, 2316, 3090, 1698, 2752, 2733, 2684],
    [1620, 2312, 1697],
    [1620, 2312, 1701],
    [2676, 2978, 2214, 2280, 587, 607],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5], [6, 7, 8, 9, 10, 11],
  ];
}
