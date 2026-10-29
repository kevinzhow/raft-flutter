// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `messageFooter`.
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

/// raft-ui recipe `messageFooter` (`src/components/message-item/message-footer.recipe.ts`, index.mjs:7353).
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
      1305,
      1484,
      1424,
      1319,
      1021,
      1583,
      1933,
      1727,
      277,
      1814,
      1017,
      1827,
      1283,
      429,
      1577,
      996,
      1324,
      1592,
      1757,
      1710,
      615,
      290,
      294,
    ],
    [1499, 1305, 1740, 1319, 1021, 1933, 277, 1191, 1014, 1839, 1824, 278],
    [
      1305,
      1484,
      1424,
      1319,
      1583,
      1933,
      1727,
      1893,
      277,
      1185,
      1021,
      1708,
      621,
      1658,
      1738,
      1821,
      1008,
      1827,
      581,
      1283,
      429,
      279,
    ],
    [1832],
    [
      1305,
      1484,
      1424,
      1319,
      1021,
      1583,
      1933,
      1727,
      277,
      1191,
      1708,
      1657,
      1814,
      1017,
      1827,
      581,
      1283,
      429,
      1577,
      996,
      279,
      293,
    ],
    [
      1305,
      1484,
      1424,
      1319,
      1583,
      1933,
      1727,
      1893,
      277,
      1185,
      1021,
      1708,
      621,
      1658,
      1738,
      1821,
      1008,
      581,
      1283,
      429,
      279,
      1822,
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
