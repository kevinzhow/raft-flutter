// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `appLinkCard`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftAppLinkCardRecipe].
class RaftAppLinkCardRecipeStyle {
  const RaftAppLinkCardRecipeStyle({
    required this.root,
    required this.placeholderLine,
    required this.placeholderButton,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `placeholderLine`.
  final RaftSlotStyle placeholderLine;

  /// Slot `placeholderButton`.
  final RaftSlotStyle placeholderButton;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'placeholderLine': placeholderLine,
    'placeholderButton': placeholderButton,
  };
}

/// raft-ui recipe `appLinkCard` (`dist/components/app-link-card/app-link-card.mjs`, index.mjs:26243).
///
/// Used by: AppLinkCard, AppLinkCardPlaceholder.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftAppLinkCardRecipe {
  static const String recipeName = 'appLinkCard';
  static const List<String> slotNames = [
    'root',
    'placeholderLine',
    'placeholderButton',
  ];
  static const List<RaftRecipeAxis> axes = [];

  static RaftAppLinkCardRecipeStyle resolve({
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
    return RaftAppLinkCardRecipeStyle(
      root: s[0],
      placeholderLine: s[1],
      placeholderButton: s[2],
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
    [1400, 1404, 2159, 1392, 1876],
    [1400, 1679, 1864],
    [1661, 2042, 2700, 2463],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2],
  ];
}
