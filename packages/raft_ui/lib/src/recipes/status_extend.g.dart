// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `status$extend`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `variant` axis of `status$extend` (default `default`).
enum RaftStatusBaseRecipeVariant {
  default_('default'),
  primary('primary'),
  information('information'),
  muted('muted'),
  accent('accent'),
  success('success'),
  warning('warning'),
  danger('danger');

  const RaftStatusBaseRecipeVariant(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftStatusBaseRecipe].
class RaftStatusBaseRecipeStyle {
  const RaftStatusBaseRecipeStyle({required this.root});

  /// Slot `root`.
  final RaftSlotStyle root;

  Map<String, RaftSlotStyle> get slots => {'root': root};
}

/// raft-ui recipe `status$extend` (`src/components/status/status.tsx`, index.mjs:2018).
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftStatusBaseRecipe {
  static const String recipeName = 'status\$extend';
  static const List<String> slotNames = ['root'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
    RaftRecipeAxis('variant', ['default', 'primary', 'information', 'muted', 'accent', 'success', 'warning', 'danger'], 'default', false),
  ];

  static RaftStatusBaseRecipeStyle resolve({required RaftRecipeTheme theme, RaftStatusBaseRecipeVariant? variant, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name, variant?.css], states, tokens);
    return RaftStatusBaseRecipeStyle(root: s[0]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [2775, 2300, 2867, 2815, 738, 864, 900, 542],
    [2775, 2300, 2867, 2815, 738, 864, 900, 544],
    [2775, 2300, 2867, 2815, 738, 864, 900, 543],
    [2775, 2300, 2867, 2815, 738, 864, 900, 545],
    [2775, 2300, 2867, 2815, 738, 864, 900, 539],
    [2775, 2300, 2867, 2815, 738, 864, 900, 546],
    [2775, 2300, 2867, 2815, 738, 864, 900, 547],
    [2775, 2300, 2867, 2815, 738, 864, 900, 541],
    [2775, 2300, 2867, 2815, 738, 542],
    [2775, 2300, 2867, 2815, 738, 544],
    [2775, 2300, 2867, 2815, 738, 543],
    [2775, 2300, 2867, 2815, 738, 545],
    [2775, 2300, 2867, 2815, 738, 539],
    [2775, 2300, 2867, 2815, 738, 546],
    [2775, 2300, 2867, 2815, 738, 547],
    [2775, 2300, 2867, 2815, 738, 541],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0], [1], [2], [3], [4], [5], [6], [7], [8], [9], [10], [11], [12], [13], [14], [15],
  ];
}
