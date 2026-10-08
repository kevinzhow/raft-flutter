// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `messageTextSelectionToolbar`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftMessageTextSelectionToolbarRecipe].
class RaftMessageTextSelectionToolbarRecipeStyle {
  const RaftMessageTextSelectionToolbarRecipeStyle({required this.toolbar, required this.button, required this.separator});

  /// Slot `toolbar`.
  final RaftSlotStyle toolbar;
  /// Slot `button`.
  final RaftSlotStyle button;
  /// Slot `separator`.
  final RaftSlotStyle separator;

  Map<String, RaftSlotStyle> get slots => {'toolbar': toolbar, 'button': button, 'separator': separator};
}

/// raft-ui recipe `messageTextSelectionToolbar` (`src/components/message-item/message-text-selection-toolbar.recipe.ts`, index.mjs:10084).
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

  static RaftMessageTextSelectionToolbarRecipeStyle resolve({required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name], states, tokens);
    return RaftMessageTextSelectionToolbarRecipeStyle(toolbar: s[0], button: s[1], separator: s[2]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [1620, 2574, 2312, 2834, 2656, 3032, 866, 876, 856, 1692, 2863],
    [1620, 1964, 2312, 1697, 2751, 2649, 3084, 2956, 2228, 1636],
    [3129, 765],
    [1620, 2574, 2312, 2834, 2656, 3032, 1696, 2817, 867, 896, 825, 2669, 1688, 2865, 1009],
    [1620, 1964, 2312, 1697, 2751, 2649, 3084, 2822, 2981, 2212, 2276, 1635, 1669],
    [3129, 2174],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2], [3, 4, 5],
  ];
}
