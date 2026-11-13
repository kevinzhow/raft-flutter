// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `composer`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftComposerRecipe].
class RaftComposerRecipeStyle {
  const RaftComposerRecipeStyle({
    required this.root,
    required this.inputFrame,
    required this.input,
    required this.toolbar,
    required this.actions,
    required this.meta,
    required this.iconButton,
    required this.submit,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `inputFrame`.
  final RaftSlotStyle inputFrame;

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

  /// Slot `submit`.
  final RaftSlotStyle submit;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'inputFrame': inputFrame,
    'input': input,
    'toolbar': toolbar,
    'actions': actions,
    'meta': meta,
    'iconButton': iconButton,
    'submit': submit,
  };
}

/// raft-ui recipe `composer` (`dist/components/composer/composer.recipe.mjs`, index.mjs:16067).
///
/// Used by: Composer, ComposerActions, ComposerIconButton, ComposerInput, ComposerMeta, ComposerSubmit, ComposerToolbar.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftComposerRecipe {
  static const String recipeName = 'composer';
  static const List<String> slotNames = [
    'root',
    'inputFrame',
    'input',
    'toolbar',
    'actions',
    'meta',
    'iconButton',
    'submit',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('icon', ['true', 'false'], null, true),
  ];

  static RaftComposerRecipeStyle resolve({
    bool? icon,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [icon?.toString()],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftComposerRecipeStyle(
      root: s[0],
      inputFrame: s[1],
      input: s[2],
      toolbar: s[3],
      actions: s[4],
      meta: s[5],
      iconButton: s[6],
      submit: s[7],
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
    [
      1400,
      2725,
      1404,
      1466,
      2263,
      2462,
      941,
      2403,
      2383,
      2285,
      952,
      911,
      2598,
      2497,
      1775,
    ],
    [2725, 2116, 575],
    [
      1912,
      2725,
      2434,
      933,
      2247,
      1388,
      2104,
      2398,
      1456,
      2585,
      1455,
      2598,
      2311,
    ],
    [1400, 1864, 1868, 2155, 1475, 2054],
    [1400, 1864, 1475],
    [2522, 2461, 2603, 2079, 2076, 2025, 2020, 1351, 1349, 776, 774, 461],
    [2461],
    [2461, 2079, 2076, 2025, 2020],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 4, 5, 6],
    [0, 1, 2, 3, 4, 4, 5, 7],
    [0, 1, 2, 3, 4, 4, 5, 6],
  ];
}
