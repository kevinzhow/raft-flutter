// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `markdown`.
// ignore_for_file: type=lint

import '../recipe_runtime.dart';
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

/// raft-ui recipe `markdown` (`src/components/markdown/markdown.recipe.ts`, index.mjs:8740).
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
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftMarkdownRecipeStyle resolve({
    RaftMarkdownRecipeLevel? level,
    bool? ordered,
    required RaftRecipeTheme theme,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [level?.css, ordered?.toString(), theme.name],
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
    [2366, 1709],
    [2512, 2345],
    [2869, 3134, 1601, 3135, 2983, 2294],
    [845, 3037, 582],
    [2512, 2725, 2377],
    [2511],
    [2630, 908, 897, 2724, 2329, 3001],
    [2631, 927, 892],
    [2681, 2631],
    [898, 878, 892, 3053],
    [],
    [878, 892, 2781, 2792, 778, 3040, 1709, 3172],
    [876, 892, 2781, 2792],
    [2618, 643],
    [2308, 2505, 2631, 878, 892],
    [2366, 1713, 3013],
    [2512, 2345, 2497],
    [2869, 3134, 3135, 2983, 1600, 1602, 2301, 2282],
    [2512, 2725, 2377, 2497],
    [2630, 2497, 2851, 2783, 2794, 908, 912, 805, 3018, 2641],
    [2631, 925, 912],
    [2681, 2631, 3167, 2505, 2848, 876, 906, 830],
    [898, 877, 3053],
    [2342],
    [2781, 2792, 877, 889, 906, 2643, 2642, 804, 3040, 1713, 3172, 3013],
    [2781, 2792, 877, 889, 906, 2643],
    [2308, 2505, 2631, 2848, 876, 912],
    [2318, 2362, 3176],
    [2512, 2725, 2376],
    [2512, 2725, 2376, 2497],
    [1709, 2625, 2512, 2955],
    [2625, 2512, 2955, 1713, 3013],
    [1709, 2623, 2512, 2954],
    [2623, 2512, 2954, 1713, 3013],
    [1709, 2623, 2512, 2953],
    [2623, 2512, 2953, 1713, 3013],
    [1709, 2621, 2511, 2964],
    [2621, 2511, 2964, 1713, 3013],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 10],
    [15, 16, 17, 3, 18, 5, 19, 20, 21, 22, 23, 24, 25, 13, 26, 27],
    [0, 1, 2, 3, 28, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 10],
    [15, 16, 17, 3, 29, 5, 19, 20, 21, 22, 23, 24, 25, 13, 26, 27],
    [30, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 10],
    [31, 16, 17, 3, 18, 5, 19, 20, 21, 22, 23, 24, 25, 13, 26, 27],
    [30, 1, 2, 3, 28, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 10],
    [31, 16, 17, 3, 29, 5, 19, 20, 21, 22, 23, 24, 25, 13, 26, 27],
    [32, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 10],
    [33, 16, 17, 3, 18, 5, 19, 20, 21, 22, 23, 24, 25, 13, 26, 27],
    [32, 1, 2, 3, 28, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 10],
    [33, 16, 17, 3, 29, 5, 19, 20, 21, 22, 23, 24, 25, 13, 26, 27],
    [34, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 10],
    [35, 16, 17, 3, 18, 5, 19, 20, 21, 22, 23, 24, 25, 13, 26, 27],
    [34, 1, 2, 3, 28, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 10],
    [35, 16, 17, 3, 29, 5, 19, 20, 21, 22, 23, 24, 25, 13, 26, 27],
    [36, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 10],
    [37, 16, 17, 3, 18, 5, 19, 20, 21, 22, 23, 24, 25, 13, 26, 27],
    [36, 1, 2, 3, 28, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 10],
    [37, 16, 17, 3, 29, 5, 19, 20, 21, 22, 23, 24, 25, 13, 26, 27],
    [36, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 10],
    [37, 16, 17, 3, 18, 5, 19, 20, 21, 22, 23, 24, 25, 13, 26, 27],
    [36, 1, 2, 3, 28, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 10],
    [37, 16, 17, 3, 29, 5, 19, 20, 21, 22, 23, 24, 25, 13, 26, 27],
    [36, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 10],
    [37, 16, 17, 3, 18, 5, 19, 20, 21, 22, 23, 24, 25, 13, 26, 27],
    [36, 1, 2, 3, 28, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 10],
    [37, 16, 17, 3, 29, 5, 19, 20, 21, 22, 23, 24, 25, 13, 26, 27],
  ];
}
