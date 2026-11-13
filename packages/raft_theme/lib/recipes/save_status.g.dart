// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `saveStatus`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftSaveStatusRecipe].
class RaftSaveStatusRecipeStyle {
  const RaftSaveStatusRecipeStyle({required this.root, required this.error});

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `error`.
  final RaftSlotStyle error;

  Map<String, RaftSlotStyle> get slots => {'root': root, 'error': error};
}

/// raft-ui recipe `saveStatus` (`dist/components/save-status/save-status.mjs`, index.mjs:29174).
///
/// Used by: SaveStatus, SaveStatusError.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftSaveStatusRecipe {
  static const String recipeName = 'saveStatus';
  static const List<String> slotNames = ['root', 'error'];
  static const List<RaftRecipeAxis> axes = [];

  static RaftSaveStatusRecipeStyle resolve({
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
    return RaftSaveStatusRecipeStyle(root: s[0], error: s[1]);
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
    [937, 2116, 1378, 2145, 640, 643, 2597],
    [937, 2733, 2594],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1],
  ];
}
