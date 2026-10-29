// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
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

/// raft-ui recipe `dropdownMenu` (`src/components/dropdown-menu/dropdown-menu.tsx`, index.mjs:3989).
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
  static const List<RaftRecipeAxis> axes = [];

  static RaftDropdownMenuRecipeStyle resolve({
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
    [1725],
    [1317, 1941, 1575],
    [
      1358,
      1581,
      1575,
      965,
      1491,
      967,
      1019,
      1707,
      602,
      1592,
      1820,
      1735,
      1692,
      1696,
    ],
    [
      965,
      1926,
      660,
      1725,
      1319,
      390,
      1834,
      1575,
      1891,
      1479,
      1024,
      1708,
      1657,
      1667,
      1016,
      1811,
      1013,
      1820,
      1270,
      862,
      814,
      749,
      690,
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
      1926,
      660,
      1725,
      1319,
      1834,
      1575,
      1891,
      1479,
      1024,
      1708,
      1657,
      1667,
      1016,
      1811,
      1013,
      1820,
      1270,
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
      1926,
      660,
      1725,
      1319,
      390,
      1834,
      1575,
      1891,
      1479,
      1024,
      1708,
      1657,
      1667,
      1016,
      1811,
      1013,
      1820,
      1270,
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
    [1483, 966, 1895, 1834],
    [1658, 1669, 1858, 1825, 1781],
    [1657, 1643, 1602, 1016, 1812, 1008, 1822],
    [1497, 1196, 1483, 1712, 615, 1590, 1736, 1691, 1014, 1837, 1015, 1822],
    [1497, 1305, 1490, 1324, 1019, 1654, 1781],
    [98, 1521, 1199, 621, 604],
    [1628, 1497, 965, 1738, 1319, 1324, 1751, 1820, 280],
    [1483, 966, 1895],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13],
  ];
}
