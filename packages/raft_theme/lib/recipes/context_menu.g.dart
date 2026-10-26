// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `contextMenu`.
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

/// raft-ui recipe `contextMenu` (`src/components/context-menu/context-menu.tsx`, index.mjs:3730).
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
    [1723],
    [1316, 1939, 1573],
    [
      965,
      967,
      1357,
      1579,
      1573,
      1489,
      1018,
      1705,
      602,
      1590,
      1818,
      1733,
      1690,
      1694,
    ],
    [
      965,
      1924,
      660,
      1723,
      1318,
      390,
      1832,
      1573,
      1889,
      1477,
      1023,
      1706,
      1655,
      1665,
      1015,
      1809,
      1012,
      1818,
      1269,
      862,
      814,
      834,
      836,
      275,
      277,
      159,
      189,
      827,
    ],
    [
      965,
      1924,
      660,
      1723,
      1318,
      1832,
      1573,
      1889,
      1477,
      1023,
      1706,
      1655,
      1665,
      1015,
      1809,
      1012,
      1818,
      1269,
      862,
      814,
      834,
      836,
      275,
      277,
      159,
      189,
      827,
    ],
    [
      965,
      1924,
      660,
      1723,
      1318,
      390,
      1832,
      1573,
      1889,
      1477,
      1023,
      1706,
      1655,
      1665,
      1015,
      1809,
      1012,
      1818,
      1269,
      862,
      885,
      834,
      836,
      275,
      277,
      159,
      189,
      827,
    ],
    [1481, 966, 1893, 1832],
    [1656, 1667, 1856, 1823, 1779],
    [1655, 1641, 1600, 1015, 1810, 1007, 1820],
    [1495, 1195, 1481, 1710, 615, 1588, 1734, 1689, 1013, 1835, 1014, 1820],
    [98, 1519, 1198, 621, 604],
    [1626, 1495, 965, 1736, 1318, 1323, 1749, 1818, 280],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
  ];
}
