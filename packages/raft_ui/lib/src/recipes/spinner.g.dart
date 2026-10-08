// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `spinner`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `size` axis of `spinner` (default `sm`).
enum RaftSpinnerRecipeSize {
  xs('xs'),
  sm('sm'),
  md('md'),
  lg('lg');

  const RaftSpinnerRecipeSize(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// `variant` axis of `spinner`.
enum RaftSpinnerRecipeVariant {
  default_('default'),
  inverse('inverse');

  const RaftSpinnerRecipeVariant(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftSpinnerRecipe].
class RaftSpinnerRecipeStyle {
  const RaftSpinnerRecipeStyle({required this.root, required this.ring});

  /// Slot `root`.
  final RaftSlotStyle root;
  /// Slot `ring`.
  final RaftSlotStyle ring;

  Map<String, RaftSlotStyle> get slots => {'root': root, 'ring': ring};
}

/// raft-ui recipe `spinner` (`src/components/spinner/spinner.tsx`, index.mjs:106).
///
/// Used by: Spinner.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftSpinnerRecipe {
  static const String recipeName = 'spinner';
  static const List<String> slotNames = ['root', 'ring'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
    RaftRecipeAxis('size', ['xs', 'sm', 'md', 'lg'], 'sm', false),
    RaftRecipeAxis('variant', ['default', 'inverse'], null, true),
  ];

  static RaftSpinnerRecipeStyle resolve({required RaftRecipeTheme theme, RaftSpinnerRecipeSize? size, RaftSpinnerRecipeVariant? variant, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name, size?.css, variant?.css], states, tokens);
    return RaftSpinnerRecipeStyle(root: s[0], ring: s[1]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [2775, 2301, 2867, 2312, 2317, 2344, 2971, 2877],
    [862, 2890, 2867],
    [2775, 2301, 2867, 2312, 2317, 2344, 2877, 2956],
    [862, 2890, 2867, 642, 2815, 866, 883, 915],
    [2775, 2301, 2867, 2312, 2317, 2344, 2877, 3026],
    [862, 2890, 2867, 642, 2815, 866, 884, 915],
    [2775, 2301, 2867, 2312, 2317, 2344, 2971, 2880],
    [2775, 2301, 2867, 2312, 2317, 2344, 2880, 2956],
    [2775, 2301, 2867, 2312, 2317, 2344, 2880, 3026],
    [2775, 2301, 2867, 2312, 2317, 2344, 2971, 2882],
    [2775, 2301, 2867, 2312, 2317, 2344, 2882, 2956],
    [2775, 2301, 2867, 2312, 2317, 2344, 2882, 3026],
    [2775, 2301, 2867, 2312, 2317, 2344, 2971, 2885],
    [2775, 2301, 2867, 2312, 2317, 2344, 2885, 2956],
    [2775, 2301, 2867, 2312, 2317, 2344, 2885, 3026],
    [2775, 2301, 2867, 2312, 2317, 2344, 2971, 2879],
    [2775, 2301, 2867, 2312, 2317, 2344, 2971, 2881],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1], [2, 3], [4, 5], [6, 1], [7, 3], [8, 5], [9, 1], [10, 3], [11, 5], [12, 1], [13, 3], [14, 5], [15, 1], [15, 1], [15, 1], [15, 1],
    [15, 1], [15, 1], [16, 1], [16, 1], [16, 1], [16, 1], [16, 1], [16, 1],
  ];
}
