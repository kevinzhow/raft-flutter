// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `kbd`.
// ignore_for_file: type=lint

import '../recipe_runtime.dart';
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

/// raft-ui recipe `kbd` (`src/components/kbd/kbd.tsx`, index.mjs:4681).
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

  static RaftKbdRecipeStyle resolve({
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
    return RaftKbdRecipeStyle(root: s[0], group: s[1]);
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
      2739,
      2320,
      3167,
      2902,
      2331,
      2336,
      1721,
      3172,
      1716,
      1713,
      2868,
      423,
      413,
      2962,
      3032,
    ],
    [2320, 2331, 1721],
    [
      2739,
      2320,
      3167,
      2902,
      2331,
      2336,
      1721,
      3172,
      1716,
      2868,
      423,
      413,
      2603,
      2852,
      830,
      2778,
      2791,
      2956,
      1713,
      3018,
      2821,
      2827,
      2829,
      1003,
      1152,
      1156,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1],
    [2, 1],
  ];
}
