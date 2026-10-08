// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `select`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `chrome` axis of `select` (default `default`).
enum RaftSelectRecipeChrome {
  default_('default'),
  field('field');

  const RaftSelectRecipeChrome(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftSelectRecipe].
class RaftSelectRecipeStyle {
  const RaftSelectRecipeStyle({required this.trigger, required this.icon, required this.value, required this.positioner, required this.content, required this.list, required this.item, required this.itemLeading, required this.itemIndicator, required this.itemText, required this.label, required this.group, required this.groupLabel, required this.separator, required this.scrollArrow, required this.empty});

  /// Slot `trigger`.
  final RaftSlotStyle trigger;
  /// Slot `icon`.
  final RaftSlotStyle icon;
  /// Slot `value`.
  final RaftSlotStyle value;
  /// Slot `positioner`.
  final RaftSlotStyle positioner;
  /// Slot `content`.
  final RaftSlotStyle content;
  /// Slot `list`.
  final RaftSlotStyle list;
  /// Slot `item`.
  final RaftSlotStyle item;
  /// Slot `itemLeading`.
  final RaftSlotStyle itemLeading;
  /// Slot `itemIndicator`.
  final RaftSlotStyle itemIndicator;
  /// Slot `itemText`.
  final RaftSlotStyle itemText;
  /// Slot `label`.
  final RaftSlotStyle label;
  /// Slot `group`.
  final RaftSlotStyle group;
  /// Slot `groupLabel`.
  final RaftSlotStyle groupLabel;
  /// Slot `separator`.
  final RaftSlotStyle separator;
  /// Slot `scrollArrow`.
  final RaftSlotStyle scrollArrow;
  /// Slot `empty`.
  final RaftSlotStyle empty;

  Map<String, RaftSlotStyle> get slots => {'trigger': trigger, 'icon': icon, 'value': value, 'positioner': positioner, 'content': content, 'list': list, 'item': item, 'itemLeading': itemLeading, 'itemIndicator': itemIndicator, 'itemText': itemText, 'label': label, 'group': group, 'groupLabel': groupLabel, 'separator': separator, 'scrollArrow': scrollArrow, 'empty': empty};
}

/// raft-ui recipe `select` (`src/components/select/select.tsx`, index.mjs:7201).
///
/// Used by: SelectContent, SelectGroup, SelectGroupLabel, SelectIcon, SelectItem, SelectItemIndicator, SelectItemLeading, SelectItemText, SelectLabel, SelectList, SelectPopup, SelectScrollDownArrow, SelectScrollUpArrow, SelectSeparator, SelectTrigger, SelectValue, useComposerSuggestions.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftSelectRecipe {
  static const String recipeName = 'select';
  static const List<String> slotNames = ['trigger', 'icon', 'value', 'positioner', 'content', 'list', 'item', 'itemLeading', 'itemIndicator', 'itemText', 'label', 'group', 'groupLabel', 'separator', 'scrollArrow', 'empty'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
    RaftRecipeAxis('chrome', ['default', 'field'], 'default', false),
  ];

  static RaftSelectRecipeStyle resolve({required RaftRecipeTheme theme, RaftSelectRecipeChrome? chrome, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name, chrome?.css], states, tokens);
    return RaftSelectRecipeStyle(trigger: s[0], icon: s[1], value: s[2], positioner: s[3], content: s[4], list: s[5], item: s[6], itemLeading: s[7], itemIndicator: s[8], itemText: s[9], label: s[10], group: s[11], groupLabel: s[12], separator: s[13], scrollArrow: s[14], empty: s[15]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [2301, 2834, 2312, 2316, 1698, 2649, 3084, 1500, 1508, 1503, 1504, 1506, 7, 6, 285, 284, 369, 367, 368, 3127, 1519, 1534, 609, 581, 603, 371, 332],
    [2585, 1620, 2867, 2312, 2317, 2631, 3087, 304, 302, 310, 324],
    [1620, 2574, 1621, 3092, 3003],
    [2309, 3142, 2649],
    [2775, 2361, 2656, 2649, 3098, 2573, 866, 900, 828, 2862],
    [2365, 2661, 2664, 2832],
    [1620, 3127, 2867, 939, 2834, 2312, 2316, 1698, 2656, 2753, 3003, 2649, 3084, 873, 889, 828, 2763, 3032, 1684, 2337, 2987, 2324, 9, 2228, 1483, 1562, 1563, 1330, 1447, 1453, 298, 302, 287, 289],
    [1620, 2867, 2312, 2317, 425, 427, 2882, 2987, 298, 302, 288, 289],
    [2716, 2585, 1620, 2867, 2312, 2317, 2987, 303, 302, 311, 325],
    [2574, 1621, 3092],
    [2359, 1691, 2918, 1692, 3096, 2344, 3055, 2987],
    [1620, 1622],
    [2753, 2765, 1691, 2918, 1692, 3096, 2344, 3055, 2993],
    [1979, 2867, 865, 830],
    [580, 2304, 3138, 1620, 1963, 3127, 939, 2312, 2317, 2649, 3084, 1193, 1191, 425, 427, 900, 828, 2987, 1192, 1190],
    [2753, 2769, 2970, 1691, 3017, 1692, 2992],
    [2301, 2834, 2312, 2316, 1698, 2649, 3084, 1500, 1508, 1503, 1504, 1506, 7, 6, 285, 284, 369, 367, 368, 3127, 1519, 1534, 609, 581, 603, 371, 332, 1976, 2753, 2765, 2975, 1686, 4, 11],
    [1620, 3127, 2867, 939, 2834, 2312, 2316, 1698, 2656, 2753, 3003, 2649, 3084, 873, 889, 828, 2763, 2987, 2324, 2228, 1483, 1562, 1563, 1330, 1447, 1453, 298, 302, 287, 289, 2975, 1686, 10],
    [2301, 2834, 2312, 2316, 1698, 2649, 3084, 1500, 1508, 1503, 1504, 1506, 7, 6, 285, 284, 369, 367, 368, 3017, 1688, 3046, 2981, 2221, 598, 1652, 1665, 5, 12],
    [2775, 2361, 2584, 2656, 2649, 2818, 828, 2861],
    [2365, 2661, 2664, 2832, 1620, 1622, 1695, 2749, 2762],
    [1620, 3127, 2867, 939, 2834, 2312, 2316, 1698, 2656, 3003, 2649, 2822, 850, 2751, 2763, 2924, 1690, 2335, 3046, 2981, 3069, 1602, 2222, 2276, 1482, 1484, 1561, 1564, 1447, 1452, 298, 302, 288, 290],
    [1620, 2867, 2312, 2317, 425, 427, 2880, 2981, 298, 302, 288, 290],
    [2716, 2585, 1620, 2867, 2312, 2317, 2976, 303, 302, 310, 324],
    [2359, 1688, 2920, 2344, 3046, 2976],
    [1620, 1622, 1695],
    [2765, 2751, 2920, 1688, 2344, 3046, 2991],
    [1979, 2867, 865, 2174, 829],
    [580, 2304, 3138, 1620, 1963, 3127, 939, 2312, 2317, 2649, 3084, 1193, 1191, 425, 427, 828, 2984, 2279],
    [2753, 2769, 2970, 3017, 2981],
    [2301, 2834, 2312, 2316, 1698, 2649, 3084, 1500, 1508, 1503, 1504, 1506, 7, 6, 285, 284, 369, 367, 368, 3046, 2981, 2221, 598, 1652, 1665, 1976, 2753, 2765, 2975, 1686, 4, 11],
    [1620, 3127, 2867, 939, 2834, 2312, 2316, 1698, 2656, 3003, 2649, 2822, 850, 2751, 2763, 3046, 2981, 3069, 1602, 2222, 2276, 1482, 1484, 1561, 1564, 1447, 1452, 298, 302, 288, 290, 2975, 1686, 10],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15], [16, 1, 2, 3, 4, 5, 17, 7, 8, 9, 10, 11, 12, 13, 14, 15], [18, 1, 2, 3, 19, 20, 21, 22, 23, 9, 24, 25, 26, 27, 28, 29], [30, 1, 2, 3, 19, 20, 31, 22, 23, 9, 24, 25, 26, 27, 28, 29],
  ];
}
