// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `dropdownMenu`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftDropdownMenuRecipe].
class RaftDropdownMenuRecipeStyle {
  const RaftDropdownMenuRecipeStyle({
    required this.trigger,
    required this.positioner,
    required this.content,
    required this.item,
    required this.radioItem,
    required this.submenuTrigger,
    required this.itemLabel,
    required this.footer,
    required this.label,
    required this.shortcut,
    required this.itemCount,
    required this.separator,
    required this.indicator,
    required this.radioLabel,
  });

  /// Slot `trigger`.
  final RaftSlotStyle trigger;

  /// Slot `positioner`.
  final RaftSlotStyle positioner;

  /// Slot `content`.
  final RaftSlotStyle content;

  /// Slot `item`.
  final RaftSlotStyle item;

  /// Slot `radioItem`.
  final RaftSlotStyle radioItem;

  /// Slot `submenuTrigger`.
  final RaftSlotStyle submenuTrigger;

  /// Slot `itemLabel`.
  final RaftSlotStyle itemLabel;

  /// Slot `footer`.
  final RaftSlotStyle footer;

  /// Slot `label`.
  final RaftSlotStyle label;

  /// Slot `shortcut`.
  final RaftSlotStyle shortcut;

  /// Slot `itemCount`.
  final RaftSlotStyle itemCount;

  /// Slot `separator`.
  final RaftSlotStyle separator;

  /// Slot `indicator`.
  final RaftSlotStyle indicator;

  /// Slot `radioLabel`.
  final RaftSlotStyle radioLabel;

  Map<String, RaftSlotStyle> get slots => {
    'trigger': trigger,
    'positioner': positioner,
    'content': content,
    'item': item,
    'radioItem': radioItem,
    'submenuTrigger': submenuTrigger,
    'itemLabel': itemLabel,
    'footer': footer,
    'label': label,
    'shortcut': shortcut,
    'itemCount': itemCount,
    'separator': separator,
    'indicator': indicator,
    'radioLabel': radioLabel,
  };
}

/// raft-ui recipe `dropdownMenu` (`src/components/dropdown-menu/dropdown-menu.tsx`, index.mjs:5025).
///
/// Used by: DropdownMenuCheckboxItem, DropdownMenuContent, DropdownMenuFooter, DropdownMenuItem, DropdownMenuItemCount, DropdownMenuItemLabel, DropdownMenuLabel, DropdownMenuPopup, DropdownMenuRadioItem, DropdownMenuSeparator, DropdownMenuShortcut, DropdownMenuSubmenuTrigger, DropdownMenuTrigger.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftDropdownMenuRecipe {
  static const String recipeName = 'dropdownMenu';
  static const List<String> slotNames = [
    'trigger',
    'positioner',
    'content',
    'item',
    'radioItem',
    'submenuTrigger',
    'itemLabel',
    'footer',
    'label',
    'shortcut',
    'itemCount',
    'separator',
    'indicator',
    'radioLabel',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftDropdownMenuRecipeStyle resolve({
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
    return RaftDropdownMenuRecipeStyle(
      trigger: s[0],
      positioner: s[1],
      content: s[2],
      item: s[3],
      radioItem: s[4],
      submenuTrigger: s[5],
      itemLabel: s[6],
      footer: s[7],
      label: s[8],
      shortcut: s[9],
      itemCount: s[10],
      separator: s[11],
      indicator: s[12],
      radioLabel: s[13],
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
    [2868, 1543, 1558, 615, 587, 609],
    [2328, 3183, 2672],
    [2380, 2602, 2679, 2672, 878, 892, 833, 2896],
    [
      1644,
      3168,
      959,
      2868,
      2331,
      1723,
      2781,
      568,
      3040,
      2672,
      3125,
      2794,
      1716,
      3053,
      1713,
      3024,
      2247,
      1507,
      1469,
      1475,
      1351,
      1243,
      1257,
      1256,
      1255,
      1254,
      294,
      298,
      305,
      319,
      284,
    ],
    [
      1644,
      3168,
      959,
      2868,
      2331,
      1723,
      2781,
      3040,
      2672,
      3125,
      2679,
      2794,
      1716,
      3053,
      1713,
      2354,
      3024,
      889,
      905,
      2343,
      2247,
      1507,
      1469,
      1475,
      294,
      298,
      305,
      319,
      284,
    ],
    [
      1644,
      3168,
      959,
      2868,
      2331,
      1723,
      2781,
      568,
      3040,
      2672,
      3125,
      2794,
      1716,
      3053,
      1713,
      3024,
      2247,
      1507,
      1550,
      1469,
      1475,
      294,
      298,
      305,
      319,
      284,
    ],
    [2597, 1645, 3133, 3040],
    [2781, 2794, 3073, 3018, 2946],
    [889, 916, 2781, 2794, 1716, 2956, 1709, 3137, 2363, 3096, 3030],
    [2608, 1716, 3053, 1713],
    [
      2608,
      2320,
      2603,
      2336,
      1719,
      2946,
      2852,
      876,
      916,
      786,
      2777,
      2790,
      1716,
      2956,
      2363,
      1709,
      3067,
    ],
    [927, 892],
    [2739, 2608, 1644, 2913, 2902, 2331, 2336],
    [2597, 1645, 3133],
    [2868, 604],
    [2380, 2602, 2679, 1719, 2848, 833, 2692, 2895, 2672, 1644, 1646],
    [
      1644,
      3168,
      959,
      2868,
      2331,
      568,
      3040,
      2672,
      1724,
      2852,
      2781,
      2792,
      2962,
      1715,
      3087,
      3018,
      3110,
      1626,
      2241,
      2295,
      1506,
      1508,
      1469,
      1474,
      423,
      425,
      442,
      457,
      301,
      314,
      2192,
      1503,
    ],
    [
      1644,
      3168,
      959,
      2868,
      2331,
      3040,
      2672,
      1724,
      2852,
      2781,
      2792,
      2962,
      1715,
      3087,
      3018,
      3110,
      1626,
      2241,
      2295,
      1506,
      1508,
      1469,
      1474,
      423,
      425,
      442,
      457,
      301,
      314,
      2192,
      1503,
    ],
    [
      1644,
      3168,
      959,
      2868,
      2331,
      568,
      3040,
      2672,
      1724,
      2852,
      2781,
      2792,
      2962,
      1715,
      3087,
      3018,
      3110,
      1626,
      2241,
      2295,
      1506,
      1508,
      1548,
      1562,
      1469,
      1474,
      423,
      425,
      442,
      457,
      301,
      322,
      314,
      2192,
      1503,
      1544,
    ],
    [138, 2512, 889, 911, 2781, 2794, 1027, 2958, 1713, 2363, 3087, 3028],
    [2608, 3018],
    [2608, 2320, 2603, 2336, 1719, 2777, 2946],
    [2630, 138, 1981, 877, 834, 1010],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13],
    [14, 1, 15, 16, 17, 18, 6, 7, 19, 20, 21, 22, 12, 13],
  ];
}
