// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `combobox`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `inputOwner` axis of `combobox`.
enum RaftComboboxRecipeInputOwner {
  group('group'),
  control('control');

  const RaftComboboxRecipeInputOwner(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftComboboxRecipe].
class RaftComboboxRecipeStyle {
  const RaftComboboxRecipeStyle({
    required this.trigger,
    required this.triggerCount,
    required this.triggerIndicator,
    required this.control,
    required this.inputGroup,
    required this.input,
    required this.positioner,
    required this.content,
    required this.header,
    required this.separator,
    required this.list,
    required this.item,
    required this.itemIndicator,
    required this.label,
    required this.clear,
    required this.empty,
    required this.groupLabel,
    required this.chips,
    required this.chip,
    required this.chipRemove,
  });

  /// Slot `trigger`.
  final RaftSlotStyle trigger;

  /// Slot `triggerCount`.
  final RaftSlotStyle triggerCount;

  /// Slot `triggerIndicator`.
  final RaftSlotStyle triggerIndicator;

  /// Slot `control`.
  final RaftSlotStyle control;

  /// Slot `inputGroup`.
  final RaftSlotStyle inputGroup;

  /// Slot `input`.
  final RaftSlotStyle input;

  /// Slot `positioner`.
  final RaftSlotStyle positioner;

  /// Slot `content`.
  final RaftSlotStyle content;

  /// Slot `header`.
  final RaftSlotStyle header;

  /// Slot `separator`.
  final RaftSlotStyle separator;

  /// Slot `list`.
  final RaftSlotStyle list;

  /// Slot `item`.
  final RaftSlotStyle item;

  /// Slot `itemIndicator`.
  final RaftSlotStyle itemIndicator;

  /// Slot `label`.
  final RaftSlotStyle label;

  /// Slot `clear`.
  final RaftSlotStyle clear;

  /// Slot `empty`.
  final RaftSlotStyle empty;

  /// Slot `groupLabel`.
  final RaftSlotStyle groupLabel;

  /// Slot `chips`.
  final RaftSlotStyle chips;

  /// Slot `chip`.
  final RaftSlotStyle chip;

  /// Slot `chipRemove`.
  final RaftSlotStyle chipRemove;

  Map<String, RaftSlotStyle> get slots => {
    'trigger': trigger,
    'triggerCount': triggerCount,
    'triggerIndicator': triggerIndicator,
    'control': control,
    'inputGroup': inputGroup,
    'input': input,
    'positioner': positioner,
    'content': content,
    'header': header,
    'separator': separator,
    'list': list,
    'item': item,
    'itemIndicator': itemIndicator,
    'label': label,
    'clear': clear,
    'empty': empty,
    'groupLabel': groupLabel,
    'chips': chips,
    'chip': chip,
    'chipRemove': chipRemove,
  };
}

/// raft-ui recipe `combobox` (`src/components/combobox/combobox.tsx`, index.mjs:5311).
///
/// Used by: ComboboxChip, ComboboxChipRemove, ComboboxChips, ComboboxClear, ComboboxContent, ComboboxControl, ComboboxEmpty, ComboboxGroupLabel, ComboboxHeader, ComboboxInput, ComboboxInputGroup, ComboboxItem, ComboboxItemIndicator, ComboboxLabel, ComboboxList, ComboboxPopup, ComboboxSeparator, ComboboxTrigger, ComboboxTriggerCount, ComboboxTriggerIndicator.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftComboboxRecipe {
  static const String recipeName = 'combobox';
  static const List<String> slotNames = [
    'trigger',
    'triggerCount',
    'triggerIndicator',
    'control',
    'inputGroup',
    'input',
    'positioner',
    'content',
    'header',
    'separator',
    'list',
    'item',
    'itemIndicator',
    'label',
    'clear',
    'empty',
    'groupLabel',
    'chips',
    'chip',
    'chipRemove',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('inputOwner', ['group', 'control'], null, true),
  ];

  static RaftComboboxRecipeStyle resolve({
    RaftComboboxRecipeInputOwner? inputOwner,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [inputOwner?.css],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftComboboxRecipeStyle(
      trigger: s[0],
      triggerCount: s[1],
      triggerIndicator: s[2],
      control: s[3],
      inputGroup: s[4],
      input: s[5],
      positioner: s[6],
      content: s[7],
      header: s[8],
      separator: s[9],
      list: s[10],
      item: s[11],
      itemIndicator: s[12],
      label: s[13],
      clear: s[14],
      empty: s[15],
      groupLabel: s[16],
      chips: s[17],
      chip: s[18],
      chipRemove: s[19],
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
    [
      1304,
      1723,
      1318,
      1322,
      1573,
      1889,
      3,
      2,
      154,
      153,
      152,
      1187,
      1021,
      1706,
      641,
      615,
      1655,
      1817,
      1016,
      1823,
      1308,
      1311,
      1274,
      857,
      861,
      860,
      858,
      995,
      930,
      488,
      150,
      151,
    ],
    [1304, 1736, 1318, 1323, 1195, 1481, 1650, 1013, 1835, 1007],
    [
      1495,
      965,
      1736,
      1318,
      1323,
      1879,
      941,
      177,
      1712,
      1820,
      1555,
      1274,
      1285,
      179,
      186,
      194,
    ],
    [
      965,
      1481,
      1318,
      1022,
      1573,
      173,
      177,
      211,
      210,
      4,
      214,
      212,
      1467,
      1706,
      622,
      635,
      596,
      1656,
      1662,
      1015,
      1806,
      1818,
      1891,
      947,
      950,
      1001,
      188,
      160,
      162,
      213,
    ],
    [
      965,
      1318,
      623,
      1172,
      1022,
      633,
      615,
      1656,
      1662,
      1809,
      1820,
      180,
      177,
      963,
      998,
      999,
    ],
    [1924, 1573],
    [1316, 1939, 1573],
    [1195, 1357, 1492, 1579, 1573, 1705, 602, 1818, 1733, 1690, 1694],
    [965, 1318, 1322, 1656, 1022, 1665, 1631, 1618],
    [1198, 1736, 621, 604],
    [1361, 1583, 1585, 965, 967, 1590, 1720],
    [
      965,
      1924,
      1736,
      660,
      1723,
      1318,
      1322,
      1579,
      1832,
      1573,
      1889,
      1477,
      1023,
      1706,
      1655,
      1662,
      1015,
      1809,
      1012,
      1818,
      615,
      1269,
      862,
      903,
      834,
      836,
      275,
      277,
      265,
      271,
    ],
    [1626, 1495, 965, 1736, 1318, 1323, 1818, 180, 177, 186, 194],
    [1356, 1015, 1810, 1007, 1820],
    [
      1304,
      1318,
      1323,
      1626,
      1554,
      1573,
      1879,
      941,
      913,
      912,
      1185,
      1481,
      1706,
      1654,
      1015,
      1817,
      1016,
      1823,
      1271,
      1284,
      427,
      995,
      180,
      186,
      194,
    ],
    [1658, 1670, 1832, 1809, 1820],
    [1667, 1655, 1641, 1600, 1810, 1007, 1820],
    [
      965,
      971,
      1318,
      1467,
      1021,
      1706,
      622,
      635,
      596,
      1665,
      1634,
      1613,
      1891,
      947,
      950,
      1001,
    ],
    [1304, 1318, 1185, 1021, 1704, 581, 1629, 1614, 1817, 1016, 1818],
    [1304, 1318, 1323, 1573, 1889, 1759, 1712, 1820, 1271, 427, 995, 179],
    [1924, 1573, 1481, 966, 621, 615, 1588, 1015, 1809, 1818, 1624],
    [
      1924,
      1481,
      966,
      1710,
      621,
      615,
      1588,
      1734,
      1573,
      1689,
      1002,
      1004,
      991,
      993,
      1015,
      1806,
      1014,
      1818,
      1624,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19],
    [0, 1, 2, 3, 4, 20, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19],
    [0, 1, 2, 3, 4, 21, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19],
  ];
}
