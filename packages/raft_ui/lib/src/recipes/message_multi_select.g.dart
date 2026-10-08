// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `messageMultiSelect`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftMessageMultiSelectRecipe].
class RaftMessageMultiSelectRecipeStyle {
  const RaftMessageMultiSelectRecipeStyle({required this.root, required this.checkbox, required this.toolbar});

  /// Slot `root`.
  final RaftSlotStyle root;
  /// Slot `checkbox`.
  final RaftSlotStyle checkbox;
  /// Slot `toolbar`.
  final RaftSlotStyle toolbar;

  Map<String, RaftSlotStyle> get slots => {'root': root, 'checkbox': checkbox, 'toolbar': toolbar};
}

/// raft-ui recipe `messageMultiSelect` (`src/components/message-item/message-multi-select.recipe.ts`, index.mjs:10032).
///
/// Used by: MessageMultiSelect, MessageMultiSelectCheckbox, MessageMultiSelectToolbar.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftMessageMultiSelectRecipe {
  static const String recipeName = 'messageMultiSelect';
  static const List<String> slotNames = ['root', 'checkbox', 'toolbar'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftMessageMultiSelectRecipeStyle resolve({required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name], states, tokens);
    return RaftMessageMultiSelectRecipeStyle(root: s[0], checkbox: s[1], toolbar: s[2]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [1620, 2560, 2574, 1621, 1622],
    [2599, 2837, 2815, 1428, 1494, 2257, 2260],
    [1620, 2312, 1697, 913, 900, 831, 2751, 2736, 2692],
    [1620, 2312, 1697, 2817, 867, 896, 825, 2752, 2766, 2865, 1009],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2], [0, 1, 3],
  ];
}
