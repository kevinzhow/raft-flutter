// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `copyableCode`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `size` axis of `copyableCode` (default `md`).
enum RaftCopyableCodeRecipeSize {
  sm('sm'),
  md('md');

  const RaftCopyableCodeRecipeSize(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftCopyableCodeRecipe].
class RaftCopyableCodeRecipeStyle {
  const RaftCopyableCodeRecipeStyle({required this.root, required this.code, required this.codeInner, required this.action, required this.iconSwap});

  /// Slot `root`.
  final RaftSlotStyle root;
  /// Slot `code`.
  final RaftSlotStyle code;
  /// Slot `codeInner`.
  final RaftSlotStyle codeInner;
  /// Slot `action`.
  final RaftSlotStyle action;
  /// Slot `iconSwap`.
  final RaftSlotStyle iconSwap;

  Map<String, RaftSlotStyle> get slots => {'root': root, 'code': code, 'codeInner': codeInner, 'action': action, 'iconSwap': iconSwap};
}

/// raft-ui recipe `copyableCode` (`src/components/copyable-code/copyable-code.tsx`, index.mjs:2404).
///
/// Used by: CopyableCode, CopyableCodeAction, CopyableCodeRoot.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftCopyableCodeRecipe {
  static const String recipeName = 'copyableCode';
  static const List<String> slotNames = ['root', 'code', 'codeInner', 'action', 'iconSwap'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
    RaftRecipeAxis('size', ['sm', 'md'], 'md', false),
  ];

  static RaftCopyableCodeRecipeStyle resolve({required RaftRecipeTheme theme, RaftCopyableCodeRecipeSize? size, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name, size?.css], states, tokens);
    return RaftCopyableCodeRecipeStyle(root: s[0], code: s[1], codeInner: s[2], action: s[3], iconSwap: s[4]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [1917, 1620, 3127, 2574, 2312, 1698],
    [2574, 1621, 1689, 3032, 866, 900, 763, 2946, 2863, 2753, 2763, 2335],
    [862, 3127, 2574, 2484, 932],
    [2867, 22, 13, 378],
    [2775, 2302, 2878, 25, 29, 28, 30, 26, 27, 31, 2586, 1366, 1365, 1367, 1364, 1363, 1362, 1357, 1356, 1361, 1360, 1359, 1358],
    [2574, 1621, 1689, 3032, 866, 900, 763, 2946, 2863, 2753, 2765, 2335],
    [2574, 1621, 1689, 3032, 824, 2940, 2793, 2795, 1132, 1149, 2335, 2751, 2760],
    [862, 3127, 2574, 2484, 932, 921, 886, 889, 1005, 825, 2749, 967, 2763, 2335],
    [2867, 22, 13, 378, 21, 19, 16, 18, 14],
    [862, 3127, 2574, 2484, 932, 921, 886, 889, 1005, 825, 2749, 967, 2765, 2335],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4], [0, 5, 2, 3, 4], [0, 6, 7, 8, 4], [0, 6, 9, 8, 4],
  ];
}
