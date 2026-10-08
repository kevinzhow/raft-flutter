// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `heading`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `level` axis of `heading` (default `1`).
enum RaftHeadingRecipeLevel {
  v1('1'),
  v2('2'),
  v3('3'),
  v4('4'),
  v5('5'),
  v6('6');

  const RaftHeadingRecipeLevel(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// `variant` axis of `heading`.
enum RaftHeadingRecipeVariant {
  default_('default'),
  primary('primary'),
  information('information'),
  muted('muted'),
  placeholder('placeholder'),
  accent('accent'),
  success('success'),
  warning('warning'),
  danger('danger');

  const RaftHeadingRecipeVariant(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftHeadingRecipe].
class RaftHeadingRecipeStyle {
  const RaftHeadingRecipeStyle({required this.base});

  /// Slot `base`.
  final RaftSlotStyle base;

  Map<String, RaftSlotStyle> get slots => {'base': base};
}

/// raft-ui recipe `heading` (`src/components/text/text.tsx`, index.mjs:12344).
///
/// Used by: MarkdownHeading, PanelHeading, TaskBoardColumnHeading, TaskSectionHeading, TextHeading.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftHeadingRecipe {
  static const String recipeName = 'heading';
  static const List<String> slotNames = ['base'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('level', ['1', '2', '3', '4', '5', '6'], '1', false),
    RaftRecipeAxis('variant', ['default', 'primary', 'information', 'muted', 'placeholder', 'accent', 'success', 'warning', 'danger'], null, true),
  ];

  static RaftHeadingRecipeStyle resolve({RaftHeadingRecipeLevel? level, RaftHeadingRecipeVariant? variant, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [level?.css, variant?.css], states, tokens);
    return RaftHeadingRecipeStyle(base: s[0]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [2359, 1687, 1688, 2976, 2930, 3047, 2330],
    [2359, 1687, 1688, 2930, 3047, 2330, 2976],
    [2359, 1687, 1688, 2930, 3047, 2330, 3007],
    [2359, 1687, 1688, 2930, 3047, 2330, 2999],
    [2359, 1687, 1688, 2930, 3047, 2330, 2981],
    [2359, 1687, 1688, 2930, 3047, 2330, 2984],
    [2359, 1687, 1688, 2930, 3047, 2330, 2951],
    [2359, 1687, 1688, 2930, 3047, 2330, 3019],
    [2359, 1687, 1688, 2930, 3047, 2330, 3023],
    [2359, 1687, 1688, 2930, 3047, 2330, 2972],
    [2359, 1687, 1688, 2976, 2914, 3047, 2329],
    [2359, 1687, 1688, 2914, 3047, 2329, 2976],
    [2359, 1687, 1688, 2914, 3047, 2329, 3007],
    [2359, 1687, 1688, 2914, 3047, 2329, 2999],
    [2359, 1687, 1688, 2914, 3047, 2329, 2981],
    [2359, 1687, 1688, 2914, 3047, 2329, 2984],
    [2359, 1687, 1688, 2914, 3047, 2329, 2951],
    [2359, 1687, 1688, 2914, 3047, 2329, 3019],
    [2359, 1687, 1688, 2914, 3047, 2329, 3023],
    [2359, 1687, 1688, 2914, 3047, 2329, 2972],
    [2359, 1687, 1688, 2976, 2928, 3047, 2328],
    [2359, 1687, 1688, 2928, 3047, 2328, 2976],
    [2359, 1687, 1688, 2928, 3047, 2328, 3007],
    [2359, 1687, 1688, 2928, 3047, 2328, 2999],
    [2359, 1687, 1688, 2928, 3047, 2328, 2981],
    [2359, 1687, 1688, 2928, 3047, 2328, 2984],
    [2359, 1687, 1688, 2928, 3047, 2328, 2951],
    [2359, 1687, 1688, 2928, 3047, 2328, 3019],
    [2359, 1687, 1688, 2928, 3047, 2328, 3023],
    [2359, 1687, 1688, 2928, 3047, 2328, 2972],
    [2359, 1687, 1688, 2976, 2927, 3046, 2327],
    [2359, 1687, 1688, 2927, 3046, 2327, 2976],
    [2359, 1687, 1688, 2927, 3046, 2327, 3007],
    [2359, 1687, 1688, 2927, 3046, 2327, 2999],
    [2359, 1687, 1688, 2927, 3046, 2327, 2981],
    [2359, 1687, 1688, 2927, 3046, 2327, 2984],
    [2359, 1687, 1688, 2927, 3046, 2327, 2951],
    [2359, 1687, 1688, 2927, 3046, 2327, 3019],
    [2359, 1687, 1688, 2927, 3046, 2327, 3023],
    [2359, 1687, 1688, 2927, 3046, 2327, 2972],
    [2359, 1687, 1688, 2976, 2913, 2339],
    [2359, 1687, 1688, 2913, 2339, 2976],
    [2359, 1687, 1688, 2913, 2339, 3007],
    [2359, 1687, 1688, 2913, 2339, 2999],
    [2359, 1687, 1688, 2913, 2339, 2981],
    [2359, 1687, 1688, 2913, 2339, 2984],
    [2359, 1687, 1688, 2913, 2339, 2951],
    [2359, 1687, 1688, 2913, 2339, 3019],
    [2359, 1687, 1688, 2913, 2339, 3023],
    [2359, 1687, 1688, 2913, 2339, 2972],
    [2359, 1687, 1688, 2976, 3031, 2338],
    [2359, 1687, 1688, 3031, 2338, 2976],
    [2359, 1687, 1688, 3031, 2338, 3007],
    [2359, 1687, 1688, 3031, 2338, 2999],
    [2359, 1687, 1688, 3031, 2338, 2981],
    [2359, 1687, 1688, 3031, 2338, 2984],
    [2359, 1687, 1688, 3031, 2338, 2951],
    [2359, 1687, 1688, 3031, 2338, 3019],
    [2359, 1687, 1688, 3031, 2338, 3023],
    [2359, 1687, 1688, 3031, 2338, 2972],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0], [1], [2], [3], [4], [5], [6], [7], [8], [9], [10], [11], [12], [13], [14], [15],
    [16], [17], [18], [19], [20], [21], [22], [23], [24], [25], [26], [27], [28], [29], [30], [31],
    [32], [33], [34], [35], [36], [37], [38], [39], [40], [41], [42], [43], [44], [45], [46], [47],
    [48], [49], [50], [51], [52], [53], [54], [55], [56], [57], [58], [59],
  ];
}
