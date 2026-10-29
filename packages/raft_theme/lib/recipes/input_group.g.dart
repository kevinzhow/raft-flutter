// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `inputGroup`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `align` axis of `inputGroup` (default `inline-start`).
enum RaftInputGroupRecipeAlign {
  inlineStart('inline-start'),
  inlineEnd('inline-end');

  const RaftInputGroupRecipeAlign(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// `variant` axis of `inputGroup` (default `default`).
enum RaftInputGroupRecipeVariant {
  default_('default'),
  container('container');

  const RaftInputGroupRecipeVariant(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftInputGroupRecipe].
class RaftInputGroupRecipeStyle {
  const RaftInputGroupRecipeStyle({
    required this.root,
    required this.addon,
    required this.text,
    required this.control,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `addon`.
  final RaftSlotStyle addon;

  /// Slot `text`.
  final RaftSlotStyle text;

  /// Slot `control`.
  final RaftSlotStyle control;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'addon': addon,
    'text': text,
    'control': control,
  };
}

/// raft-ui recipe `inputGroup` (`src/components/input-group/input-group.tsx`, index.mjs:5152).
///
/// Used by: ComboboxInputGroup, InputGroup, InputGroupAddon, InputGroupInput.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftInputGroupRecipe {
  static const String recipeName = 'inputGroup';
  static const List<String> slotNames = ['root', 'addon', 'text', 'control'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis(
      'align',
      ['inline-start', 'inline-end'],
      'inline-start',
      false,
    ),
    RaftRecipeAxis('variant', ['default', 'container'], 'default', false),
  ];

  static RaftInputGroupRecipeStyle resolve({
    RaftInputGroupRecipeAlign? align,
    RaftInputGroupRecipeVariant? variant,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [align?.css, variant?.css],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftInputGroupRecipeStyle(
      root: s[0],
      addon: s[1],
      text: s[2],
      control: s[3],
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
      1147,
      1682,
      965,
      1929,
      1484,
      1319,
      1245,
      1174,
      1583,
      1710,
      622,
      635,
      596,
      1822,
      1738,
      1895,
      947,
      950,
      1002,
      1233,
      1232,
      1231,
      1230,
      1228,
      1229,
    ],
    [965, 1740, 1319, 1324, 1023, 1660, 1727, 1784, 160, 1566, 298, 1636],
    [965, 1740, 1319, 1660, 1727, 1933, 1014, 1838, 1785, 1566, 298, 1633],
    [
      1484,
      966,
      615,
      1620,
      1577,
      1631,
      1198,
      1666,
      1012,
      1820,
      1011,
      1822,
      1628,
      928,
      938,
      934,
    ],
    [
      965,
      1740,
      1319,
      1324,
      1023,
      1660,
      1727,
      1784,
      160,
      1566,
      1732,
      333,
      633,
      581,
      636,
    ],
    [
      965,
      1740,
      1319,
      1660,
      1727,
      1933,
      1014,
      1838,
      1785,
      1566,
      1732,
      334,
      633,
      581,
      636,
    ],
    [965, 1740, 1319, 1324, 1023, 1660, 1727, 1784, 160, 1567, 1618],
    [965, 1740, 1319, 1660, 1727, 1933, 1014, 1838, 1785, 1567, 1615],
    [
      965,
      1740,
      1319,
      1324,
      1023,
      1660,
      1727,
      1784,
      160,
      1567,
      1732,
      333,
      633,
      581,
      630,
    ],
    [
      965,
      1740,
      1319,
      1660,
      1727,
      1933,
      1014,
      1838,
      1785,
      1567,
      1732,
      334,
      633,
      581,
      630,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3],
    [0, 4, 5, 3],
    [0, 6, 7, 3],
    [0, 8, 9, 3],
  ];
}
