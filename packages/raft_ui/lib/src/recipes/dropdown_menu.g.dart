// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `dropdownMenu`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftDropdownMenuRecipe].
class RaftDropdownMenuRecipeStyle {
  const RaftDropdownMenuRecipeStyle({required this.trigger, required this.positioner, required this.content, required this.item, required this.radioItem, required this.submenuTrigger, required this.itemLabel, required this.footer, required this.label, required this.shortcut, required this.itemCount, required this.separator, required this.indicator, required this.radioLabel});

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
  /// Slot `itemCount`.
  final RaftSlotStyle itemCount;
  /// Slot `separator`.
  final RaftSlotStyle separator;
  /// Slot `indicator`.
  final RaftSlotStyle indicator;
  /// Slot `radioLabel`.
  final RaftSlotStyle radioLabel;

  Map<String, RaftSlotStyle> get slots => {'trigger': trigger, 'positioner': positioner, 'content': content, 'item': item, 'radioItem': radioItem, 'submenuTrigger': submenuTrigger, 'itemLabel': itemLabel, 'footer': footer, 'label': label, 'shortcut': shortcut, 'itemCount': itemCount, 'separator': separator, 'indicator': indicator, 'radioLabel': radioLabel};
}

/// raft-ui recipe `dropdownMenu` (`src/components/dropdown-menu/dropdown-menu.tsx`, index.mjs:5013).
///
/// Used by: DropdownMenuCheckboxItem, DropdownMenuContent, DropdownMenuFooter, DropdownMenuItem, DropdownMenuItemCount, DropdownMenuItemLabel, DropdownMenuLabel, DropdownMenuPopup, DropdownMenuRadioItem, DropdownMenuSeparator, DropdownMenuShortcut, DropdownMenuSubmenuTrigger, DropdownMenuTrigger.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftDropdownMenuRecipe {
  static const String recipeName = 'dropdownMenu';
  static const List<String> slotNames = ['trigger', 'positioner', 'content', 'item', 'radioItem', 'submenuTrigger', 'itemLabel', 'footer', 'label', 'shortcut', 'itemCount', 'separator', 'indicator', 'radioLabel'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftDropdownMenuRecipeStyle resolve({required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name], states, tokens);
    return RaftDropdownMenuRecipeStyle(trigger: s[0], positioner: s[1], content: s[2], item: s[3], radioItem: s[4], submenuTrigger: s[5], itemLabel: s[6], footer: s[7], label: s[8], shortcut: s[9], itemCount: s[10], separator: s[11], indicator: s[12], radioLabel: s[13]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [2834, 1519, 1534, 609, 581, 603],
    [2309, 3142, 2649],
    [2361, 2579, 2656, 2649, 866, 876, 828, 2862],
    [1620, 3127, 939, 2834, 2312, 1698, 2753, 567, 3003, 2649, 3084, 2765, 1691, 3017, 1688, 2987, 2228, 1483, 1447, 1453, 1329, 1224, 1235, 1234, 1233, 1232, 298, 302, 309, 323, 288],
    [1620, 3127, 939, 2834, 2312, 1698, 2753, 3003, 2649, 3084, 2656, 2765, 1691, 3017, 1688, 2335, 2987, 873, 889, 2324, 2228, 1483, 1447, 1453, 298, 302, 309, 323, 288],
    [1620, 3127, 939, 2834, 2312, 1698, 2753, 567, 3003, 2649, 3084, 2765, 1691, 3017, 1688, 2987, 2228, 1483, 1526, 1447, 1453, 298, 302, 309, 323, 288],
    [2574, 1621, 3092, 3003],
    [2753, 2765, 3032, 2981, 2911],
    [873, 900, 2753, 2765, 1691, 2918, 1684, 3096, 2344, 3055, 2993],
    [2585, 1691, 3017, 1688],
    [2585, 2301, 2580, 2317, 1694, 2911, 2822, 864, 900, 780, 2749, 2761, 1691, 2918, 2344, 1684, 3026],
    [913, 876],
    [2716, 2585, 1620, 2878, 2867, 2312, 2317],
    [2574, 1621, 3092],
    [2834, 598],
    [2361, 2579, 2656, 1694, 2818, 828, 2669, 2861, 2649, 1620, 1622],
    [1620, 3127, 939, 2834, 2312, 567, 3003, 2649, 1699, 2822, 2753, 2763, 2924, 1690, 3046, 2981, 3069, 1602, 2222, 2276, 1482, 1484, 1447, 1452, 425, 427, 444, 459, 305, 318, 2177, 1479],
    [1620, 3127, 939, 2834, 2312, 3003, 2649, 1699, 2822, 2753, 2763, 2924, 1690, 3046, 2981, 3069, 1602, 2222, 2276, 1482, 1484, 1447, 1452, 425, 427, 444, 459, 305, 318, 2177, 1479],
    [1620, 3127, 939, 2834, 2312, 567, 3003, 2649, 1699, 2822, 2753, 2763, 2924, 1690, 3046, 2981, 3069, 1602, 2222, 2276, 1482, 1484, 1524, 1538, 1447, 1452, 425, 427, 444, 459, 305, 326, 318, 2177, 1479, 1520],
    [138, 2491, 873, 895, 2753, 2765, 1007, 2920, 1688, 2344, 3046, 2991],
    [2585, 2981],
    [2585, 2301, 2580, 2317, 1694, 2749, 2911],
    [2608, 138, 1979, 865, 829, 990],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13], [14, 1, 15, 16, 17, 18, 6, 7, 19, 20, 21, 22, 12, 13],
  ];
}
