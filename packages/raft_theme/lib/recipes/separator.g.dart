// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `separator`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftSeparatorRecipe].
class RaftSeparatorRecipeStyle {
  const RaftSeparatorRecipeStyle({
    required this.root,
    required this.labeledRoot,
    required this.labeledLine,
    required this.labeledContent,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `labeledRoot`.
  final RaftSlotStyle labeledRoot;

  /// Slot `labeledLine`.
  final RaftSlotStyle labeledLine;

  /// Slot `labeledContent`.
  final RaftSlotStyle labeledContent;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'labeledRoot': labeledRoot,
    'labeledLine': labeledLine,
    'labeledContent': labeledContent,
  };
}

/// raft-ui recipe `separator` (`src/components/separator/separator.tsx`, index.mjs:13638).
///
/// Used by: ComboboxSeparator, ContextMenuSeparator, DropdownMenuSeparator, MessageTextSelectionToolbarSeparator, PopoverSeparator, PreviewCardSeparator, SelectSeparator, Separator.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftSeparatorRecipe {
  static const String recipeName = 'separator';
  static const List<String> slotNames = [
    'root',
    'labeledRoot',
    'labeledLine',
    'labeledContent',
  ];
  static const List<RaftRecipeAxis> axes = [];

  static RaftSeparatorRecipeStyle resolve({
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
    return RaftSeparatorRecipeStyle(
      root: s[0],
      labeledRoot: s[1],
      labeledLine: s[2],
      labeledContent: s[3],
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
    [1736, 720, 724, 604, 716, 726],
    [1039, 1044, 1318, 1024, 1669],
    [1924, 1736, 1198, 604],
    [1481, 1015, 1817, 1016, 1820],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3],
  ];
}
