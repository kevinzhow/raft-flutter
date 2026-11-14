// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `mobileNavServer`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftMobileNavServerRecipe].
class RaftMobileNavServerRecipeStyle {
  const RaftMobileNavServerRecipeStyle({
    required this.item,
    required this.content,
    required this.scroll,
    required this.list,
    required this.group,
    required this.row,
    required this.rowLabel,
    required this.rowBody,
    required this.rowDescription,
    required this.destinations,
    required this.destination,
  });

  /// Slot `item`.
  final RaftSlotStyle item;

  /// Slot `content`.
  final RaftSlotStyle content;

  /// Slot `scroll`.
  final RaftSlotStyle scroll;

  /// Slot `list`.
  final RaftSlotStyle list;

  /// Slot `group`.
  final RaftSlotStyle group;

  /// Slot `row`.
  final RaftSlotStyle row;

  /// Slot `rowLabel`.
  final RaftSlotStyle rowLabel;

  /// Slot `rowBody`.
  final RaftSlotStyle rowBody;

  /// Slot `rowDescription`.
  final RaftSlotStyle rowDescription;

  /// Slot `destinations`.
  final RaftSlotStyle destinations;

  /// Slot `destination`.
  final RaftSlotStyle destination;

  Map<String, RaftSlotStyle> get slots => {
    'item': item,
    'content': content,
    'scroll': scroll,
    'list': list,
    'group': group,
    'row': row,
    'rowLabel': rowLabel,
    'rowBody': rowBody,
    'rowDescription': rowDescription,
    'destinations': destinations,
    'destination': destination,
  };
}

/// raft-ui recipe `mobileNavServer` (`dist/components/mobile-nav/mobile-nav-server.mjs`, index.mjs:25890).
///
/// Used by: MobileNavServerItem, MobileNavServerPopoverContent, MobileNavServerPopoverDestination, MobileNavServerPopoverDestinations, MobileNavServerPopoverGroup, MobileNavServerPopoverList, MobileNavServerPopoverRow, MobileNavServerPopoverRowBody, MobileNavServerPopoverRowDescription, MobileNavServerPopoverRowLabel.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftMobileNavServerRecipe {
  static const String recipeName = 'mobileNavServer';
  static const List<String> slotNames = [
    'item',
    'content',
    'scroll',
    'list',
    'group',
    'row',
    'rowLabel',
    'rowBody',
    'rowDescription',
    'destinations',
    'destination',
  ];
  static const List<RaftRecipeAxis> axes = [];

  static RaftMobileNavServerRecipeStyle resolve({
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
    return RaftMobileNavServerRecipeStyle(
      item: s[0],
      content: s[1],
      scroll: s[2],
      list: s[3],
      group: s[4],
      row: s[5],
      rowLabel: s[6],
      rowBody: s[7],
      rowDescription: s[8],
      destinations: s[9],
      destination: s[10],
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
    [2483, 603, 90, 1274],
    [1400, 1404, 2718, 2116, 1922],
    [1400, 2098, 1404],
    [1400, 2109, 1401, 1404, 2261],
    [1400, 2499, 1404, 2261],
    [
      1400,
      2725,
      2499,
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
      695,
      1415,
      766,
      472,
      474,
      327,
      360,
      89,
      88,
    ],
    [2116, 1401, 2681],
    [1400, 2116, 1401, 1404],
    [2116, 2681, 1454, 2616, 1455, 2600],
    [1489, 2499, 1501, 797, 1464, 2261, 1038, 1037],
    [
      2433,
      1400,
      2116,
      993,
      2483,
      1404,
      1864,
      1869,
      2247,
      2675,
      1464,
      2461,
      2399,
      2417,
      1456,
      2597,
      1453,
      2598,
      1783,
      695,
      1415,
      472,
      480,
      474,
      492,
      321,
      322,
      136,
      140,
      138,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
  ];
}
