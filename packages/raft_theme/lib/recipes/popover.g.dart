// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `popover`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `size` axis of `popover`.
enum RaftPopoverRecipeSize {
  default_('default'),
  item('item');

  const RaftPopoverRecipeSize(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftPopoverRecipe].
class RaftPopoverRecipeStyle {
  const RaftPopoverRecipeStyle({
    required this.trigger,
    required this.positioner,
    required this.content,
    required this.header,
    required this.body,
    required this.actions,
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

  /// Slot `body`.
  final RaftSlotStyle body;

  /// Slot `actions`.
  final RaftSlotStyle actions;

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
    'body': body,
    'actions': actions,
    'separator': separator,
    'title': title,
    'description': description,
    'close': close,
    'arrow': arrow,
    'backdrop': backdrop,
    'viewport': viewport,
  };
}

/// raft-ui recipe `popover` (`dist/components/popover/popover.mjs`, index.mjs:7057).
///
/// Used by: PopoverActions, PopoverArrow, PopoverBackdrop, PopoverBody, PopoverClose, PopoverContent, PopoverDescription, PopoverHeader, PopoverPopup, PopoverSeparator, PopoverTitle, PopoverTrigger, PopoverViewport.
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
    'body',
    'actions',
    'separator',
    'title',
    'description',
    'close',
    'arrow',
    'backdrop',
    'viewport',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('size', ['default', 'item'], null, true),
  ];

  static RaftPopoverRecipeStyle resolve({
    RaftPopoverRecipeSize? size,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [size?.css],
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
      body: s[4],
      actions: s[5],
      separator: s[6],
      title: s[7],
      description: s[8],
      close: s[9],
      arrow: s[10],
      backdrop: s[11],
      viewport: s[12],
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
    [1911, 2128, 2252, 2247, 2462, 915, 2598, 2496, 2445, 2449],
    [1400, 1864, 1868, 2403, 2100, 1466, 2415, 2356, 2302],
    [1400, 2116, 1404, 1465, 2405, 2384, 2276, 1877],
    [1400, 1408, 1864, 1870, 1466, 2405, 2276, 1877],
    [960, 953],
    [1907, 1456, 2609, 1449, 2598],
    [1907, 1456, 2597, 2603],
    [
      1847,
      1864,
      1869,
      2247,
      2675,
      1661,
      2126,
      2461,
      2400,
      1456,
      2597,
      1449,
      2598,
      1785,
      697,
      1439,
      479,
    ],
    [2513, 2451, 950, 960, 954, 915],
    [1399, 1849, 933],
    [937],
    [1911, 2128, 2252, 2247, 2462, 915, 2598, 2496, 2445, 2449, 2716, 1952],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
    [0, 1, 13, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
  ];
}
