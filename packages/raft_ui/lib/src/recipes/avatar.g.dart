// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `avatar`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `type` axis of `avatar`.
enum RaftAvatarRecipeType {
  agent('agent'),
  human('human');

  const RaftAvatarRecipeType(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// `size` axis of `avatar`.
enum RaftAvatarRecipeSize {
  xl('xl'),
  lg('lg'),
  md('md'),
  sm('sm'),
  xs('xs'),
  v2xs('2xs'),
  v3xs('3xs');

  const RaftAvatarRecipeSize(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftAvatarRecipe].
class RaftAvatarRecipeStyle {
  const RaftAvatarRecipeStyle({required this.root, required this.image, required this.fallback, required this.badge, required this.dot, required this.group});

  /// Slot `root`.
  final RaftSlotStyle root;
  /// Slot `image`.
  final RaftSlotStyle image;
  /// Slot `fallback`.
  final RaftSlotStyle fallback;
  /// Slot `badge`.
  final RaftSlotStyle badge;
  /// Slot `dot`.
  final RaftSlotStyle dot;
  /// Slot `group`.
  final RaftSlotStyle group;

  Map<String, RaftSlotStyle> get slots => {'root': root, 'image': image, 'fallback': fallback, 'badge': badge, 'dot': dot, 'group': group};
}

/// raft-ui recipe `avatar` (`src/components/avatar/avatar.tsx`, index.mjs:8113).
///
/// Used by: Avatar, AvatarBadge, AvatarFallback, AvatarGroup, AvatarGroupCount, AvatarImage, LiveAgentActivityBarAvatar.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftAvatarRecipe {
  static const String recipeName = 'avatar';
  static const List<String> slotNames = ['root', 'image', 'fallback', 'badge', 'dot', 'group'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
    RaftRecipeAxis('type', ['agent', 'human'], null, true),
    RaftRecipeAxis('size', ['xl', 'lg', 'md', 'sm', 'xs', '2xs', '3xs'], null, true),
  ];

  static RaftAvatarRecipeStyle resolve({required RaftRecipeTheme theme, RaftAvatarRecipeType? type_, RaftAvatarRecipeSize? size, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name, type_?.css, size?.css], states, tokens);
    return RaftAvatarRecipeStyle(root: s[0], image: s[1], fallback: s[2], badge: s[3], dot: s[4], group: s[5]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [1910, 2775, 1620, 2867, 2312, 2317, 2834, 876, 2956],
    [2890, 2623],
    [1620, 2890, 2312, 2317, 305, 1810, 1770, 1787, 1792, 1815, 1754, 1761, 2956],
    [580, 3138, 2876, 2834, 1813, 1773, 1790, 1795, 1819, 1758, 1765, 2780, 924, 3088, 1814, 1774, 1791, 1796, 1797, 1821, 1760, 1767],
    [2301, 2312, 2317, 2815, 2645, 2653, 296, 1809, 1808, 1769, 1768, 1786, 1785, 1817, 1756, 1763, 845, 2976],
    [1911, 1620, 2312, 146, 93, 95, 88, 90],
    [1910, 2775, 1620, 2867, 2312, 2317, 2834, 876, 2956, 2875, 866],
    [1910, 2775, 1620, 2867, 2312, 2317, 2834, 876, 2956, 2873, 866],
    [1910, 2775, 1620, 2867, 2312, 2317, 2834, 876, 2956, 2886, 866],
    [1910, 2775, 1620, 2867, 2312, 2317, 2834, 876, 2956, 2885, 866],
    [1910, 2775, 1620, 2867, 2312, 2317, 2834, 876, 2956, 2882, 864],
    [1910, 2775, 1620, 2867, 2312, 2317, 2834, 876, 2956, 2881, 864],
    [1910, 2775, 1620, 2867, 2312, 2317, 2834, 876, 2956, 2879, 864],
    [1910, 2775, 1620, 2867, 2312, 2317, 2834, 876, 2956, 772],
    [1910, 2775, 1620, 2867, 2312, 2317, 2834, 876, 2956, 2875, 866, 772],
    [1910, 2775, 1620, 2867, 2312, 2317, 2834, 876, 2956, 2873, 866, 772],
    [1910, 2775, 1620, 2867, 2312, 2317, 2834, 876, 2956, 2886, 866, 772],
    [1910, 2775, 1620, 2867, 2312, 2317, 2834, 876, 2956, 2885, 866, 772],
    [1910, 2775, 1620, 2867, 2312, 2317, 2834, 876, 2956, 2882, 864, 772],
    [1910, 2775, 1620, 2867, 2312, 2317, 2834, 876, 2956, 2881, 864, 772],
    [1910, 2775, 1620, 2867, 2312, 2317, 2834, 876, 2956, 2879, 864, 772],
    [1910, 2775, 1620, 2867, 2312, 2317, 2834, 876, 775, 2956],
    [1910, 2775, 1620, 2867, 2312, 2317, 2834, 876, 2875, 866, 775, 2956],
    [1910, 2775, 1620, 2867, 2312, 2317, 2834, 876, 2873, 866, 775, 2956],
    [1910, 2775, 1620, 2867, 2312, 2317, 2834, 876, 2886, 866, 775, 2956],
    [1910, 2775, 1620, 2867, 2312, 2317, 2834, 876, 2885, 866, 775, 2956],
    [1910, 2775, 1620, 2867, 2312, 2317, 2834, 876, 2882, 864, 775, 2956],
    [1910, 2775, 1620, 2867, 2312, 2317, 2834, 876, 2881, 864, 775, 2956],
    [1910, 2775, 1620, 2867, 2312, 2317, 2834, 876, 2879, 864, 775, 2956],
    [1910, 2775, 1620, 2867, 2312, 2317, 2834, 795],
    [2890, 2623, 2815],
    [1620, 2890, 2312, 2317, 305, 1810, 1770, 1787, 1792, 1815, 1754, 1761, 2656, 795, 2985, 3017, 2815, 1820, 1759, 1766],
    [580, 3138, 2876, 2834, 1813, 1773, 1790, 1795, 1819, 1758, 1765, 2645, 2648, 1812, 1811, 1772, 1771, 1789, 1788, 1794, 1793, 1818, 1816, 1757, 1755, 1764, 1762],
    [2301, 2312, 2317, 2815, 2645, 296, 1809, 1808, 1769, 1768, 1786, 1785, 1817, 1756, 1763, 845, 3020, 2648],
    [1911, 1620, 2312, 147, 91, 93, 94, 86, 88, 89],
    [1910, 2775, 1620, 2867, 2312, 2317, 2834, 795, 2875, 866, 916, 789, 2815],
    [1910, 2775, 1620, 2867, 2312, 2317, 2834, 795, 2873, 866, 916, 789, 2815],
    [1910, 2775, 1620, 2867, 2312, 2317, 2834, 795, 2886, 866, 916, 789, 2815],
    [1910, 2775, 1620, 2867, 2312, 2317, 2834, 795, 2885, 866, 916, 789, 2815],
    [1910, 2775, 1620, 2867, 2312, 2317, 2834, 795, 2882, 864, 916, 789, 2815],
    [1910, 2775, 1620, 2867, 2312, 2317, 2834, 795, 2881, 864, 916, 789, 2815],
    [1910, 2775, 1620, 2867, 2312, 2317, 2834, 795, 2879, 864, 916, 789, 2815],
    [1910, 2775, 1620, 2867, 2312, 2317, 2834, 795, 2981],
    [1910, 2775, 1620, 2867, 2312, 2317, 2834, 795, 2875, 866, 916, 789, 2815, 2981],
    [1910, 2775, 1620, 2867, 2312, 2317, 2834, 795, 2873, 866, 916, 789, 2815, 2981],
    [1910, 2775, 1620, 2867, 2312, 2317, 2834, 795, 2886, 866, 916, 789, 2815, 2981],
    [1910, 2775, 1620, 2867, 2312, 2317, 2834, 795, 2885, 866, 916, 789, 2815, 2981],
    [1910, 2775, 1620, 2867, 2312, 2317, 2834, 795, 2882, 864, 916, 789, 2815, 2981],
    [1910, 2775, 1620, 2867, 2312, 2317, 2834, 795, 2881, 864, 916, 789, 2815, 2981],
    [1910, 2775, 1620, 2867, 2312, 2317, 2834, 795, 2879, 864, 916, 789, 2815, 2981],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5], [6, 1, 2, 3, 4, 5], [7, 1, 2, 3, 4, 5], [8, 1, 2, 3, 4, 5], [9, 1, 2, 3, 4, 5], [10, 1, 2, 3, 4, 5], [11, 1, 2, 3, 4, 5], [12, 1, 2, 3, 4, 5], [13, 1, 2, 3, 4, 5], [14, 1, 2, 3, 4, 5], [15, 1, 2, 3, 4, 5], [16, 1, 2, 3, 4, 5], [17, 1, 2, 3, 4, 5], [18, 1, 2, 3, 4, 5], [19, 1, 2, 3, 4, 5], [20, 1, 2, 3, 4, 5],
    [21, 1, 2, 3, 4, 5], [22, 1, 2, 3, 4, 5], [23, 1, 2, 3, 4, 5], [24, 1, 2, 3, 4, 5], [25, 1, 2, 3, 4, 5], [26, 1, 2, 3, 4, 5], [27, 1, 2, 3, 4, 5], [28, 1, 2, 3, 4, 5], [29, 30, 31, 32, 33, 34], [35, 30, 31, 32, 33, 34], [36, 30, 31, 32, 33, 34], [37, 30, 31, 32, 33, 34], [38, 30, 31, 32, 33, 34], [39, 30, 31, 32, 33, 34], [40, 30, 31, 32, 33, 34], [41, 30, 31, 32, 33, 34],
    [42, 30, 31, 32, 33, 34], [43, 30, 31, 32, 33, 34], [44, 30, 31, 32, 33, 34], [45, 30, 31, 32, 33, 34], [46, 30, 31, 32, 33, 34], [47, 30, 31, 32, 33, 34], [48, 30, 31, 32, 33, 34], [49, 30, 31, 32, 33, 34], [42, 30, 31, 32, 33, 34], [43, 30, 31, 32, 33, 34], [44, 30, 31, 32, 33, 34], [45, 30, 31, 32, 33, 34], [46, 30, 31, 32, 33, 34], [47, 30, 31, 32, 33, 34], [48, 30, 31, 32, 33, 34], [49, 30, 31, 32, 33, 34],
  ];
}
