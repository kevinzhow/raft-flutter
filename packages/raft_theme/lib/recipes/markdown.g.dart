// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `markdown`.
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

/// raft-ui recipe `markdown` (`src/components/markdown/markdown.recipe.ts`, index.mjs:6849).
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
    [1346, 1007, 1818],
    [1429, 1329],
    [1724, 1894, 914, 1895, 1700, 1822, 1280, 1573, 995],
    [418, 1008, 1712, 575, 1661, 650, 1840, 1309, 1312, 1691, 1695],
    [1429, 1619, 1355],
    [1428],
    [1518, 631, 634, 1615, 1823, 1547],
    [1521, 621, 639, 633],
    [1581, 1520, 1923, 1422, 1705, 620, 633, 596],
    [624, 621, 1809],
    [1328],
    [1656, 1665, 621, 623, 633, 1548, 581, 1832, 1016, 1928, 1818],
    [1656, 1665, 621, 623, 633, 1548],
    [1503, 469],
    [1288, 1422, 1520, 1705, 620, 633],
    [1302, 1344, 1932],
    [1429, 1619, 1354],
    [1007, 1818, 1510, 1429, 1791],
    [1007, 1818, 1509, 1429, 1790],
    [1007, 1818, 1509, 1429, 1789],
    [1007, 1818, 1507, 1428, 1797],
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
