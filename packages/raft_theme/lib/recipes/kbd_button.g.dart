// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `kbdButton`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftKbdButtonRecipe].
class RaftKbdButtonRecipeStyle {
  const RaftKbdButtonRecipeStyle({
    required this.root,
    required this.placeholder,
    required this.caret,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `placeholder`.
  final RaftSlotStyle placeholder;

  /// Slot `caret`.
  final RaftSlotStyle caret;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'placeholder': placeholder,
    'caret': caret,
  };
}

/// raft-ui recipe `kbdButton` (`dist/components/kbd-button/kbd-button.mjs`, index.mjs:29264).
///
/// Used by: KbdButton, KbdButtonCaret, KbdButtonPlaceholder.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftKbdButtonRecipe {
  static const String recipeName = 'kbdButton';
  static const List<String> slotNames = ['root', 'placeholder', 'caret'];
  static const List<RaftRecipeAxis> axes = [];

  static RaftKbdButtonRecipeStyle resolve({
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
    return RaftKbdButtonRecipeStyle(root: s[0], placeholder: s[1], caret: s[2]);
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
      2433,
      1847,
      2499,
      1864,
      1465,
      761,
      170,
      2461,
      2261,
      997,
      2483,
      2247,
      2660,
      1365,
      723,
      735,
      2191,
      2189,
      2190,
      1439,
      1301,
      1302,
      1300,
      1305,
      1303,
      1304,
      1297,
      1298,
      1296,
      1299,
      1249,
      1251,
      1250,
    ],
    [2398, 2729, 1456, 2587, 2600],
    [937, 1665, 2711, 2499, 897],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2],
  ];
}
