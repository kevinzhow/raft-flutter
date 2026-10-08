// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
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
  const RaftMarkdownRecipeStyle({required this.heading, required this.paragraph, required this.link, required this.mark, required this.list, required this.listItem, required this.blockquote, required this.rule, required this.tableScroll, required this.table, required this.tableRow, required this.headerCell, required this.cell, required this.checkbox, required this.image, required this.inlineCode});

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

  Map<String, RaftSlotStyle> get slots => {'heading': heading, 'paragraph': paragraph, 'link': link, 'mark': mark, 'list': list, 'listItem': listItem, 'blockquote': blockquote, 'rule': rule, 'tableScroll': tableScroll, 'table': table, 'tableRow': tableRow, 'headerCell': headerCell, 'cell': cell, 'checkbox': checkbox, 'image': image, 'inlineCode': inlineCode};
}

/// raft-ui recipe `markdown` (`src/components/markdown/markdown.recipe.ts`, index.mjs:8719).
///
/// Used by: MarkdownBlockquote, MarkdownCell, MarkdownCheckbox, MarkdownHeaderCell, MarkdownHeading, MarkdownImage, MarkdownInlineCode, MarkdownLink, MarkdownList, MarkdownListItem, MarkdownMark, MarkdownOrderedList, MarkdownParagraph, MarkdownRule, MarkdownTable, MarkdownTableRow, MarkdownTableScroll.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftMarkdownRecipe {
  static const String recipeName = 'markdown';
  static const List<String> slotNames = ['heading', 'paragraph', 'link', 'mark', 'list', 'listItem', 'blockquote', 'rule', 'tableScroll', 'table', 'tableRow', 'headerCell', 'cell', 'checkbox', 'image', 'inlineCode'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('level', ['1', '2', '3', '4', '5', '6'], null, true),
    RaftRecipeAxis('ordered', ['false', 'true'], 'false', false),
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftMarkdownRecipeStyle resolve({RaftMarkdownRecipeLevel? level, bool? ordered, required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [level?.css, ordered?.toString(), theme.name], states, tokens);
    return RaftMarkdownRecipeStyle(heading: s[0], paragraph: s[1], link: s[2], mark: s[3], list: s[4], listItem: s[5], blockquote: s[6], rule: s[7], tableScroll: s[8], table: s[9], tableRow: s[10], headerCell: s[11], cell: s[12], checkbox: s[13], image: s[14], inlineCode: s[15]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [2347, 1684],
    [2491, 2326],
    [2835, 3093, 1577, 3094, 2945, 2275],
    [841, 3000, 577],
    [2491, 2702, 2358],
    [2490],
    [2608, 892, 881, 2701, 2310, 2964],
    [2609, 913, 876],
    [2658, 2609],
    [882, 866, 876, 3017],
    [],
    [866, 876, 2753, 2763, 772, 3003, 1684, 3131],
    [864, 876, 2753, 2763],
    [2595, 637],
    [2289, 2484, 2609, 866, 876],
    [2347, 1688, 2976],
    [2491, 2326, 2476],
    [2835, 3093, 3094, 2945, 1576, 1578, 2282, 2263],
    [2491, 2702, 2358, 2476],
    [2608, 2476, 2821, 2755, 2765, 892, 896, 799, 2981, 2619],
    [2609, 911, 896],
    [2658, 2609, 3126, 2484, 2818, 864, 890, 825],
    [882, 865, 3017],
    [2323],
    [2753, 2763, 865, 873, 890, 2621, 2620, 798, 3003, 1688, 3131, 2976],
    [2753, 2763, 865, 873, 890, 2621],
    [2289, 2484, 2609, 2818, 864, 896],
    [2299, 2343, 3135],
    [2491, 2702, 2357],
    [2491, 2702, 2357, 2476],
    [1684, 2602, 2491, 2917],
    [2602, 2491, 2917, 1688, 2976],
    [1684, 2600, 2491, 2916],
    [2600, 2491, 2916, 1688, 2976],
    [1684, 2600, 2491, 2915],
    [2600, 2491, 2915, 1688, 2976],
    [1684, 2598, 2490, 2926],
    [2598, 2490, 2926, 1688, 2976],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 10], [15, 16, 17, 3, 18, 5, 19, 20, 21, 22, 23, 24, 25, 13, 26, 27], [0, 1, 2, 3, 28, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 10], [15, 16, 17, 3, 29, 5, 19, 20, 21, 22, 23, 24, 25, 13, 26, 27], [30, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 10], [31, 16, 17, 3, 18, 5, 19, 20, 21, 22, 23, 24, 25, 13, 26, 27], [30, 1, 2, 3, 28, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 10], [31, 16, 17, 3, 29, 5, 19, 20, 21, 22, 23, 24, 25, 13, 26, 27], [32, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 10], [33, 16, 17, 3, 18, 5, 19, 20, 21, 22, 23, 24, 25, 13, 26, 27], [32, 1, 2, 3, 28, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 10], [33, 16, 17, 3, 29, 5, 19, 20, 21, 22, 23, 24, 25, 13, 26, 27], [34, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 10], [35, 16, 17, 3, 18, 5, 19, 20, 21, 22, 23, 24, 25, 13, 26, 27], [34, 1, 2, 3, 28, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 10], [35, 16, 17, 3, 29, 5, 19, 20, 21, 22, 23, 24, 25, 13, 26, 27],
    [36, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 10], [37, 16, 17, 3, 18, 5, 19, 20, 21, 22, 23, 24, 25, 13, 26, 27], [36, 1, 2, 3, 28, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 10], [37, 16, 17, 3, 29, 5, 19, 20, 21, 22, 23, 24, 25, 13, 26, 27], [36, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 10], [37, 16, 17, 3, 18, 5, 19, 20, 21, 22, 23, 24, 25, 13, 26, 27], [36, 1, 2, 3, 28, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 10], [37, 16, 17, 3, 29, 5, 19, 20, 21, 22, 23, 24, 25, 13, 26, 27], [36, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 10], [37, 16, 17, 3, 18, 5, 19, 20, 21, 22, 23, 24, 25, 13, 26, 27], [36, 1, 2, 3, 28, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 10], [37, 16, 17, 3, 29, 5, 19, 20, 21, 22, 23, 24, 25, 13, 26, 27],
  ];
}
