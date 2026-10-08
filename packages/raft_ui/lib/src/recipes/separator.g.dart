// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `separator`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftSeparatorRecipe].
class RaftSeparatorRecipeStyle {
  const RaftSeparatorRecipeStyle({required this.root, required this.labeledRoot, required this.labeledLine, required this.labeledContent});

  /// Slot `root`.
  final RaftSlotStyle root;
  /// Slot `labeledRoot`.
  final RaftSlotStyle labeledRoot;
  /// Slot `labeledLine`.
  final RaftSlotStyle labeledLine;
  /// Slot `labeledContent`.
  final RaftSlotStyle labeledContent;

  Map<String, RaftSlotStyle> get slots => {'root': root, 'labeledRoot': labeledRoot, 'labeledLine': labeledLine, 'labeledContent': labeledContent};
}

/// raft-ui recipe `separator` (`src/components/separator/separator.tsx`, index.mjs:16238).
///
/// Used by: ComboboxSeparator, ContextMenuSeparator, DropdownMenuSeparator, MessageTextSelectionToolbarSeparator, PopoverSeparator, PreviewCardSeparator, SelectSeparator, Separator.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftSeparatorRecipe {
  static const String recipeName = 'separator';
  static const List<String> slotNames = ['root', 'labeledRoot', 'labeledLine', 'labeledContent'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftSeparatorRecipeStyle resolve({required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name], states, tokens);
    return RaftSeparatorRecipeStyle(root: s[0], labeledRoot: s[1], labeledLine: s[2], labeledContent: s[3]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [2867, 1290, 1296, 1284, 1279, 1278, 1297, 1291, 1292],
    [1717, 1723, 2312, 1700, 2767],
    [3127, 2867, 1947, 913, 900],
    [2574, 1689, 3032, 1688, 2995],
    [2867, 1290, 1296, 829, 1286, 1299],
    [3127, 2867, 1979, 829],
    [2574, 1689, 3032, 1688, 2984],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3], [4, 1, 5, 6],
  ];
}
