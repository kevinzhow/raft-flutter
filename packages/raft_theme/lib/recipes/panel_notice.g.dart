// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `panelNotice`.
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

/// raft-ui recipe `panelNotice` (`src/components/panel/panel-notice.tsx`, index.mjs:14132).
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
      965,
      1736,
      1320,
      1466,
      1023,
      623,
      634,
      1659,
      1668,
      1390,
      1015,
      1809,
      1016,
      1818,
      581,
    ],
    [1481, 966],
    [965, 1736, 1318, 100, 1024],
    [
      965,
      1736,
      1320,
      1466,
      1023,
      623,
      634,
      1659,
      1668,
      1390,
      1015,
      1809,
      1016,
      1818,
      617,
    ],
    [
      965,
      1736,
      1320,
      1466,
      1023,
      623,
      634,
      1659,
      1668,
      1390,
      1015,
      1809,
      1016,
      1818,
      580,
    ],
    [
      965,
      1736,
      1320,
      1466,
      1023,
      623,
      634,
      1659,
      1668,
      1390,
      1015,
      1809,
      1016,
      1818,
      593,
    ],
    [
      965,
      1736,
      1320,
      1466,
      1023,
      623,
      634,
      1659,
      1668,
      1390,
      1015,
      1809,
      1016,
      1818,
      609,
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
