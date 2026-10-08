// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `popover`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftPopoverRecipe].
class RaftPopoverRecipeStyle {
  const RaftPopoverRecipeStyle({required this.trigger, required this.positioner, required this.content, required this.header, required this.separator, required this.title, required this.description, required this.close, required this.arrow, required this.backdrop, required this.viewport});

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

  Map<String, RaftSlotStyle> get slots => {'trigger': trigger, 'positioner': positioner, 'content': content, 'header': header, 'separator': separator, 'title': title, 'description': description, 'close': close, 'arrow': arrow, 'backdrop': backdrop, 'viewport': viewport};
}

/// raft-ui recipe `popover` (`src/components/popover/popover.tsx`, index.mjs:5873).
///
/// Used by: PopoverArrow, PopoverBackdrop, PopoverClose, PopoverContent, PopoverDescription, PopoverHeader, PopoverPopup, PopoverSeparator, PopoverTitle, PopoverTrigger, PopoverViewport.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftPopoverRecipe {
  static const String recipeName = 'popover';
  static const List<String> slotNames = ['trigger', 'positioner', 'content', 'header', 'separator', 'title', 'description', 'close', 'arrow', 'backdrop', 'viewport'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftPopoverRecipeStyle resolve({required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name], states, tokens);
    return RaftPopoverRecipeStyle(trigger: s[0], positioner: s[1], content: s[2], header: s[3], separator: s[4], title: s[5], description: s[6], close: s[7], arrow: s[8], backdrop: s[9], viewport: s[10]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [2834],
    [2309, 3142, 2649],
    [2361, 2583, 2656, 2649, 866, 900, 828, 2861],
    [1620, 2312, 2316, 2753, 2765],
    [911, 900],
    [2359, 2918, 1684, 2344, 1691, 3096, 3055, 2993],
    [2359, 3032, 2335, 1691, 2987],
    [2301, 2312, 2317, 2918, 1684, 2649, 3084, 1691, 3096, 3055, 2993, 2280],
    [2876, 2805, 892, 913, 900, 828],
    [1619, 2303, 850],
    [862],
    [2361, 2583, 2656, 2649, 2818, 828, 2864],
    [911, 895],
    [2359, 2920, 1688, 3046, 2991],
    [2359, 3032, 2335, 2981],
    [2301, 2312, 2317, 2649, 2920, 1688, 3046, 2981, 3084, 1602, 2276],
    [2876, 2805, 891, 911, 895, 828],
    [1619, 2303, 819, 679],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10], [0, 1, 11, 3, 12, 13, 14, 15, 16, 17, 10],
  ];
}
