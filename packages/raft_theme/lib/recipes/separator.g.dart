// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
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

/// raft-ui recipe `separator` (`src/components/separator/separator.tsx`, index.mjs:16492).
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
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftSeparatorRecipeStyle resolve({
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
    [2902, 1312, 1318, 1306, 1301, 1300, 1319, 1313, 1314],
    [1742, 1748, 2331, 1725, 2796],
    [3168, 2902, 1949, 927, 916],
    [2597, 1714, 3073, 1713, 3032],
    [2902, 1312, 1318, 834, 1308, 1321],
    [3168, 2902, 1981, 834],
    [2597, 1714, 3073, 1713, 3021],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3],
    [4, 1, 5, 6],
  ];
}
