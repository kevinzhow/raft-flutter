// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `messageListJump`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `side` axis of `messageListJump` (default `bottom`).
enum RaftMessageListJumpRecipeSide {
  bottom('bottom'),
  top('top');

  const RaftMessageListJumpRecipeSide(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftMessageListJumpRecipe].
class RaftMessageListJumpRecipeStyle {
  const RaftMessageListJumpRecipeStyle({
    required this.controls,
    required this.group,
    required this.dismiss,
  });

  /// Slot `controls`.
  final RaftSlotStyle controls;

  /// Slot `group`.
  final RaftSlotStyle group;

  /// Slot `dismiss`.
  final RaftSlotStyle dismiss;

  Map<String, RaftSlotStyle> get slots => {
    'controls': controls,
    'group': group,
    'dismiss': dismiss,
  };
}

/// raft-ui recipe `messageListJump` (`dist/components/message-list/message-list.recipe.mjs`, index.mjs:14942).
///
/// Used by: MessageListJumpControls, MessageListJumpPillDismiss, MessageListJumpPillGroup.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftMessageListJumpRecipe {
  static const String recipeName = 'messageListJump';
  static const List<String> slotNames = ['controls', 'group', 'dismiss'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('side', ['bottom', 'top'], 'bottom', false),
  ];

  static RaftMessageListJumpRecipeStyle resolve({
    RaftMessageListJumpRecipeSide? side,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [side?.css],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftMessageListJumpRecipeStyle(
      controls: s[0],
      group: s[1],
      dismiss: s[2],
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
    [
      691,
      1858,
      2744,
      2156,
      1400,
      2724,
      1973,
      1864,
      1869,
      1479,
      1488,
      971,
      1409,
    ],
    [1847, 2499, 1867, 121],
    [2469, 957, 2603, 1798, 460, 720, 749, 741, 2028, 2031, 2030],
    [
      691,
      1858,
      2744,
      2156,
      1400,
      2724,
      1973,
      1408,
      1864,
      1869,
      1479,
      1488,
      2643,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2],
    [3, 1, 2],
  ];
}
