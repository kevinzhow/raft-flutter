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
      1305,
      1725,
      1319,
      1323,
      1575,
      1891,
      3,
      2,
      154,
      153,
      152,
      1188,
      1022,
      1708,
      641,
      615,
      1657,
      1819,
      1017,
      1825,
      1309,
      1312,
      1275,
      857,
      861,
      860,
      858,
      996,
      930,
      488,
      150,
      151,
    ],
    [1305, 1738, 1319, 1324, 1196, 1483, 1652, 1014, 1837, 1008],
    [
      1497,
      965,
      1738,
      1319,
      1324,
      1881,
      941,
      177,
      1714,
      1822,
      1557,
      1275,
      1286,
      179,
      186,
      194,
    ],
    [
      965,
      1483,
      1319,
      1023,
      1575,
      173,
      177,
      211,
      210,
      4,
      214,
      212,
      1469,
      1708,
      622,
      635,
      596,
      1658,
      1664,
      1016,
      1808,
      1820,
      1893,
      947,
      950,
      1002,
      188,
      160,
      162,
      213,
    ],
    [
      965,
      1319,
      623,
      1173,
      1023,
      633,
      615,
      1658,
      1664,
      1811,
      1822,
      180,
      177,
      963,
      999,
      1000,
    ],
    [1926, 1575],
    [1317, 1941, 1575],
    [1196, 1358, 1494, 1581, 1575, 1707, 602, 1820, 1735, 1692, 1696],
    [965, 1319, 1323, 1658, 1023, 1667, 1633, 1620],
    [1199, 1738, 621, 604],
    [1363, 1585, 1587, 965, 967, 1592, 1722],
    [
      965,
      1926,
      1738,
      660,
      1725,
      1319,
      1323,
      1581,
      1834,
      1575,
      1891,
      1479,
      1024,
      1708,
      1657,
      1664,
      1016,
      1811,
      1013,
      1820,
      615,
      1270,
      862,
      903,
      834,
      836,
      275,
      277,
      265,
      271,
    ],
    [1628, 1497, 965, 1738, 1319, 1324, 1820, 180, 177, 186, 194],
    [1357, 1016, 1812, 1008, 1822],
    [
      1305,
      1319,
      1324,
      1628,
      1556,
      1575,
      1881,
      941,
      913,
      912,
      1186,
      1483,
      1708,
      1656,
      1016,
      1819,
      1017,
      1825,
      1272,
      1285,
      427,
      996,
      180,
      186,
      194,
    ],
    [1660, 1672, 1834, 1811, 1822],
    [1669, 1657, 1643, 1602, 1812, 1008, 1822],
    [
      965,
      971,
      1319,
      1469,
      1022,
      1708,
      622,
      635,
      596,
      1667,
      1636,
      1615,
      1893,
      947,
      950,
      1002,
    ],
    [1305, 1319, 1186, 1022, 1706, 581, 1631, 1616, 1819, 1017, 1820],
    [1305, 1319, 1324, 1575, 1891, 1761, 1714, 1822, 1272, 427, 996, 179],
    [1926, 1575, 1483, 966, 621, 615, 1590, 1016, 1811, 1820, 1626],
    [
      1926,
      1483,
      966,
      1712,
      621,
      615,
      1590,
      1736,
      1575,
      1691,
      1003,
      1005,
      991,
      993,
      1016,
      1808,
      1015,
      1820,
      1626,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19],
    [0, 1, 2, 3, 4, 20, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19],
    [0, 1, 2, 3, 4, 21, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19],
  ];
}
