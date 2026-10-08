// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `drawer$extend`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `side` axis of `drawer$extend`.
enum RaftDrawerBaseRecipeSide {
  down('down'),
  up('up'),
  left('left'),
  right('right');

  const RaftDrawerBaseRecipeSide(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// `axis` axis of `drawer$extend`.
enum RaftDrawerBaseRecipeAxis {
  x('x'),
  y('y');

  const RaftDrawerBaseRecipeAxis(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftDrawerBaseRecipe].
class RaftDrawerBaseRecipeStyle {
  const RaftDrawerBaseRecipeStyle({required this.overlay, required this.popup, required this.content, required this.swipeHandle});

  /// Slot `overlay`.
  final RaftSlotStyle overlay;
  /// Slot `popup`.
  final RaftSlotStyle popup;
  /// Slot `content`.
  final RaftSlotStyle content;
  /// Slot `swipeHandle`.
  final RaftSlotStyle swipeHandle;

  Map<String, RaftSlotStyle> get slots => {'overlay': overlay, 'popup': popup, 'content': content, 'swipeHandle': swipeHandle};
}

/// raft-ui recipe `drawer$extend` (`src/components/dialog/dialog.tsx`, index.mjs:1014).
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftDrawerBaseRecipe {
  static const String recipeName = 'drawer\$extend';
  static const List<String> slotNames = ['overlay', 'popup', 'content', 'swipeHandle'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('side', ['down', 'up', 'left', 'right'], null, true),
    RaftRecipeAxis('axis', ['x', 'y'], null, true),
    RaftRecipeAxis('snapPoints', ['true', 'false'], null, true),
  ];

  static RaftDrawerBaseRecipeStyle resolve({RaftDrawerBaseRecipeSide? side, RaftDrawerBaseRecipeAxis? axis, bool? snapPoints, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [side?.css, axis?.css, snapPoints?.toString()], states, tokens);
    return RaftDrawerBaseRecipeStyle(overlay: s[0], popup: s[1], content: s[2], swipeHandle: s[3]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [2633, 3085, 1605, 1614, 1566, 1465, 1464, 1461, 2593],
    [474, 477, 471, 489, 497, 490, 488, 491, 492, 494, 493, 2638, 3058, 2627, 863, 3080, 1607, 1610, 3134, 1462, 1569, 1566, 1565, 1467, 1464, 1456, 1572, 1518, 2593],
    [3085, 1602, 1614, 2593, 1844, 1845],
    [3085, 1602, 2593, 1844, 1845],
    [2633, 3085, 1605, 1614, 1566, 1465, 1464, 1461, 2593, 487],
    [474, 477, 471, 489, 497, 490, 488, 491, 492, 494, 493, 2638, 3058, 2627, 863, 3080, 1607, 1610, 3134, 1462, 1569, 1566, 1565, 1467, 1464, 1456, 1572, 1518, 2593, 495, 502],
    [474, 477, 471, 489, 497, 490, 488, 491, 492, 494, 493, 2638, 3058, 2627, 863, 3080, 1607, 1610, 3134, 1462, 1569, 1566, 1565, 1467, 1464, 1456, 1572, 1518, 2593, 496, 503],
    [474, 477, 471, 489, 497, 490, 488, 491, 492, 494, 493, 2638, 3058, 2627, 863, 3080, 1607, 1610, 3134, 1462, 1569, 1566, 1565, 1467, 1464, 1456, 1572, 1518, 2593, 481, 500, 507],
    [474, 477, 471, 489, 497, 490, 488, 491, 492, 494, 493, 2638, 3058, 2627, 863, 3080, 1607, 1610, 3134, 1462, 1569, 1566, 1565, 1467, 1464, 1456, 1572, 1518, 2593, 481, 500, 507, 495, 502],
    [474, 477, 471, 489, 497, 490, 488, 491, 492, 494, 493, 2638, 3058, 2627, 863, 3080, 1607, 1610, 3134, 1462, 1569, 1566, 1565, 1467, 1464, 1456, 1572, 1518, 2593, 481, 500, 507, 496, 503],
    [474, 477, 471, 489, 497, 490, 488, 491, 492, 494, 493, 2638, 3058, 2627, 863, 3080, 1607, 1610, 3134, 1462, 1569, 1566, 1565, 1467, 1464, 1456, 1572, 1518, 2593, 480, 501, 506],
    [474, 477, 471, 489, 497, 490, 488, 491, 492, 494, 493, 2638, 3058, 2627, 863, 3080, 1607, 1610, 3134, 1462, 1569, 1566, 1565, 1467, 1464, 1456, 1572, 1518, 2593, 480, 501, 506, 495, 502],
    [474, 477, 471, 489, 497, 490, 488, 491, 492, 494, 493, 2638, 3058, 2627, 863, 3080, 1607, 1610, 3134, 1462, 1569, 1566, 1565, 1467, 1464, 1456, 1572, 1518, 2593, 480, 501, 506, 496, 503],
    [474, 477, 471, 489, 497, 490, 488, 491, 492, 494, 493, 2638, 3058, 2627, 863, 3080, 1607, 1610, 3134, 1462, 1569, 1566, 1565, 1467, 1464, 1456, 1572, 1518, 2593, 478, 499, 504],
    [474, 477, 471, 489, 497, 490, 488, 491, 492, 494, 493, 2638, 3058, 2627, 863, 3080, 1607, 1610, 3134, 1462, 1569, 1566, 1565, 1467, 1464, 1456, 1572, 1518, 2593, 478, 499, 504, 495, 502],
    [474, 477, 471, 489, 497, 490, 488, 491, 492, 494, 493, 2638, 3058, 2627, 863, 3080, 1607, 1610, 3134, 1462, 1569, 1566, 1565, 1467, 1464, 1456, 1572, 1518, 2593, 478, 499, 504, 496, 503],
    [474, 477, 471, 489, 497, 490, 488, 491, 492, 494, 493, 2638, 3058, 2627, 863, 3080, 1607, 1610, 3134, 1462, 1569, 1566, 1565, 1467, 1464, 1456, 1572, 1518, 2593, 479, 498, 505],
    [474, 477, 471, 489, 497, 490, 488, 491, 492, 494, 493, 2638, 3058, 2627, 863, 3080, 1607, 1610, 3134, 1462, 1569, 1566, 1565, 1467, 1464, 1456, 1572, 1518, 2593, 479, 498, 505, 495, 502],
    [474, 477, 471, 489, 497, 490, 488, 491, 492, 494, 493, 2638, 3058, 2627, 863, 3080, 1607, 1610, 3134, 1462, 1569, 1566, 1565, 1467, 1464, 1456, 1572, 1518, 2593, 479, 498, 505, 496, 503],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3], [4, 1, 2, 3], [0, 1, 2, 3], [0, 5, 2, 3], [4, 5, 2, 3], [0, 5, 2, 3], [0, 6, 2, 3], [4, 6, 2, 3], [0, 6, 2, 3], [0, 7, 2, 3], [4, 7, 2, 3], [0, 7, 2, 3], [0, 8, 2, 3], [4, 8, 2, 3], [0, 8, 2, 3], [0, 9, 2, 3],
    [4, 9, 2, 3], [0, 9, 2, 3], [0, 10, 2, 3], [4, 10, 2, 3], [0, 10, 2, 3], [0, 11, 2, 3], [4, 11, 2, 3], [0, 11, 2, 3], [0, 12, 2, 3], [4, 12, 2, 3], [0, 12, 2, 3], [0, 13, 2, 3], [4, 13, 2, 3], [0, 13, 2, 3], [0, 14, 2, 3], [4, 14, 2, 3],
    [0, 14, 2, 3], [0, 15, 2, 3], [4, 15, 2, 3], [0, 15, 2, 3], [0, 16, 2, 3], [4, 16, 2, 3], [0, 16, 2, 3], [0, 17, 2, 3], [4, 17, 2, 3], [0, 17, 2, 3], [0, 18, 2, 3], [4, 18, 2, 3], [0, 18, 2, 3],
  ];
}
