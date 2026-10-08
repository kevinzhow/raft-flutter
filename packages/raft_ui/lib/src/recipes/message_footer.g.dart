// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
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

/// `elevation` axis of `messageFooter` (default `none`).
enum RaftMessageFooterRecipeElevation {
  none('none'),
  xs('xs'),
  sm('sm');

  const RaftMessageFooterRecipeElevation(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftMessageFooterRecipe].
class RaftMessageFooterRecipeStyle {
  const RaftMessageFooterRecipeStyle({required this.savedIndicator, required this.readReceipt, required this.badge, required this.badgeSeparator});

  /// Slot `savedIndicator`.
  final RaftSlotStyle savedIndicator;
  /// Slot `readReceipt`.
  final RaftSlotStyle readReceipt;
  /// Slot `badge`.
  final RaftSlotStyle badge;
  /// Slot `badgeSeparator`.
  final RaftSlotStyle badgeSeparator;

  Map<String, RaftSlotStyle> get slots => {'savedIndicator': savedIndicator, 'readReceipt': readReceipt, 'badge': badge, 'badgeSeparator': badgeSeparator};
}

/// raft-ui recipe `messageFooter` (`src/components/message-item/message-footer.recipe.ts`, index.mjs:9330).
///
/// Used by: MessageItemBadge, MessageItemBadgeSeparator, MessageItemReadReceipt, MessageItemSavedIndicator.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftMessageFooterRecipe {
  static const String recipeName = 'messageFooter';
  static const List<String> slotNames = ['savedIndicator', 'readReceipt', 'badge', 'badgeSeparator'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('badgeStatus', ['read', 'unread'], null, true),
    RaftRecipeAxis('elevation', ['none', 'xs', 'sm'], 'none', false),
    RaftRecipeAxis('iconOnly', ['true', 'false'], 'false', false),
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftMessageFooterRecipeStyle resolve({RaftMessageFooterRecipeBadgeStatus? badgeStatus, RaftMessageFooterRecipeElevation? elevation, bool? iconOnly, required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [badgeStatus?.css, elevation?.css, iconOnly?.toString(), theme.name], states, tokens);
    return RaftMessageFooterRecipeStyle(savedIndicator: s[0], readReceipt: s[1], badge: s[2], badgeSeparator: s[3]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [2301, 2574, 2484, 2312, 1696, 2656, 3131, 2834, 427, 2884, 2317, 2667, 1961, 2750, 2918, 1684, 2344, 856, 2956, 1601, 2252, 1639, 1646, 1642, 449, 866, 876, 2863, 3083, 2176, 2268, 608, 605, 430],
    [2585, 2301, 2867, 2312, 1696, 3131, 427, 1961, 2918, 1684, 2344, 2960, 428],
    [2301, 2574, 2484, 2312, 1696, 2656, 3131, 2834, 3084, 427, 1961, 864, 900, 2750, 2918, 1684, 2344, 2956, 2197, 429],
    [2991],
    [2301, 2574, 2484, 2312, 2656, 3131, 2834, 427, 2884, 2317, 2667, 1961, 1697, 839, 2750, 2761, 2920, 1688, 2331, 3050, 3006, 1172, 3075, 1601, 2253, 1654, 1667, 2818, 431],
    [2585, 2301, 2867, 2312, 1696, 3131, 427, 1961, 2920, 1688, 2981, 428],
    [2301, 2574, 2484, 2312, 1696, 2656, 3131, 2834, 3084, 427, 1961, 2818, 2750, 2922, 1680, 3047, 2214, 438],
    [2301, 2574, 2484, 2312, 1696, 2656, 3131, 2834, 427, 1961, 864, 900, 2750, 2918, 1684, 2344, 856, 2956, 3076, 1601, 2252, 1639, 1646, 1642, 428, 449],
    [2301, 2574, 2484, 2312, 2656, 3131, 2834, 427, 1961, 1697, 2815, 839, 2750, 2761, 2920, 1688, 2331, 3050, 3006, 1172, 3075, 1601, 2253, 1654, 1667, 438],
    [2301, 2574, 2484, 2312, 2656, 3131, 2834, 427, 2865, 2884, 2317, 2667, 1961, 1697, 839, 2750, 2761, 2920, 1688, 2331, 3050, 3006, 1172, 3075, 1601, 2253, 1654, 1667, 2818, 431],
    [2301, 2574, 2484, 2312, 1696, 2656, 3131, 2834, 427, 2865, 1961, 864, 900, 2750, 2918, 1684, 2344, 856, 2956, 3076, 1601, 2252, 1639, 1646, 1642, 428, 449],
    [2301, 2574, 2484, 2312, 2656, 3131, 2834, 427, 2865, 1961, 1697, 2815, 839, 2750, 2761, 2920, 1688, 2331, 3050, 3006, 1172, 3075, 1601, 2253, 1654, 1667, 438],
    [2301, 2574, 2484, 2312, 2656, 3131, 2834, 427, 2863, 2884, 2317, 2667, 1961, 1697, 839, 2750, 2761, 2920, 1688, 2331, 3050, 3006, 1172, 3075, 1601, 2253, 1654, 1667, 2818, 431],
    [2301, 2574, 2484, 2312, 1696, 2656, 3131, 2834, 427, 2863, 1961, 864, 900, 2750, 2918, 1684, 2344, 856, 2956, 3076, 1601, 2252, 1639, 1646, 1642, 428, 449],
    [2301, 2574, 2484, 2312, 2656, 3131, 2834, 427, 2863, 1961, 1697, 2815, 839, 2750, 2761, 2920, 1688, 2331, 3050, 3006, 1172, 3075, 1601, 2253, 1654, 1667, 438],
    [2301, 2574, 2484, 2312, 1696, 2656, 3131, 2834, 3084, 427, 1961, 864, 900, 2750, 2918, 1684, 2344, 2956, 2197, 429, 856],
    [2301, 2574, 2484, 2312, 1696, 2656, 3131, 2834, 3084, 427, 1961, 2818, 2750, 2922, 1680, 3047, 2214, 438, 2981],
    [2301, 2574, 2484, 2312, 1696, 2656, 3131, 2834, 3084, 427, 1961, 864, 900, 2750, 2918, 1684, 2344, 2956, 2197, 429, 773],
    [2301, 2574, 2484, 2312, 1696, 2656, 3131, 2834, 3084, 427, 1961, 2818, 2750, 1680, 2214, 438, 813, 2922, 3047],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3], [4, 5, 6, 3], [7, 1, 2, 3], [8, 5, 6, 3], [0, 1, 2, 3], [9, 5, 6, 3], [10, 1, 2, 3], [11, 5, 6, 3], [0, 1, 2, 3], [12, 5, 6, 3], [13, 1, 2, 3], [14, 5, 6, 3], [0, 1, 15, 3], [4, 5, 16, 3], [7, 1, 15, 3], [8, 5, 16, 3],
    [0, 1, 15, 3], [9, 5, 16, 3], [10, 1, 15, 3], [11, 5, 16, 3], [0, 1, 15, 3], [12, 5, 16, 3], [13, 1, 15, 3], [14, 5, 16, 3], [0, 1, 17, 3], [4, 5, 18, 3], [7, 1, 17, 3], [8, 5, 18, 3], [0, 1, 17, 3], [9, 5, 18, 3], [10, 1, 17, 3], [11, 5, 18, 3],
    [0, 1, 17, 3], [12, 5, 18, 3], [13, 1, 17, 3], [14, 5, 18, 3],
  ];
}
