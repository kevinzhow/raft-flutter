// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `pickerTriggerButton`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftPickerTriggerButtonRecipe].
class RaftPickerTriggerButtonRecipeStyle {
  const RaftPickerTriggerButtonRecipeStyle({required this.base});

  /// Slot `base`.
  final RaftSlotStyle base;

  Map<String, RaftSlotStyle> get slots => {'base': base};
}

/// raft-ui recipe `pickerTriggerButton` (`src/components/picker-trigger-button/picker-trigger-button.tsx`, index.mjs:7146).
///
/// Used by: PickerTriggerButton.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftPickerTriggerButtonRecipe {
  static const String recipeName = 'pickerTriggerButton';
  static const List<String> slotNames = ['base'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftPickerTriggerButtonRecipeStyle resolve({required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name], states, tokens);
    return RaftPickerTriggerButtonRecipeStyle(base: s[0]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [2775, 2301, 1966, 2867, 2312, 2317, 1698, 2753, 2763, 3032, 3131, 2834, 2819, 2646, 2650, 2652, 3084, 1601, 1649, 1590, 1594, 1586, 2131, 2126, 425, 427, 417, 75, 866, 871, 856, 2860, 1691, 1684, 2948, 2287, 2241, 2237, 2267, 609, 610, 602, 1541, 1533, 355, 83, 82, 356, 357, 358],
    [2775, 2301, 2867, 2312, 2317, 1698, 3131, 2834, 2646, 2650, 2652, 3084, 1601, 1649, 1590, 1594, 1586, 2131, 2126, 425, 427, 417, 75, 1964, 2655, 2818, 865, 825, 2752, 2760, 1691, 3032, 1688, 3046, 2984, 643, 2850, 1146, 718, 688, 710, 731, 720, 690, 2221, 598, 983, 1100, 1652, 1665, 1661, 1663, 1500, 1508, 1503, 1504, 1506, 370, 351, 349, 350, 354, 352, 353],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0], [1],
  ];
}
