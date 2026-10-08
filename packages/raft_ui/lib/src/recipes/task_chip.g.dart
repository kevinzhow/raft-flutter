// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `taskChip`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `status` axis of `taskChip`.
enum RaftTaskChipRecipeStatus {
  todo('todo'),
  inProgress('in-progress'),
  inReview('in-review'),
  done('done'),
  closed('closed');

  const RaftTaskChipRecipeStatus(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// `variant` axis of `taskChip` (default `default`).
enum RaftTaskChipRecipeVariant {
  default_('default'),
  inline('inline');

  const RaftTaskChipRecipeVariant(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftTaskChipRecipe].
class RaftTaskChipRecipeStyle {
  const RaftTaskChipRecipeStyle({required this.root});

  /// Slot `root`.
  final RaftSlotStyle root;

  Map<String, RaftSlotStyle> get slots => {'root': root};
}

/// raft-ui recipe `taskChip` (`src/components/tasks/task-chip.tsx`, index.mjs:19273).
///
/// Used by: TaskChip.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftTaskChipRecipe {
  static const String recipeName = 'taskChip';
  static const List<String> slotNames = ['root'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
    RaftRecipeAxis('status', ['todo', 'in-progress', 'in-review', 'done', 'closed'], null, true),
    RaftRecipeAxis('variant', ['default', 'inline'], 'default', false),
  ];

  static RaftTaskChipRecipeStyle resolve({required RaftRecipeTheme theme, RaftTaskChipRecipeStatus? status, RaftTaskChipRecipeVariant? variant, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name, status?.css, variant?.css], states, tokens);
    return RaftTaskChipRecipeStyle(root: s[0]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [2301, 2484, 2312, 1697, 635, 2656, 2815, 864, 2751, 2760, 1688, 576, 2342, 3053, 3131, 302, 303, 2976, 2611, 2835, 3075, 1601, 2254, 1639, 1647, 1644],
    [2301, 2484, 2312, 2656, 864, 576, 3053, 3131, 302, 303, 2611, 2835, 3075, 1601, 1639, 1647, 1644, 1696, 636, 2819, 876, 2749, 2760, 2924, 1688, 2347, 2956, 2252],
    [2301, 2484, 2656, 3053, 3131, 302, 2611, 2835, 3075, 1601, 1639, 1647, 1644, 2311, 795, 2760, 635, 576, 2340, 307, 301, 1696, 2819, 864, 876, 2749, 1688, 2956, 2252],
    [2301, 2484, 2312, 2656, 2815, 2751, 2760, 576, 3053, 3131, 302, 303, 2611, 2835, 3075, 1601, 2254, 1639, 1647, 1644, 869, 817, 2976, 1969, 637, 136, 1697, 2924, 1690, 2344, 867],
    [2301, 2484, 2656, 2751, 3053, 3131, 302, 2611, 2835, 3075, 1601, 1639, 1647, 1644, 2976, 2311, 1697, 2815, 864, 916, 795, 2760, 2721, 2697, 635, 576, 2340, 1681, 2251, 307, 301],
    [2301, 2484, 2312, 2656, 2815, 2751, 2760, 576, 3053, 3131, 302, 303, 2611, 2835, 3075, 1601, 2254, 1639, 1647, 1644, 905, 838, 3008, 1172, 1969, 637, 136, 1697, 2924, 1690, 2344, 867],
    [2301, 2484, 2656, 2751, 3053, 3131, 302, 2611, 2835, 3075, 1601, 1639, 1647, 1644, 3008, 1172, 2311, 1697, 2815, 864, 916, 795, 2760, 2721, 2697, 635, 576, 2340, 1681, 2251, 307, 301],
    [2301, 2484, 2312, 2656, 2815, 2751, 2760, 576, 3053, 3131, 302, 303, 2611, 2835, 3075, 1601, 2254, 1639, 1647, 1644, 918, 854, 3025, 1969, 637, 136, 1697, 2924, 1690, 2344, 867],
    [2301, 2484, 2656, 2751, 3053, 3131, 302, 2611, 2835, 3075, 1601, 1639, 1647, 1644, 3025, 2311, 1697, 2815, 864, 916, 795, 2760, 2721, 2697, 635, 576, 2340, 1681, 2251, 307, 301],
    [2301, 2484, 2312, 2656, 2815, 2751, 2760, 576, 3053, 3131, 302, 303, 2611, 2835, 3075, 1601, 2254, 1639, 1647, 1644, 910, 847, 3021, 1969, 637, 136, 1697, 2924, 1690, 2344, 867],
    [2301, 2484, 2656, 2751, 3053, 3131, 302, 2611, 2835, 3075, 1601, 1639, 1647, 1644, 3021, 2311, 1697, 2815, 864, 916, 795, 2760, 2721, 2697, 635, 576, 2340, 1681, 2251, 307, 301],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0], [0], [1], [2], [1], [2], [1], [2], [1], [2], [1], [2], [0], [0], [3], [4],
    [5], [6], [7], [8], [9], [10], [3], [4],
  ];
}
