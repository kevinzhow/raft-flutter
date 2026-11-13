// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `contextMenu`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
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

/// raft-ui recipe `contextMenu` (`dist/components/context-menu/context-menu.mjs`, index.mjs:5593).
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
  static const List<RaftRecipeAxis> axes = [];

  static RaftContextMenuRecipeStyle resolve({
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [],
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
    [2483],
    [1862, 2746, 2247],
    [
      1400,
      1404,
      1911,
      2252,
      2247,
      2125,
      1462,
      2462,
      915,
      2261,
      2598,
      2496,
      2445,
      2449,
    ],
    [
      1400,
      2725,
      993,
      2483,
      1864,
      2613,
      2247,
      2675,
      2113,
      1467,
      2461,
      2402,
      2430,
      1456,
      2587,
      1453,
      2598,
      1783,
      1237,
      1160,
      1185,
      1187,
      472,
      474,
      327,
      360,
      1177,
    ],
    [
      1400,
      2725,
      993,
      2483,
      1864,
      2613,
      2247,
      2675,
      2113,
      1467,
      2461,
      2402,
      2430,
      1456,
      2587,
      1453,
      2598,
      1783,
      1237,
      1275,
      1185,
      1187,
      472,
      474,
      327,
      360,
      1177,
    ],
    [2116, 1401, 2681, 2613],
    [2403, 2417, 2637, 2603, 2556],
    [2402, 2381, 2274, 1456, 2588, 1449, 2600],
    [2132, 1673, 2116, 2468, 933, 2260, 2497, 1852, 1454, 2616, 1455, 2600],
    [177, 2158, 1680, 940, 918],
    [2346, 2132, 1400, 2499, 1864, 1869, 2517, 2598, 478],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 3, 4, 5, 6, 7, 8, 9, 10],
  ];
}
