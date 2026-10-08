// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `kbd`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftKbdRecipe].
class RaftKbdRecipeStyle {
  const RaftKbdRecipeStyle({required this.root, required this.group});

  /// Slot `root`.
  final RaftSlotStyle root;
  /// Slot `group`.
  final RaftSlotStyle group;

  Map<String, RaftSlotStyle> get slots => {'root': root, 'group': group};
}

/// raft-ui recipe `kbd` (`src/components/kbd/kbd.tsx`, index.mjs:4669).
///
/// Used by: Kbd, KbdGroup.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftKbdRecipe {
  static const String recipeName = 'kbd';
  static const List<String> slotNames = ['root', 'group'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftKbdRecipeStyle resolve({required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name], states, tokens);
    return RaftKbdRecipeStyle(root: s[0], group: s[1]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [2716, 2301, 3126, 2867, 2312, 2317, 1696, 3131, 1691, 1688, 2834, 425, 415, 2924, 2995],
    [2301, 2312, 1696],
    [2716, 2301, 3126, 2867, 2312, 2317, 1696, 3131, 1691, 2834, 425, 415, 2580, 2822, 825, 2750, 2762, 2918, 1688, 2981, 2791, 2797, 2799, 983, 1133, 1137],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1], [2, 1],
  ];
}
