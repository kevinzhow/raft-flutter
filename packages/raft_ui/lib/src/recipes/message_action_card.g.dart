// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `messageActionCard`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftMessageActionCardRecipe].
class RaftMessageActionCardRecipeStyle {
  const RaftMessageActionCardRecipeStyle({required this.root, required this.header, required this.headerStatus});

  /// Slot `root`.
  final RaftSlotStyle root;
  /// Slot `header`.
  final RaftSlotStyle header;
  /// Slot `headerStatus`.
  final RaftSlotStyle headerStatus;

  Map<String, RaftSlotStyle> get slots => {'root': root, 'header': header, 'headerStatus': headerStatus};
}

/// raft-ui recipe `messageActionCard` (`src/components/message-action-card/message-action-card.recipe.ts`, index.mjs:10678).
///
/// Used by: MessageActionCard, MessageActionCardHeader, MessageActionCardHeaderStatus.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftMessageActionCardRecipe {
  static const String recipeName = 'messageActionCard';
  static const List<String> slotNames = ['root', 'header', 'headerStatus'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftMessageActionCardRecipeStyle resolve({required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name], states, tokens);
    return RaftMessageActionCardRecipeStyle(root: s[0], header: s[1], headerStatus: s[2]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [2598, 3127],
    [1620, 1626, 2312, 1698, 874, 3017, 1684],
    [2585],
    [1620, 1626, 2312, 1698, 2765, 2924, 1682],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2], [0, 3, 2],
  ];
}
