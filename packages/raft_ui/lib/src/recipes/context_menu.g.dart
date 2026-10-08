// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `contextMenu`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftContextMenuRecipe].
class RaftContextMenuRecipeStyle {
  const RaftContextMenuRecipeStyle({required this.trigger, required this.positioner, required this.content, required this.item, required this.radioItem, required this.submenuTrigger, required this.itemLabel, required this.footer, required this.label, required this.shortcut, required this.separator, required this.indicator});

  /// Slot `trigger`.
  final RaftSlotStyle trigger;
  /// Slot `positioner`.
  final RaftSlotStyle positioner;
  /// Slot `content`.
  final RaftSlotStyle content;
  /// Slot `item`.
  final RaftSlotStyle item;
  /// Slot `radioItem`.
  final RaftSlotStyle radioItem;
  /// Slot `submenuTrigger`.
  final RaftSlotStyle submenuTrigger;
  /// Slot `itemLabel`.
  final RaftSlotStyle itemLabel;
  /// Slot `footer`.
  final RaftSlotStyle footer;
  /// Slot `label`.
  final RaftSlotStyle label;
  /// Slot `shortcut`.
  final RaftSlotStyle shortcut;
  /// Slot `separator`.
  final RaftSlotStyle separator;
  /// Slot `indicator`.
  final RaftSlotStyle indicator;

  Map<String, RaftSlotStyle> get slots => {'trigger': trigger, 'positioner': positioner, 'content': content, 'item': item, 'radioItem': radioItem, 'submenuTrigger': submenuTrigger, 'itemLabel': itemLabel, 'footer': footer, 'label': label, 'shortcut': shortcut, 'separator': separator, 'indicator': indicator};
}

/// raft-ui recipe `contextMenu` (`src/components/context-menu/context-menu.tsx`, index.mjs:4708).
///
/// Used by: ContextMenuCheckboxItem, ContextMenuContent, ContextMenuFooter, ContextMenuItem, ContextMenuItemLabel, ContextMenuLabel, ContextMenuPopup, ContextMenuRadioItem, ContextMenuSeparator, ContextMenuShortcut, ContextMenuSubmenuTrigger, ContextMenuTrigger.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftContextMenuRecipe {
  static const String recipeName = 'contextMenu';
  static const List<String> slotNames = ['trigger', 'positioner', 'content', 'item', 'radioItem', 'submenuTrigger', 'itemLabel', 'footer', 'label', 'shortcut', 'separator', 'indicator'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftContextMenuRecipeStyle resolve({required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name], states, tokens);
    return RaftContextMenuRecipeStyle(trigger: s[0], positioner: s[1], content: s[2], item: s[3], radioItem: s[4], submenuTrigger: s[5], itemLabel: s[6], footer: s[7], label: s[8], shortcut: s[9], separator: s[10], indicator: s[11]);
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
    [1620, 1622, 2361, 2579, 2656, 2649, 866, 876, 828, 2862],
    [1620, 3127, 939, 2834, 2312, 1698, 2753, 567, 3003, 2649, 3084, 2765, 1691, 3017, 1692, 2335, 2987, 2208, 1480, 1447, 1453, 425, 427, 441, 458, 416],
    [1620, 3127, 939, 2834, 2312, 1698, 2753, 3003, 2649, 3084, 1967, 2656, 1691, 3017, 1692, 2337, 2987, 873, 889, 2324, 2208, 1480, 1447, 1453, 425, 427, 441, 458, 416],
    [1620, 3127, 939, 2834, 2312, 1698, 2753, 567, 3003, 2649, 3084, 2765, 1691, 3017, 1692, 2335, 2987, 2208, 1480, 1521, 1447, 1453, 425, 427, 441, 458, 416],
    [2574, 1621, 3092, 3003],
    [2753, 2765, 3032, 2981, 2911],
    [873, 900, 2753, 2765, 1691, 2918, 1684, 3096, 2344, 3055, 2993],
    [2585, 1691, 3017, 1692, 2337],
    [913, 876],
    [2716, 2585, 1620, 2878, 2867, 2312, 2317],
    [1620, 1622, 2361, 2579, 2656, 1695, 2818, 828, 2669, 2861, 2649],
    [1620, 3127, 939, 2834, 2312, 567, 3003, 2649, 1699, 2822, 2753, 2763, 2924, 1690, 3046, 2981, 3069, 1602, 2222, 2276, 1482, 1484, 1447, 1452, 425, 427, 444, 459, 305, 318, 2177, 1479],
    [1620, 3127, 939, 2834, 2312, 3003, 2649, 1699, 2822, 2753, 2763, 2924, 1690, 3046, 2981, 3069, 1602, 2222, 2276, 1482, 1484, 1447, 1452, 425, 427, 444, 459, 305, 318, 2177, 1479],
    [1620, 3127, 939, 2834, 2312, 567, 3003, 2649, 1699, 2822, 2753, 2763, 2924, 1690, 3046, 2981, 3069, 1602, 2222, 2276, 1482, 1484, 1524, 1538, 1447, 1452, 425, 427, 444, 459, 305, 326, 318, 2177, 1479, 1520],
    [138, 2491, 873, 895, 2753, 2765, 1007, 2920, 1688, 2344, 3046, 2991],
    [2585, 2981],
    [2608, 138, 1979, 865, 829, 990],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], [0, 1, 12, 13, 14, 15, 6, 7, 16, 17, 18, 11],
  ];
}
