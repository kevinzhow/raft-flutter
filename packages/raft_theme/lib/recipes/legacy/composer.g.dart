// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `composer`.
// ignore_for_file: type=lint

import '../recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftComposerRecipe].
class RaftComposerRecipeStyle {
  const RaftComposerRecipeStyle({
    required this.root,
    required this.input,
    required this.toolbar,
    required this.actions,
    required this.meta,
    required this.iconButton,
  });

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

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'input': input,
    'toolbar': toolbar,
    'actions': actions,
    'meta': meta,
    'iconButton': iconButton,
  };
}

/// raft-ui recipe `composer` (`src/components/composer/composer.recipe.ts`, index.mjs:13278).
///
/// Used by: Composer, ComposerActions, ComposerIconButton, ComposerInput, ComposerMeta, ComposerToolbar.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftComposerRecipe {
  static const String recipeName = 'composer';
  static const List<String> slotNames = [
    'root',
    'input',
    'toolbar',
    'actions',
    'meta',
    'iconButton',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftComposerRecipeStyle resolve({
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
    return RaftComposerRecipeStyle(
      root: s[0],
      input: s[1],
      toolbar: s[2],
      actions: s[3],
      meta: s[4],
      iconButton: s[5],
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
    [1644, 3168, 1646, 1723, 878, 2694, 892, 868, 2897, 1698],
    [
      2587,
      2381,
      3168,
      2805,
      863,
      2993,
      2354,
      2672,
      2580,
      1641,
      2684,
      1716,
      2994,
      2733,
    ],
    [1644, 2331, 2335, 1725],
    [1644, 2331, 1723],
    [1644, 2331, 1725],
    [2923, 2692, 892, 868, 2994, 2897, 2191, 2260, 2256, 2287, 614, 611],
    [
      1644,
      3168,
      1646,
      1723,
      2679,
      2847,
      877,
      2690,
      830,
      2897,
      2821,
      2826,
      1163,
      1152,
      1088,
      1089,
    ],
    [
      2381,
      3168,
      2805,
      863,
      2993,
      2354,
      2672,
      2580,
      1641,
      2684,
      2585,
      2781,
      2762,
      1716,
      3024,
      2734,
    ],
    [1644, 2331, 2335, 3131, 1723, 2780, 2758, 2707],
    [1644, 2331, 1722],
    [1644, 2331, 1726],
    [2699, 3015, 2233, 2299, 593, 613],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5],
    [6, 7, 8, 9, 10, 11],
  ];
}
