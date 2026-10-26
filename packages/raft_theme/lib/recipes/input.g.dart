// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `input`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftInputRecipe].
class RaftInputRecipeStyle {
  const RaftInputRecipeStyle({required this.root});

  /// Slot `root`.
  final RaftSlotStyle root;

  Map<String, RaftSlotStyle> get slots => {'root': root};
}

/// raft-ui recipe `input` (`src/components/input/input.recipe.ts`, index.mjs:5051).
///
/// Used by: ComboboxInput, ComposerInput, Input.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftInputRecipe {
  static const String recipeName = 'input';
  static const List<String> slotNames = ['root'];
  static const List<RaftRecipeAxis> axes = [];

  static const List<RaftRecipePackBinding> _packBindings = [
    RaftRecipePackBinding(
      'root',
      'border-top-left-radius',
      RaftRecipeTokenKind.number,
      'radius.control',
    ),
    RaftRecipePackBinding(
      'root',
      'border-top-right-radius',
      RaftRecipeTokenKind.number,
      'radius.control',
    ),
    RaftRecipePackBinding(
      'root',
      'border-bottom-left-radius',
      RaftRecipeTokenKind.number,
      'radius.control',
    ),
    RaftRecipePackBinding(
      'root',
      'border-bottom-right-radius',
      RaftRecipeTokenKind.number,
      'radius.control',
    ),
  ];

  static RaftInputRecipeStyle resolve({
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
      bindings: _packBindings,
    );
    return RaftInputRecipeStyle(root: s[0]);
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
      bindings: _packBindings,
    );
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [
      1173,
      1924,
      1656,
      1662,
      1011,
      1816,
      1010,
      1573,
      1706,
      622,
      635,
      596,
      1818,
      1624,
      1734,
      1891,
      947,
      950,
      1005,
      869,
      928,
      925,
      922,
      938,
      934,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0],
  ];
}
