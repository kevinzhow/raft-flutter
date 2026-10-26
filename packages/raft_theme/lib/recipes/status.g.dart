// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `status`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `variant` axis of `status` (default `default`).
enum RaftStatusRecipeVariant {
  default_('default'),
  primary('primary'),
  information('information'),
  muted('muted'),
  accent('accent'),
  success('success'),
  warning('warning'),
  danger('danger');

  const RaftStatusRecipeVariant(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// `size` axis of `status` (default `md`).
enum RaftStatusRecipeSize {
  xs('xs'),
  sm('sm'),
  md('md'),
  lg('lg');

  const RaftStatusRecipeSize(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftStatusRecipe].
class RaftStatusRecipeStyle {
  const RaftStatusRecipeStyle({required this.root});

  /// Slot `root`.
  final RaftSlotStyle root;

  Map<String, RaftSlotStyle> get slots => {'root': root};
}

/// raft-ui recipe `status` (`src/components/status/status.tsx`, index.mjs:2030).
///
/// Used by: Banner, FormSection, LegacyTaskPanelStatus, LiveAgentActivityBarStatus, MessageActionCardStatus, MessageItemBadge, NotificationCenterItemIcon, OtterIndicator, PanelNotice, PanelStatus, Status, Step, Steps, TaskBoardColumnBadge, TaskCardStatus, TaskChip, TaskClosedIcon, TaskDoneIcon, TaskInProgressIcon, TaskInReviewIcon, TaskSectionBadge, TaskStatusBadge, TaskStatusIcon, TaskTodoIcon, TimelineItem.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftStatusRecipe {
  static const String recipeName = 'status';
  static const List<String> slotNames = ['root'];
  static const List<RaftRecipeAxis> axes = [
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
    RaftRecipeAxis('size', ['xs', 'sm', 'md', 'lg'], 'md', false),
  ];

  static RaftStatusRecipeStyle resolve({
    RaftStatusRecipeVariant? variant,
    RaftStatusRecipeSize? size,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [variant?.css, size?.css],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftStatusRecipeStyle(root: s[0]);
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
    [1678, 1303, 1736, 568, 637, 370, 1741, 1699, 620],
    [1678, 1303, 1736, 568, 1700, 622, 637, 370, 1746],
    [1678, 1303, 1736, 568, 1700, 622, 637, 370, 1764],
    [1678, 1303, 1736, 568, 1700, 622, 637, 370, 1755],
    [1678, 1303, 1736, 568, 637, 365, 1741, 1699, 620],
    [1678, 1303, 1736, 568, 1700, 622, 637, 365, 1746],
    [1678, 1303, 1736, 568, 1700, 622, 637, 365, 1764],
    [1678, 1303, 1736, 568, 1700, 622, 637, 365, 1755],
    [1678, 1303, 1736, 568, 637, 364, 1741, 1699, 620],
    [1678, 1303, 1736, 568, 1700, 622, 637, 364, 1746],
    [1678, 1303, 1736, 568, 1700, 622, 637, 364, 1764],
    [1678, 1303, 1736, 568, 1700, 622, 637, 364, 1755],
    [1678, 1303, 1736, 568, 637, 366, 1741, 1699, 620],
    [1678, 1303, 1736, 568, 1700, 622, 637, 366, 1746],
    [1678, 1303, 1736, 568, 1700, 622, 637, 366, 1764],
    [1678, 1303, 1736, 568, 1700, 622, 637, 366, 1755],
    [1678, 1303, 1736, 568, 637, 362, 1741, 1699, 620],
    [1678, 1303, 1736, 568, 1700, 622, 637, 362, 1746],
    [1678, 1303, 1736, 568, 1700, 622, 637, 362, 1764],
    [1678, 1303, 1736, 568, 1700, 622, 637, 362, 1755],
    [1678, 1303, 1736, 568, 637, 367, 1741, 1699, 620],
    [1678, 1303, 1736, 568, 1700, 622, 637, 367, 1746],
    [1678, 1303, 1736, 568, 1700, 622, 637, 367, 1764],
    [1678, 1303, 1736, 568, 1700, 622, 637, 367, 1755],
    [1678, 1303, 1736, 568, 637, 368, 1741, 1699, 620],
    [1678, 1303, 1736, 568, 1700, 622, 637, 368, 1746],
    [1678, 1303, 1736, 568, 1700, 622, 637, 368, 1764],
    [1678, 1303, 1736, 568, 1700, 622, 637, 368, 1755],
    [1678, 1303, 1736, 568, 637, 363, 1741, 1699, 620],
    [1678, 1303, 1736, 568, 1700, 622, 637, 363, 1746],
    [1678, 1303, 1736, 568, 1700, 622, 637, 363, 1764],
    [1678, 1303, 1736, 568, 1700, 622, 637, 363, 1755],
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
    [16],
    [17],
    [18],
    [19],
    [20],
    [21],
    [22],
    [23],
    [24],
    [25],
    [26],
    [27],
    [28],
    [29],
    [30],
    [31],
  ];
}
