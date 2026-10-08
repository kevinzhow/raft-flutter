// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `codeBlock`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftCodeBlockRecipe].
class RaftCodeBlockRecipeStyle {
  const RaftCodeBlockRecipeStyle({required this.root, required this.header, required this.title, required this.actions, required this.corner, required this.body, required this.action});

  /// Slot `root`.
  final RaftSlotStyle root;
  /// Slot `header`.
  final RaftSlotStyle header;
  /// Slot `title`.
  final RaftSlotStyle title;
  /// Slot `actions`.
  final RaftSlotStyle actions;
  /// Slot `corner`.
  final RaftSlotStyle corner;
  /// Slot `body`.
  final RaftSlotStyle body;
  /// Slot `action`.
  final RaftSlotStyle action;

  Map<String, RaftSlotStyle> get slots => {'root': root, 'header': header, 'title': title, 'actions': actions, 'corner': corner, 'body': body, 'action': action};
}

/// raft-ui recipe `codeBlock` (`src/components/code-block/code-block.recipe.ts`, index.mjs:8489).
///
/// Used by: CodeBlock, CodeBlockAction, CodeBlockActions, CodeBlockBody, CodeBlockHeader, CodeBlockTitle.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftCodeBlockRecipe {
  static const String recipeName = 'codeBlock';
  static const List<String> slotNames = ['root', 'header', 'title', 'actions', 'corner', 'body', 'action'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftCodeBlockRecipeStyle resolve({required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name], states, tokens);
    return RaftCodeBlockRecipeStyle(root: s[0], header: s[1], title: s[2], actions: s[3], corner: s[4], body: s[5], action: s[6]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [1915, 2775, 2609, 2574, 473, 2747, 2679, 866, 900, 763, 2863],
    [1620, 1941, 2312, 1700, 2753, 3017, 1684, 3055, 2979, 3096],
    [2574, 1621, 3092, 1689, 3032, 716, 723, 704],
    [2585, 1620, 2312, 1698, 568, 570, 569, 571],
    [2716, 580, 3139, 2869, 1383, 1381, 1377, 1379, 887, 1382, 1380, 1376, 1378],
    [2775, 2574, 2658, 2673, 1689, 3017, 763, 2946, 2644, 140, 2647, 410],
    [2301, 2867, 2312, 2317, 3073, 1645, 1653, 2883, 802, 2980, 2215, 2278, 1657],
    [1915, 2775, 2609, 2574, 472, 2655, 2819, 2753, 2679, 824, 2793, 2795, 1132],
    [1620, 1941, 2312, 1700, 2752, 921, 873, 886, 889, 1005, 825, 3018, 1688, 2981, 1002],
    [2574, 1621, 3092, 1689, 3032],
    [2716, 580, 3139, 2869, 1383, 1381, 1377, 1379, 2174],
    [2775, 2574, 2658, 2673, 1689, 3017, 2767, 2725, 2700, 2345, 825, 2976, 967, 921, 886, 889, 1005, 411, 953],
    [2301, 2867, 2312, 2317, 3073, 1645, 1653],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6], [7, 8, 9, 3, 10, 11, 12],
  ];
}
