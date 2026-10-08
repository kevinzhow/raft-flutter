// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `table`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftTableRecipe].
class RaftTableRecipeStyle {
  const RaftTableRecipeStyle({required this.root, required this.header, required this.body, required this.row, required this.head, required this.cell, required this.colgroup, required this.column, required this.caption});

  /// Slot `root`.
  final RaftSlotStyle root;
  /// Slot `header`.
  final RaftSlotStyle header;
  /// Slot `body`.
  final RaftSlotStyle body;
  /// Slot `row`.
  final RaftSlotStyle row;
  /// Slot `head`.
  final RaftSlotStyle head;
  /// Slot `cell`.
  final RaftSlotStyle cell;
  /// Slot `colgroup`.
  final RaftSlotStyle colgroup;
  /// Slot `column`.
  final RaftSlotStyle column;
  /// Slot `caption`.
  final RaftSlotStyle caption;

  Map<String, RaftSlotStyle> get slots => {'root': root, 'header': header, 'body': body, 'row': row, 'head': head, 'cell': cell, 'colgroup': colgroup, 'column': column, 'caption': caption};
}

/// raft-ui recipe `table` (`src/components/table/table.recipe.ts`, index.mjs:12520).
///
/// Used by: MarkdownTable, Table, TableBody, TableCaption, TableCell, TableColgroup, TableColumn, TableHead, TableHeader, TableRow.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftTableRecipe {
  static const String recipeName = 'table';
  static const List<String> slotNames = ['root', 'header', 'body', 'row', 'head', 'cell', 'colgroup', 'column', 'caption'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftTableRecipeStyle resolve({required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name], states, tokens);
    return RaftTableRecipeStyle(root: s[0], header: s[1], body: s[2], row: s[3], head: s[4], cell: s[5], colgroup: s[6], column: s[7], caption: s[8]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [3127, 882, 933, 3017, 866, 876],
    [],
    [327, 328],
    [3003, 3131, 875, 876, 772, 2753, 2765, 1684, 2956],
    [638, 3135, 875, 876, 2753, 2765],
    [2981],
    [3127, 882, 933, 3017],
    [3003, 3131, 873, 896, 797, 2753, 2765, 1688, 2976],
    [638, 3135, 873, 895, 2753, 2765],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 1, 3, 4, 1, 1, 5], [6, 1, 2, 1, 7, 8, 1, 1, 5],
  ];
}
