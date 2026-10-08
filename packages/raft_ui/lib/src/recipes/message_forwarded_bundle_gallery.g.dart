// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `messageForwardedBundleGallery`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `count` axis of `messageForwardedBundleGallery`.
enum RaftMessageForwardedBundleGalleryRecipeCount {
  v1('1'),
  v2('2'),
  v3('3');

  const RaftMessageForwardedBundleGalleryRecipeCount(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftMessageForwardedBundleGalleryRecipe].
class RaftMessageForwardedBundleGalleryRecipeStyle {
  const RaftMessageForwardedBundleGalleryRecipeStyle({required this.root, required this.row, required this.tile});

  /// Slot `root`.
  final RaftSlotStyle root;
  /// Slot `row`.
  final RaftSlotStyle row;
  /// Slot `tile`.
  final RaftSlotStyle tile;

  Map<String, RaftSlotStyle> get slots => {'root': root, 'row': row, 'tile': tile};
}

/// raft-ui recipe `messageForwardedBundleGallery` (`src/components/message-forwarded-bundle/message-forwarded-bundle.recipe.ts`, index.mjs:11560).
///
/// Used by: MessageForwardedBundleGallery, MessageForwardedBundleGalleryTile.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftMessageForwardedBundleGalleryRecipe {
  static const String recipeName = 'messageForwardedBundleGallery';
  static const List<String> slotNames = ['root', 'row', 'tile'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('count', ['1', '2', '3'], null, true),
  ];

  static RaftMessageForwardedBundleGalleryRecipeStyle resolve({RaftMessageForwardedBundleGalleryRecipeCount? count, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [count?.css], states, tokens);
    return RaftMessageForwardedBundleGalleryRecipeStyle(root: s[0], row: s[1], tile: s[2]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [2574],
    [1717, 1698],
    [405, 409, 407],
    [1717, 1698, 1718, 675, 2892],
    [1717, 1698, 1719, 675, 2892],
    [1717, 1698, 1719, 674, 2891, 2523],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2], [0, 3, 2], [0, 4, 2], [0, 5, 2],
  ];
}
