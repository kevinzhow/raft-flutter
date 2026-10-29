// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `popover`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftPopoverRecipe].
class RaftPopoverRecipeStyle {
  const RaftPopoverRecipeStyle({
    required this.trigger,
    required this.positioner,
    required this.content,
    required this.header,
    required this.separator,
    required this.title,
    required this.description,
    required this.close,
    required this.arrow,
    required this.backdrop,
    required this.viewport,
  });

  /// Slot `trigger`.
  final RaftSlotStyle trigger;

  /// Slot `positioner`.
  final RaftSlotStyle positioner;

  /// Slot `content`.
  final RaftSlotStyle content;

  /// Slot `header`.
  final RaftSlotStyle header;

  /// Slot `separator`.
  final RaftSlotStyle separator;

  /// Slot `title`.
  final RaftSlotStyle title;

  /// Slot `description`.
  final RaftSlotStyle description;

  /// Slot `close`.
  final RaftSlotStyle close;

  /// Slot `arrow`.
  final RaftSlotStyle arrow;

  /// Slot `backdrop`.
  final RaftSlotStyle backdrop;

  /// Slot `viewport`.
  final RaftSlotStyle viewport;

  Map<String, RaftSlotStyle> get slots => {
    'trigger': trigger,
    'positioner': positioner,
    'content': content,
    'header': header,
    'separator': separator,
    'title': title,
    'description': description,
    'close': close,
    'arrow': arrow,
    'backdrop': backdrop,
    'viewport': viewport,
  };
}

/// raft-ui recipe `popover` (`src/components/popover/popover.tsx`, index.mjs:4707).
///
/// Used by: PopoverArrow, PopoverBackdrop, PopoverClose, PopoverContent, PopoverDescription, PopoverHeader, PopoverPopup, PopoverSeparator, PopoverTitle, PopoverTrigger, PopoverViewport.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftPopoverRecipe {
  static const String recipeName = 'popover';
  static const List<String> slotNames = [
    'trigger',
    'positioner',
    'content',
    'header',
    'separator',
    'title',
    'description',
    'close',
    'arrow',
    'backdrop',
    'viewport',
  ];
  static const List<RaftRecipeAxis> axes = [];

  static RaftPopoverRecipeStyle resolve({
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
    return RaftPopoverRecipeStyle(
      trigger: s[0],
      positioner: s[1],
      content: s[2],
      header: s[3],
      separator: s[4],
      title: s[5],
      description: s[6],
      close: s[7],
      arrow: s[8],
      backdrop: s[9],
      viewport: s[10],
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
    [1727],
    [1317, 1944, 1577],
    [1358, 1496, 1583, 1577, 1709, 602, 1822, 1737, 1694, 1698],
    [965, 1319, 1323, 1660, 1470, 1023, 1669, 1636, 1622],
    [639, 633],
    [1357, 1016, 1833, 1008, 1822],
    [1357, 1016, 1821, 1827],
    [
      1305,
      1319,
      1324,
      1577,
      1893,
      1188,
      1494,
      1710,
      1657,
      1016,
      1821,
      1008,
      1822,
      1272,
      427,
      996,
      281,
    ],
    [1750, 1700, 630, 639, 634, 602],
    [964, 1307, 615],
    [618],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
  ];
}
