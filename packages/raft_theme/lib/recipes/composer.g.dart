// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `composer`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
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

/// raft-ui recipe `composer` (`src/components/composer/composer.recipe.ts`, index.mjs:11123).
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
  static const List<RaftRecipeAxis> axes = [];

  static RaftComposerRecipeStyle resolve({
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
    [
      965,
      1924,
      967,
      1022,
      1591,
      1705,
      622,
      1656,
      1643,
      1602,
      635,
      596,
      1818,
      1734,
      1001,
    ],
    [
      1358,
      1924,
      1679,
      615,
      1573,
      957,
      1583,
      1473,
      1651,
      1015,
      1806,
      1014,
      1818,
      1463,
      1624,
    ],
    [965, 1318, 1322, 1022],
    [965, 1318, 1022],
    [1753, 1706, 1823, 926, 924, 484, 482, 399, 266],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 3, 4],
  ];
}
