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
    [965, 1483, 967, 1581, 1820, 1707, 620, 633, 596, 1736],
    [
      1138,
      1040,
      1483,
      507,
      1041,
      1321,
      1035,
      1038,
      1204,
      1206,
      1205,
      1202,
      1203,
      1595,
      1200,
    ],
    [1719, 1483, 655, 1016, 1813, 1010, 1820],
    [657, 1717, 1719, 965, 1738, 1319, 1729, 180, 177, 1466],
    [1720, 1483, 655, 1016, 1811, 1838, 1825],
    [1719, 656, 965, 1738, 1319, 1728, 1326],
    [1483, 1595],
    [
      965,
      1483,
      1023,
      969,
      1319,
      1016,
      1812,
      1822,
      179,
      177,
      124,
      639,
      633,
      1660,
      1671,
    ],
    [965, 1483, 967, 1581, 1820, 1708, 622, 632, 596, 1736],
    [
      1138,
      1040,
      1483,
      507,
      1041,
      1321,
      1038,
      1204,
      1206,
      1205,
      1202,
      1203,
      1034,
      1594,
    ],
    [1719, 1483, 655, 1820, 1016, 1811, 1017],
    [1720, 1483, 655, 1838, 1016, 1819, 1825],
    [1483, 1658, 1605],
    [965, 1483, 1023, 969, 1319, 1016, 1812, 1822, 179, 177, 124],
    [
      1138,
      1040,
      1483,
      507,
      1041,
      1321,
      1035,
      1038,
      1204,
      1206,
      1205,
      1202,
      1203,
      1660,
      1671,
    ],
    [1483, 639, 633, 1595, 958],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7],
    [8, 9, 10, 3, 11, 5, 12, 13],
    [0, 14, 2, 3, 4, 5, 15, 7],
  ];
}
