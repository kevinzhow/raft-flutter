// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `messageFooter`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `badgeStatus` axis of `messageFooter`.
enum RaftMessageFooterRecipeBadgeStatus {
  read('read'),
  unread('unread');

  const RaftMessageFooterRecipeBadgeStatus(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftMessageFooterRecipe].
class RaftMessageFooterRecipeStyle {
  const RaftMessageFooterRecipeStyle({
    required this.savedIndicator,
    required this.readReceipt,
    required this.badge,
    required this.badgeSeparator,
  });

  /// Slot `savedIndicator`.
  final RaftSlotStyle savedIndicator;

  /// Slot `readReceipt`.
  final RaftSlotStyle readReceipt;

  /// Slot `badge`.
  final RaftSlotStyle badge;

  /// Slot `badgeSeparator`.
  final RaftSlotStyle badgeSeparator;

  Map<String, RaftSlotStyle> get slots => {
    'savedIndicator': savedIndicator,
    'readReceipt': readReceipt,
    'badge': badge,
    'badgeSeparator': badgeSeparator,
  };
}

/// raft-ui recipe `messageFooter` (`dist/components/message-item/message-footer.recipe.mjs`, index.mjs:12397).
///
/// Used by: MessageItemBadge, MessageItemBadgeSeparator, MessageItemReadReceipt, MessageItemSavedIndicator.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftMessageFooterRecipe {
  static const String recipeName = 'messageFooter';
  static const List<String> slotNames = [
    'savedIndicator',
    'readReceipt',
    'badge',
    'badgeSeparator',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('badgeStatus', ['read', 'unread'], null, true),
    RaftRecipeAxis('iconOnly', ['true', 'false'], 'false', false),
  ];

  static RaftMessageFooterRecipeStyle resolve({
    RaftMessageFooterRecipeBadgeStatus? badgeStatus,
    bool? iconOnly,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [badgeStatus?.css, iconOnly?.toString()],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftMessageFooterRecipeStyle(
      savedIndicator: s[0],
      readReceipt: s[1],
      badge: s[2],
      badgeSeparator: s[3],
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
      1847,
      2116,
      1980,
      1864,
      1464,
      2252,
      2729,
      2483,
      474,
      2597,
      1449,
      2603,
      1794,
      699,
      2247,
      1439,
      1869,
      2260,
      2522,
      2463,
      933,
      488,
      492,
    ],
    [2132, 1847, 2499, 1864, 1464, 2729, 474, 1666, 1454, 2616, 2600, 476],
    [
      1847,
      2116,
      1980,
      1864,
      2252,
      2729,
      2483,
      2675,
      474,
      1658,
      1464,
      2461,
      940,
      2401,
      2497,
      2597,
      1449,
      2603,
      895,
      1794,
      699,
      477,
    ],
    [2608],
    [
      1847,
      2116,
      1980,
      1864,
      1464,
      2252,
      2729,
      2483,
      474,
      1658,
      2461,
      2362,
      2305,
      2597,
      1449,
      2603,
      895,
      1794,
      699,
      2247,
      1439,
      477,
      491,
    ],
    [
      1847,
      2116,
      1980,
      1864,
      2252,
      2729,
      2483,
      2675,
      474,
      1658,
      1464,
      2461,
      940,
      2401,
      2497,
      2597,
      1449,
      895,
      1794,
      699,
      477,
      2598,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3],
    [4, 1, 2, 3],
    [0, 1, 2, 3],
    [4, 1, 2, 3],
    [0, 1, 5, 3],
    [4, 1, 5, 3],
  ];
}
