// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `choiceList`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftChoiceListRecipe].
class RaftChoiceListRecipeStyle {
  const RaftChoiceListRecipeStyle({
    required this.root,
    required this.searchInput,
    required this.frame,
    required this.scroller,
    required this.rows,
    required this.group,
    required this.section,
    required this.heading,
    required this.item,
    required this.media,
    required this.body,
    required this.label,
    required this.description,
    required this.meta,
    required this.action,
    required this.note,
    required this.footer,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `searchInput`.
  final RaftSlotStyle searchInput;

  /// Slot `frame`.
  final RaftSlotStyle frame;

  /// Slot `scroller`.
  final RaftSlotStyle scroller;

  /// Slot `rows`.
  final RaftSlotStyle rows;

  /// Slot `group`.
  final RaftSlotStyle group;

  /// Slot `section`.
  final RaftSlotStyle section;

  /// Slot `heading`.
  final RaftSlotStyle heading;

  /// Slot `item`.
  final RaftSlotStyle item;

  /// Slot `media`.
  final RaftSlotStyle media;

  /// Slot `body`.
  final RaftSlotStyle body;

  /// Slot `label`.
  final RaftSlotStyle label;

  /// Slot `description`.
  final RaftSlotStyle description;

  /// Slot `meta`.
  final RaftSlotStyle meta;

  /// Slot `action`.
  final RaftSlotStyle action;

  /// Slot `note`.
  final RaftSlotStyle note;

  /// Slot `footer`.
  final RaftSlotStyle footer;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'searchInput': searchInput,
    'frame': frame,
    'scroller': scroller,
    'rows': rows,
    'group': group,
    'section': section,
    'heading': heading,
    'item': item,
    'media': media,
    'body': body,
    'label': label,
    'description': description,
    'meta': meta,
    'action': action,
    'note': note,
    'footer': footer,
  };
}

/// raft-ui recipe `choiceList` (`dist/components/choice-list/choice-list.recipe.mjs`, index.mjs:28800).
///
/// Used by: ChoiceList.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftChoiceListRecipe {
  static const String recipeName = 'choiceList';
  static const List<String> slotNames = [
    'root',
    'searchInput',
    'frame',
    'scroller',
    'rows',
    'group',
    'section',
    'heading',
    'item',
    'media',
    'body',
    'label',
    'description',
    'meta',
    'action',
    'note',
    'footer',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('scroll', ['true', 'false'], null, true),
    RaftRecipeAxis('fill', ['true', 'false'], null, true),
    RaftRecipeAxis('hasAction', ['true', 'false'], null, true),
  ];

  static RaftChoiceListRecipeStyle resolve({
    bool? scroll,
    bool? fill,
    bool? hasAction,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [scroll?.toString(), fill?.toString(), hasAction?.toString()],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftChoiceListRecipeStyle(
      root: s[0],
      searchInput: s[1],
      frame: s[2],
      scroller: s[3],
      rows: s[4],
      group: s[5],
      section: s[6],
      heading: s[7],
      item: s[8],
      media: s[9],
      body: s[10],
      label: s[11],
      description: s[12],
      meta: s[13],
      action: s[14],
      note: s[15],
      footer: s[16],
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
    [1489, 2116, 1466],
    [254],
    [1400, 2116, 1404, 2252, 2462, 939, 953, 911],
    [2098, 2116, 2261],
    [1489, 1495, 1476, 1485],
    [983, 988, 1489, 1500, 1502, 1476, 1485],
    [983, 988, 1489, 1500, 1502],
    [983, 2402, 2381, 2274, 1456, 2588, 1449, 2600],
    [
      983,
      1400,
      2116,
      1866,
      1467,
      2461,
      2402,
      2113,
      2430,
      2335,
      2343,
      2613,
      1456,
      2622,
      2186,
      2184,
      1181,
    ],
    [1400, 1679, 2499, 1864],
    [1489, 2116, 1401, 1463],
    [2681, 1457, 2598, 1820],
    [937, 2681, 1456, 2597, 1455, 2603, 1820],
    [2433, 2747, 989, 1400, 1679, 1864, 2489, 2355, 2153, 2337, 1456, 2622],
    [2402, 2417, 1456, 2587, 2600],
    [2499, 960, 954, 2261],
    [
      983,
      1400,
      2116,
      1866,
      1467,
      2461,
      2402,
      2113,
      2430,
      2335,
      2343,
      2613,
      1456,
      2622,
      2186,
      2184,
      1181,
      2357,
    ],
    [2116, 1466, 1400, 2098, 1401, 1404],
    [1400, 2116, 1404, 2252, 2462, 939, 953, 911, 2098, 1401],
    [2098, 2116, 2261, 1401],
    [2433, 2747, 989, 1400, 1679, 1864, 2489, 2153, 2337, 1456, 2622, 2360],
    [
      983,
      1400,
      2116,
      1866,
      1467,
      2461,
      2402,
      2113,
      2430,
      2335,
      2343,
      2613,
      1456,
      2622,
      2186,
      2184,
      1181,
      2358,
    ],
    [2098, 2116, 2261, 1916],
    [2098, 2116, 2261, 1916, 1401],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 12, 13, 14, 15],
    [0, 1, 2, 3, 4, 5, 6, 7, 16, 9, 10, 11, 12, 12, 13, 14, 15],
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 12, 13, 14, 15],
    [17, 1, 18, 19, 4, 5, 6, 7, 8, 9, 10, 11, 12, 12, 20, 14, 15],
    [17, 1, 18, 19, 4, 5, 6, 7, 21, 9, 10, 11, 12, 12, 20, 14, 15],
    [17, 1, 18, 19, 4, 5, 6, 7, 8, 9, 10, 11, 12, 12, 20, 14, 15],
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 12, 13, 14, 15],
    [0, 1, 2, 3, 4, 5, 6, 7, 16, 9, 10, 11, 12, 12, 13, 14, 15],
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 12, 13, 14, 15],
    [0, 1, 2, 22, 4, 5, 6, 7, 8, 9, 10, 11, 12, 12, 20, 14, 15],
    [0, 1, 2, 22, 4, 5, 6, 7, 21, 9, 10, 11, 12, 12, 20, 14, 15],
    [0, 1, 2, 22, 4, 5, 6, 7, 8, 9, 10, 11, 12, 12, 20, 14, 15],
    [17, 1, 18, 23, 4, 5, 6, 7, 8, 9, 10, 11, 12, 12, 20, 14, 15],
    [17, 1, 18, 23, 4, 5, 6, 7, 21, 9, 10, 11, 12, 12, 20, 14, 15],
    [17, 1, 18, 23, 4, 5, 6, 7, 8, 9, 10, 11, 12, 12, 20, 14, 15],
    [0, 1, 2, 22, 4, 5, 6, 7, 8, 9, 10, 11, 12, 12, 20, 14, 15],
    [0, 1, 2, 22, 4, 5, 6, 7, 21, 9, 10, 11, 12, 12, 20, 14, 15],
    [0, 1, 2, 22, 4, 5, 6, 7, 8, 9, 10, 11, 12, 12, 20, 14, 15],
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 12, 13, 14, 15],
    [0, 1, 2, 3, 4, 5, 6, 7, 16, 9, 10, 11, 12, 12, 13, 14, 15],
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 12, 13, 14, 15],
    [17, 1, 18, 19, 4, 5, 6, 7, 8, 9, 10, 11, 12, 12, 20, 14, 15],
    [17, 1, 18, 19, 4, 5, 6, 7, 21, 9, 10, 11, 12, 12, 20, 14, 15],
    [17, 1, 18, 19, 4, 5, 6, 7, 8, 9, 10, 11, 12, 12, 20, 14, 15],
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 12, 13, 14, 15],
    [0, 1, 2, 3, 4, 5, 6, 7, 16, 9, 10, 11, 12, 12, 13, 14, 15],
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 12, 13, 14, 15],
  ];
}
