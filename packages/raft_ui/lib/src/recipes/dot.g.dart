// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `dot`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `variant` axis of `dot` (default `default`).
enum RaftDotRecipeVariant {
  default_('default'),
  primary('primary'),
  information('information'),
  muted('muted'),
  accent('accent'),
  success('success'),
  warning('warning'),
  danger('danger');

  const RaftDotRecipeVariant(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftDotRecipe].
class RaftDotRecipeStyle {
  const RaftDotRecipeStyle({required this.root});

  /// Slot `root`.
  final RaftSlotStyle root;

  Map<String, RaftSlotStyle> get slots => {'root': root};
}

/// raft-ui recipe `dot` (`src/components/status/status.tsx`, index.mjs:2027).
///
/// Used by: AvatarBadge, Banner, LegacyTaskPanelStatus, LiveAgentActivityBarStatus, MessageItemBadge, NotificationCenterItemIcon, PanelStatus, RadioGroupIndicator, Status, Step, Steps, TaskBoardColumnBadge, TaskCardStatus, TaskChip, TaskClosedIcon, TaskDoneIcon, TaskInProgressIcon, TaskInReviewIcon, TaskSectionBadge, TaskStatusBadge, TaskStatusIcon, TaskTodoIcon, TimelineItem.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftDotRecipe {
  static const String recipeName = 'dot';
  static const List<String> slotNames = ['root'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
    RaftRecipeAxis(
      'variant',
      [
        'default',
        'primary',
        'information',
        'muted',
        'accent',
        'success',
        'warning',
        'danger',
      ],
      'default',
      false,
    ),
  ];

  static RaftDotRecipeStyle resolve({
    required RaftRecipeTheme theme,
    RaftDotRecipeVariant? variant,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [theme.name, variant?.css],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftDotRecipeStyle(root: s[0]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(
    Map<String, String?> props, {
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [for (final a in axes) props[a.name]],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [2804, 2319, 2902, 2845, 744, 876, 916, 543],
    [2804, 2319, 2902, 2845, 744, 876, 916, 545],
    [2804, 2319, 2902, 2845, 744, 876, 916, 544],
    [2804, 2319, 2902, 2845, 744, 876, 916, 546],
    [2804, 2319, 2902, 2845, 744, 876, 916, 540],
    [2804, 2319, 2902, 2845, 744, 876, 916, 547],
    [2804, 2319, 2902, 2845, 744, 876, 916, 548],
    [2804, 2319, 2902, 2845, 744, 876, 916, 542],
    [2804, 2319, 2902, 2845, 744, 543],
    [2804, 2319, 2902, 2845, 744, 545],
    [2804, 2319, 2902, 2845, 744, 544],
    [2804, 2319, 2902, 2845, 744, 546],
    [2804, 2319, 2902, 2845, 744, 540],
    [2804, 2319, 2902, 2845, 744, 547],
    [2804, 2319, 2902, 2845, 744, 548],
    [2804, 2319, 2902, 2845, 744, 542],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0],
    [1],
    [2],
    [3],
    [4],
    [5],
    [6],
    [7],
    [8],
    [9],
    [10],
    [11],
    [12],
    [13],
    [14],
    [15],
  ];
}
