// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `markdown`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `level` axis of `markdown`.
enum RaftMarkdownRecipeLevel {
  v1('1'),
  v2('2'),
  v3('3'),
  v4('4'),
  v5('5'),
  v6('6');

  const RaftMarkdownRecipeLevel(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftMarkdownRecipe].
class RaftMarkdownRecipeStyle {
  const RaftMarkdownRecipeStyle({
    required this.heading,
    required this.paragraph,
    required this.link,
    required this.mark,
    required this.list,
    required this.listItem,
    required this.blockquote,
    required this.rule,
    required this.tableScroll,
    required this.table,
    required this.tableRow,
    required this.headerCell,
    required this.cell,
    required this.checkbox,
    required this.image,
    required this.inlineCode,
  });

  /// Slot `heading`.
  final RaftSlotStyle heading;

  /// Slot `paragraph`.
  final RaftSlotStyle paragraph;

  /// Slot `link`.
  final RaftSlotStyle link;

  /// Slot `mark`.
  final RaftSlotStyle mark;

  /// Slot `list`.
  final RaftSlotStyle list;

  /// Slot `listItem`.
  final RaftSlotStyle listItem;

  /// Slot `blockquote`.
  final RaftSlotStyle blockquote;

  /// Slot `rule`.
  final RaftSlotStyle rule;

  /// Slot `tableScroll`.
  final RaftSlotStyle tableScroll;

  /// Slot `table`.
  final RaftSlotStyle table;

  /// Slot `tableRow`.
  final RaftSlotStyle tableRow;

  /// Slot `headerCell`.
  final RaftSlotStyle headerCell;

  /// Slot `cell`.
  final RaftSlotStyle cell;

  /// Slot `checkbox`.
  final RaftSlotStyle checkbox;

  /// Slot `image`.
  final RaftSlotStyle image;

  /// Slot `inlineCode`.
  final RaftSlotStyle inlineCode;

  Map<String, RaftSlotStyle> get slots => {
    'heading': heading,
    'paragraph': paragraph,
    'link': link,
    'mark': mark,
    'list': list,
    'listItem': listItem,
    'blockquote': blockquote,
    'rule': rule,
    'tableScroll': tableScroll,
    'table': table,
    'tableRow': tableRow,
    'headerCell': headerCell,
    'cell': cell,
    'checkbox': checkbox,
    'image': image,
    'inlineCode': inlineCode,
  };
}

/// raft-ui recipe `markdown` (`dist/components/markdown/markdown.recipe.mjs`, index.mjs:11548).
///
/// Used by: MarkdownBlockquote, MarkdownCell, MarkdownCheckbox, MarkdownHeaderCell, MarkdownHeading, MarkdownImage, MarkdownInlineCode, MarkdownLink, MarkdownList, MarkdownListItem, MarkdownMark, MarkdownOrderedList, MarkdownParagraph, MarkdownRule, MarkdownTable, MarkdownTableRow, MarkdownTableScroll.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftMarkdownRecipe {
  static const String recipeName = 'markdown';
  static const List<String> slotNames = [
    'heading',
    'paragraph',
    'link',
    'mark',
    'list',
    'listItem',
    'blockquote',
    'rule',
    'tableScroll',
    'table',
    'tableRow',
    'headerCell',
    'cell',
    'checkbox',
    'image',
    'inlineCode',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('level', ['1', '2', '3', '4', '5', '6'], null, true),
    RaftRecipeAxis('ordered', ['false', 'true'], 'false', false),
  ];

  static RaftMarkdownRecipeStyle resolve({
    RaftMarkdownRecipeLevel? level,
    bool? ordered,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [level?.css, ordered?.toString()],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftMarkdownRecipeStyle(
      heading: s[0],
      paragraph: s[1],
      link: s[2],
      mark: s[3],
      list: s[4],
      listItem: s[5],
      blockquote: s[6],
      rule: s[7],
      tableScroll: s[8],
      table: s[9],
      tableRow: s[10],
      headerCell: s[11],
      cell: s[12],
      checkbox: s[13],
      image: s[14],
      inlineCode: s[15],
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
    [1893, 1449, 2598],
    [1988, 1876],
    [2485, 2682, 1337, 2683, 2457, 2602, 1797, 1340, 1793, 2247, 1439],
    [680, 2471, 936, 2408, 2431, 976, 2621],
    [1988, 2303, 1906],
    [1987],
    [2158, 951, 954, 2299, 2603, 2204],
    [2160, 940, 960, 953],
    [2159, 2724, 1980, 2462, 939, 953, 911],
    [943, 940, 2587],
    [1875],
    [2403, 2415, 940, 942, 953, 2205, 895, 2613, 1457, 2729, 2598],
    [2403, 2415, 940, 942, 953, 2205],
    [2140, 761],
    [1801, 1980, 2159, 2462, 939, 953],
    [1845, 1890, 2733],
    [1988, 2303, 1905],
    [1449, 2598, 2148, 1988, 2571],
    [1449, 2598, 2147, 1988, 2570],
    [1449, 2598, 2147, 1988, 2569],
    [1449, 2598, 2145, 1987, 2576],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
    [0, 1, 2, 3, 16, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
    [17, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
    [17, 1, 2, 3, 16, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
    [18, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
    [18, 1, 2, 3, 16, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
    [19, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
    [19, 1, 2, 3, 16, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
    [20, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
    [20, 1, 2, 3, 16, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
    [20, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
    [20, 1, 2, 3, 16, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
    [20, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
    [20, 1, 2, 3, 16, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
  ];
}
