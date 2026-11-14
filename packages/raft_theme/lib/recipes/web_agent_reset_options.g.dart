// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `webAgentResetOptions`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftWebAgentResetOptionsRecipe].
class RaftWebAgentResetOptionsRecipeStyle {
  const RaftWebAgentResetOptionsRecipeStyle({
    required this.root,
    required this.row,
    required this.indicator,
    required this.content,
    required this.title,
    required this.description,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `row`.
  final RaftSlotStyle row;

  /// Slot `indicator`.
  final RaftSlotStyle indicator;

  /// Slot `content`.
  final RaftSlotStyle content;

  /// Slot `title`.
  final RaftSlotStyle title;

  /// Slot `description`.
  final RaftSlotStyle description;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'row': row,
    'indicator': indicator,
    'content': content,
    'title': title,
    'description': description,
  };
}

/// raft-ui recipe `webAgentResetOptions` (`Web src/components/agent/ResetAgentDialog.tsx sha256:98d774a5ff4dfe780462523c6c693de92e62da3700514cf6d396c5927522f903`, index.mjs:1).
///
/// Used by: ResetAgentDialogRadioOptions.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftWebAgentResetOptionsRecipe {
  static const String recipeName = 'webAgentResetOptions';
  static const List<String> slotNames = [
    'root',
    'row',
    'indicator',
    'content',
    'title',
    'description',
  ];
  static const List<RaftRecipeAxis> axes = [];

  static RaftWebAgentResetOptionsRecipeStyle resolve({
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
    return RaftWebAgentResetOptionsRecipeStyle(
      root: s[0],
      row: s[1],
      indicator: s[2],
      content: s[3],
      title: s[4],
      description: s[5],
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
    [1462],
    [1400, 2100, 1866, 1468, 2419],
    [2499],
    [1400, 2116, 1404, 1463],
    [2622, 1457, 2598],
    [2597, 1455, 2603],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5],
  ];
}
