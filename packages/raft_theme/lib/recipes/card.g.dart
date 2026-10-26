// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `card`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `variant` axis of `card` (default `default`).
enum RaftCardRecipeVariant {
  default_('default'),
  option('option'),
  inset('inset');

  const RaftCardRecipeVariant(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftCardRecipe].
class RaftCardRecipeStyle {
  const RaftCardRecipeStyle({
    required this.root,
    required this.header,
    required this.title,
    required this.leading,
    required this.description,
    required this.trailing,
    required this.content,
    required this.footer,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `header`.
  final RaftSlotStyle header;

  /// Slot `title`.
  final RaftSlotStyle title;

  /// Slot `leading`.
  final RaftSlotStyle leading;

  /// Slot `description`.
  final RaftSlotStyle description;

  /// Slot `trailing`.
  final RaftSlotStyle trailing;

  /// Slot `content`.
  final RaftSlotStyle content;

  /// Slot `footer`.
  final RaftSlotStyle footer;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'header': header,
    'title': title,
    'leading': leading,
    'description': description,
    'trailing': trailing,
    'content': content,
    'footer': footer,
  };
}

/// raft-ui recipe `card` (`src/components/card/card.recipe.ts`, index.mjs:1617).
///
/// Used by: Card, CardContent, CardDescription, CardFooter, CardHeader, CardLeading, CardTitle, CardTrailing, MessageAttachmentCard.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftCardRecipe {
  static const String recipeName = 'card';
  static const List<String> slotNames = [
    'root',
    'header',
    'title',
    'leading',
    'description',
    'trailing',
    'content',
    'footer',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('variant', ['default', 'option', 'inset'], 'default', false),
  ];

  static RaftCardRecipeStyle resolve({
    RaftCardRecipeVariant? variant,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [variant?.css],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftCardRecipeStyle(
      root: s[0],
      header: s[1],
      title: s[2],
      leading: s[3],
      description: s[4],
      trailing: s[5],
      content: s[6],
      footer: s[7],
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
    [965, 1481, 967, 1579, 1818, 1705, 620, 633, 596, 1734],
    [
      1137,
      1039,
      1481,
      507,
      1040,
      1320,
      1034,
      1037,
      1203,
      1205,
      1204,
      1201,
      1202,
      1593,
      1199,
    ],
    [1717, 1481, 655, 1015, 1811, 1009, 1818],
    [657, 1715, 1717, 965, 1736, 1318, 1727, 180, 177, 1464],
    [1718, 1481, 655, 1015, 1809, 1836, 1823],
    [1717, 656, 965, 1736, 1318, 1726, 1325],
    [1481, 1593],
    [
      965,
      1481,
      1022,
      969,
      1318,
      1015,
      1810,
      1820,
      179,
      177,
      124,
      639,
      633,
      1658,
      1669,
    ],
    [965, 1481, 967, 1579, 1818, 1706, 622, 632, 596, 1734],
    [
      1137,
      1039,
      1481,
      507,
      1040,
      1320,
      1037,
      1203,
      1205,
      1204,
      1201,
      1202,
      1033,
      1592,
    ],
    [1717, 1481, 655, 1818, 1015, 1809, 1016],
    [1718, 1481, 655, 1836, 1015, 1817, 1823],
    [1481, 1656, 1603],
    [965, 1481, 1022, 969, 1318, 1015, 1810, 1820, 179, 177, 124],
    [
      1137,
      1039,
      1481,
      507,
      1040,
      1320,
      1034,
      1037,
      1203,
      1205,
      1204,
      1201,
      1202,
      1658,
      1669,
    ],
    [1481, 639, 633, 1593, 958],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7],
    [8, 9, 10, 3, 11, 5, 12, 13],
    [0, 14, 2, 3, 4, 5, 15, 7],
  ];
}
