// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `messageTextSelectionToolbar`.
// ignore_for_file: type=lint

import '../recipe_runtime.dart';
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

/// raft-ui recipe `messageTextSelectionToolbar` (`src/components/message-item/message-text-selection-toolbar.recipe.ts`, index.mjs:10122).
///
/// Used by: MessageTextSelectionToolbar, MessageTextSelectionToolbarButton, MessageTextSelectionToolbarSeparator.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftMessageTextSelectionToolbarRecipe {
  static const String recipeName = 'messageTextSelectionToolbar';
  static const List<String> slotNames = ['toolbar', 'button', 'separator'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftMessageTextSelectionToolbarRecipeStyle resolve({
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
    [1644, 2597, 2331, 2868, 2679, 3073, 878, 892, 868, 1717, 2897],
    [1644, 1966, 2331, 1722, 2779, 2672, 3125, 2994, 2247, 1660],
    [3170, 771],
    [
      1644,
      2597,
      2331,
      2868,
      2679,
      3073,
      1721,
      2847,
      879,
      912,
      830,
      2692,
      1713,
      2899,
      1029,
    ],
    [
      1644,
      1966,
      2331,
      1722,
      2779,
      2672,
      3125,
      2852,
      3018,
      2231,
      2295,
      1659,
      1693,
    ],
    [3170, 2189],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2],
    [3, 4, 5],
  ];
}
