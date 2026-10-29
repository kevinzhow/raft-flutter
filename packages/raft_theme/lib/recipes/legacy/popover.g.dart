// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `popover`.
// ignore_for_file: type=lint

import '../recipe_runtime.dart';
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

/// raft-ui recipe `popover` (`src/components/popover/popover.tsx`, index.mjs:5885).
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
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftPopoverRecipeStyle resolve({
    required RaftRecipeTheme theme,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [theme.name],
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
    [2868],
    [2328, 3183, 2672],
    [2380, 2606, 2679, 2672, 878, 916, 833, 2895],
    [1644, 2331, 2335, 2781, 2794],
    [925, 916],
    [2378, 2956, 1709, 2363, 1716, 3137, 3096, 3030],
    [2378, 3073, 2354, 1716, 3024],
    [2320, 2331, 2336, 2956, 1709, 2672, 3125, 1716, 3137, 3096, 3030, 2299],
    [2911, 2835, 908, 927, 916, 833],
    [1643, 2322, 863],
    [874],
    [2380, 2606, 2679, 2672, 2848, 833, 2898],
    [925, 911],
    [2378, 2958, 1713, 3087, 3028],
    [2378, 3073, 2354, 3018],
    [2320, 2331, 2336, 2672, 2958, 1713, 3087, 3018, 3125, 1626, 2295],
    [2911, 2835, 907, 925, 911, 833],
    [1643, 2322, 824, 685],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
    [0, 1, 11, 3, 12, 13, 14, 15, 16, 17, 10],
  ];
}
