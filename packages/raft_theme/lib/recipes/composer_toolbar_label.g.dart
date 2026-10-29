// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `composerToolbarLabel`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftComposerToolbarLabelRecipe].
class RaftComposerToolbarLabelRecipeStyle {
  const RaftComposerToolbarLabelRecipeStyle({required this.root});

  /// Slot `root`.
  final RaftSlotStyle root;

  Map<String, RaftSlotStyle> get slots => {'root': root};
}

/// raft-ui recipe `composerToolbarLabel` (`src/components/composer/composer-toolbar-label.tsx`, index.mjs:11989).
///
/// Used by: ComposerToolbarLabel.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftComposerToolbarLabelRecipe {
  static const String recipeName = 'composerToolbarLabel';
  static const List<String> slotNames = ['root'];
  static const List<RaftRecipeAxis> axes = [];

  static RaftComposerToolbarLabelRecipeStyle resolve({
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
    return RaftComposerToolbarLabelRecipeStyle(root: s[0]);
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
    [1305, 664, 1727, 1319, 1479, 1023, 1016, 1813, 1017, 1822, 1259, 1260],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0],
  ];
}
