// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `messageTextSelectionToolbar`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftMessageTextSelectionToolbarRecipe].
class RaftMessageTextSelectionToolbarRecipeStyle {
  const RaftMessageTextSelectionToolbarRecipeStyle({
    required this.toolbar,
    required this.button,
    required this.separator,
  });

  /// Slot `toolbar`.
  final RaftSlotStyle toolbar;

  /// Slot `button`.
  final RaftSlotStyle button;

  /// Slot `separator`.
  final RaftSlotStyle separator;

  Map<String, RaftSlotStyle> get slots => {
    'toolbar': toolbar,
    'button': button,
    'separator': separator,
  };
}

/// raft-ui recipe `messageTextSelectionToolbar` (`src/components/message-item/message-text-selection-toolbar.recipe.ts`, index.mjs:7838).
///
/// Used by: MessageTextSelectionToolbar, MessageTextSelectionToolbarButton, MessageTextSelectionToolbarSeparator.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftMessageTextSelectionToolbarRecipe {
  static const String recipeName = 'messageTextSelectionToolbar';
  static const List<String> slotNames = ['toolbar', 'button', 'separator'];
  static const List<RaftRecipeAxis> axes = [];

  static RaftMessageTextSelectionToolbarRecipeStyle resolve({
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
    return RaftMessageTextSelectionToolbarRecipeStyle(
      toolbar: s[0],
      button: s[1],
      separator: s[2],
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
      1483,
      1319,
      1725,
      1020,
      1582,
      1708,
      1598,
      1819,
      1008,
      602,
      1692,
      1696,
      1735,
    ],
    [
      965,
      1319,
      1022,
      1575,
      1891,
      1188,
      1708,
      1657,
      1820,
      1272,
      427,
      996,
      280,
      294,
    ],
    [1928, 1517, 1183, 604],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2],
  ];
}
