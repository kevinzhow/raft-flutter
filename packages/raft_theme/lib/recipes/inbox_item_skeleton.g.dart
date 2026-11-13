// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `inboxItemSkeleton`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftInboxItemSkeletonRecipe].
class RaftInboxItemSkeletonRecipeStyle {
  const RaftInboxItemSkeletonRecipeStyle({
    required this.list,
    required this.row,
    required this.leading,
    required this.line,
    required this.title,
    required this.bar,
    required this.contextBar,
    required this.titleBar,
    required this.bodyBar,
    required this.timestampBar,
  });

  /// Slot `list`.
  final RaftSlotStyle list;

  /// Slot `row`.
  final RaftSlotStyle row;

  /// Slot `leading`.
  final RaftSlotStyle leading;

  /// Slot `line`.
  final RaftSlotStyle line;

  /// Slot `title`.
  final RaftSlotStyle title;

  /// Slot `bar`.
  final RaftSlotStyle bar;

  /// Slot `contextBar`.
  final RaftSlotStyle contextBar;

  /// Slot `titleBar`.
  final RaftSlotStyle titleBar;

  /// Slot `bodyBar`.
  final RaftSlotStyle bodyBar;

  /// Slot `timestampBar`.
  final RaftSlotStyle timestampBar;

  Map<String, RaftSlotStyle> get slots => {
    'list': list,
    'row': row,
    'leading': leading,
    'line': line,
    'title': title,
    'bar': bar,
    'contextBar': contextBar,
    'titleBar': titleBar,
    'bodyBar': bodyBar,
    'timestampBar': timestampBar,
  };
}

/// raft-ui recipe `inboxItemSkeleton` (`dist/components/inbox-item/inbox-item-skeleton.recipe.mjs`, index.mjs:25769).
///
/// Used by: InboxItemSkeleton, InboxItemSkeletonList.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftInboxItemSkeletonRecipe {
  static const String recipeName = 'inboxItemSkeleton';
  static const List<String> slotNames = [
    'list',
    'row',
    'leading',
    'line',
    'title',
    'bar',
    'contextBar',
    'titleBar',
    'bodyBar',
    'timestampBar',
  ];
  static const List<RaftRecipeAxis> axes = [];

  static RaftInboxItemSkeletonRecipeStyle resolve({
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
    return RaftInboxItemSkeletonRecipeStyle(
      list: s[0],
      row: s[1],
      leading: s[2],
      line: s[3],
      title: s[4],
      bar: s[5],
      contextBar: s[6],
      titleBar: s[7],
      bodyBar: s[8],
      timestampBar: s[9],
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
    [1400, 2116, 1404, 1463],
    [550, 551, 549, 2214, 2215, 2213, 2219, 2220, 2218],
    [2529],
    [2116, 1401],
    [2295],
    [1846, 1664, 1980, 761],
    [2687],
    [2688],
    [2686],
    [2710],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
  ];
}
