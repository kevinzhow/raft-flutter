// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `liveAgentActivityBar`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftLiveAgentActivityBarRecipe].
class RaftLiveAgentActivityBarRecipeStyle {
  const RaftLiveAgentActivityBarRecipeStyle({required this.root, required this.row, required this.avatar, required this.content, required this.status, required this.text});

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

  Map<String, RaftSlotStyle> get slots => {'root': root, 'row': row, 'avatar': avatar, 'content': content, 'status': status, 'text': text};
}

/// raft-ui recipe `liveAgentActivityBar` (`src/components/live-agent-activity-bar/live-agent-activity-bar.tsx`, index.mjs:17637).
///
/// Used by: LiveAgentActivityBar, LiveAgentActivityBarAvatar, LiveAgentActivityBarContent, LiveAgentActivityBarRow, LiveAgentActivityBarStatus, LiveAgentActivityBarText.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftLiveAgentActivityBarRecipe {
  static const String recipeName = 'liveAgentActivityBar';
  static const List<String> slotNames = ['root', 'row', 'avatar', 'content', 'status', 'text'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftLiveAgentActivityBarRecipeStyle resolve({required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name], states, tokens);
    return RaftLiveAgentActivityBarRecipeStyle(root: s[0], row: s[1], avatar: s[2], content: s[3], status: s[4], text: s[5]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [2867, 2765, 913, 876, 856, 2755, 2511],
    [1620, 2567, 2312, 1698],
    [2886, 2867, 2656],
    [1620, 2574, 1621, 2312, 1697],
    [876],
    [2574, 3092, 3017, 1689, 2963],
    [2867, 2753, 2765, 2817, 864, 896, 825, 2862, 1009],
    [2574, 1621, 2312, 1697, 938],
    [2636],
    [2574, 3092, 1621, 1691, 2924, 1690, 2981],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5], [6, 1, 2, 7, 8, 9],
  ];
}
