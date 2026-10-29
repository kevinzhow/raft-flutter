// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `contextMenu`.
// ignore_for_file: type=lint

import '../recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftContextMenuRecipe].
class RaftContextMenuRecipeStyle {
  const RaftContextMenuRecipeStyle({
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
    required this.separator,
    required this.indicator,
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

  /// Slot `separator`.
  final RaftSlotStyle separator;

  /// Slot `indicator`.
  final RaftSlotStyle indicator;

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
    'separator': separator,
    'indicator': indicator,
  };
}

/// raft-ui recipe `contextMenu` (`src/components/context-menu/context-menu.tsx`, index.mjs:4720).
///
/// Used by: ContextMenuCheckboxItem, ContextMenuContent, ContextMenuFooter, ContextMenuItem, ContextMenuItemLabel, ContextMenuLabel, ContextMenuPopup, ContextMenuRadioItem, ContextMenuSeparator, ContextMenuShortcut, ContextMenuSubmenuTrigger, ContextMenuTrigger.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftContextMenuRecipe {
  static const String recipeName = 'contextMenu';
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
    'separator',
    'indicator',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftContextMenuRecipeStyle resolve({
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
    return RaftContextMenuRecipeStyle(
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
      separator: s[10],
      indicator: s[11],
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
    [2868],
    [2328, 3183, 2672],
    [1644, 1646, 2380, 2602, 2679, 2672, 878, 892, 833, 2896],
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
      1717,
      2354,
      3024,
      2227,
      1504,
      1469,
      1475,
      423,
      425,
      439,
      456,
      414,
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
      1969,
      2679,
      1716,
      3053,
      1717,
      2356,
      3024,
      889,
      905,
      2343,
      2227,
      1504,
      1469,
      1475,
      423,
      425,
      439,
      456,
      414,
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
      1717,
      2354,
      3024,
      2227,
      1504,
      1545,
      1469,
      1475,
      423,
      425,
      439,
      456,
      414,
    ],
    [2597, 1645, 3133, 3040],
    [2781, 2794, 3073, 3018, 2946],
    [889, 916, 2781, 2794, 1716, 2956, 1709, 3137, 2363, 3096, 3030],
    [2608, 1716, 3053, 1717, 2356],
    [927, 892],
    [2739, 2608, 1644, 2913, 2902, 2331, 2336],
    [1644, 1646, 2380, 2602, 2679, 1720, 2848, 833, 2692, 2895, 2672],
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
    [2630, 138, 1981, 877, 834, 1010],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
    [0, 1, 12, 13, 14, 15, 6, 7, 16, 17, 18, 11],
  ];
}
