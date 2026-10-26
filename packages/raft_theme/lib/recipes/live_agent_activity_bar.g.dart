// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `liveAgentActivityBar`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftLiveAgentActivityBarRecipe].
class RaftLiveAgentActivityBarRecipeStyle {
  const RaftLiveAgentActivityBarRecipeStyle({
    required this.root,
    required this.row,
    required this.avatar,
    required this.content,
    required this.status,
    required this.text,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `row`.
  final RaftSlotStyle row;

  /// Slot `avatar`.
  final RaftSlotStyle avatar;

  /// Slot `content`.
  final RaftSlotStyle content;

  /// Slot `status`.
  final RaftSlotStyle status;

  /// Slot `text`.
  final RaftSlotStyle text;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'row': row,
    'avatar': avatar,
    'content': content,
    'status': status,
    'text': text,
  };
}

/// raft-ui recipe `liveAgentActivityBar` (`src/components/live-agent-activity-bar/live-agent-activity-bar.tsx`, index.mjs:14432).
///
/// Used by: LiveAgentActivityBar, LiveAgentActivityBarAvatar, LiveAgentActivityBarContent, LiveAgentActivityBarRow, LiveAgentActivityBarStatus, LiveAgentActivityBarText.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftLiveAgentActivityBarRecipe {
  static const String recipeName = 'liveAgentActivityBar';
  static const List<String> slotNames = [
    'root',
    'row',
    'avatar',
    'content',
    'status',
    'text',
  ];
  static const List<RaftRecipeAxis> axes = [];

  static RaftLiveAgentActivityBarRecipeStyle resolve({
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftLiveAgentActivityBarRecipeStyle(
      root: s[0],
      row: s[1],
      avatar: s[2],
      content: s[3],
      status: s[4],
      text: s[5],
    );
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
    [1736, 1705, 620, 633, 596, 1656, 1667, 1734],
    [965, 1476, 1318, 1022, 125],
    [1736, 1579, 1758],
    [965, 1481, 966, 1318, 1021],
    [472, 369],
    [1481, 1893, 1015, 1817, 1016, 1818],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5],
  ];
}
