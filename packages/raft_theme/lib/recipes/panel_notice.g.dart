// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `panelNotice`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `status` axis of `panelNotice` (default `warning`).
enum RaftPanelNoticeRecipeStatus {
  default_('default'),
  warning('warning'),
  destructive('destructive'),
  info('info'),
  success('success');

  const RaftPanelNoticeRecipeStatus(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftPanelNoticeRecipe].
class RaftPanelNoticeRecipeStyle {
  const RaftPanelNoticeRecipeStyle({
    required this.root,
    required this.content,
    required this.actions,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `content`.
  final RaftSlotStyle content;

  /// Slot `actions`.
  final RaftSlotStyle actions;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'content': content,
    'actions': actions,
  };
}

/// raft-ui recipe `panelNotice` (`dist/components/panel/panel-notice.mjs`, index.mjs:20144).
///
/// Used by: PanelNotice, PanelNoticeActions, PanelNoticeContent.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftPanelNoticeRecipe {
  static const String recipeName = 'panelNotice';
  static const List<String> slotNames = ['root', 'content', 'actions'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis(
      'status',
      ['default', 'warning', 'destructive', 'info', 'success'],
      'warning',
      false,
    ),
  ];

  static RaftPanelNoticeRecipeStyle resolve({
    RaftPanelNoticeRecipeStatus? status,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [status?.css],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftPanelNoticeRecipeStyle(root: s[0], content: s[1], actions: s[2]);
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
    [
      1400,
      2499,
      1866,
      2099,
      1467,
      942,
      954,
      2394,
      2418,
      1456,
      2587,
      1457,
      2598,
      339,
      130,
      135,
      131,
      895,
    ],
    [2116, 1401],
    [1400, 2499, 1864, 179, 1468],
    [
      1400,
      2499,
      1866,
      2099,
      1467,
      942,
      954,
      2394,
      2418,
      1456,
      2587,
      1457,
      2598,
      339,
      130,
      135,
      131,
      935,
    ],
    [
      1400,
      2499,
      1866,
      2099,
      1467,
      942,
      954,
      2394,
      2418,
      1456,
      2587,
      1457,
      2598,
      339,
      130,
      135,
      131,
      893,
    ],
    [
      1400,
      2499,
      1866,
      2099,
      1467,
      942,
      954,
      2394,
      2418,
      1456,
      2587,
      1457,
      2598,
      339,
      130,
      135,
      131,
      907,
    ],
    [
      1400,
      2499,
      1866,
      2099,
      1467,
      942,
      954,
      2394,
      2418,
      1456,
      2587,
      1457,
      2598,
      339,
      130,
      135,
      131,
      927,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2],
    [3, 1, 2],
    [4, 1, 2],
    [5, 1, 2],
    [6, 1, 2],
  ];
}
