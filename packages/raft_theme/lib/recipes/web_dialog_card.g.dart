// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `webDialogCard`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftWebDialogCardRecipe].
class RaftWebDialogCardRecipeStyle {
  const RaftWebDialogCardRecipeStyle({
    required this.root,
    required this.header,
    required this.title,
    required this.close,
    required this.defaultWidth,
    required this.glyph,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `header`.
  final RaftSlotStyle header;

  /// Slot `title`.
  final RaftSlotStyle title;

  /// Slot `close`.
  final RaftSlotStyle close;

  /// Slot `defaultWidth`.
  final RaftSlotStyle defaultWidth;

  /// Slot `glyph`.
  final RaftSlotStyle glyph;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'header': header,
    'title': title,
    'close': close,
    'defaultWidth': defaultWidth,
    'glyph': glyph,
  };
}

/// raft-ui recipe `webDialogCard` (`Web src/components/ui/DialogCard.tsx sha256:bfcbf1e265e4cc3971236e35b4a3734eed11875eb07c348760b7c592da2818a8`, index.mjs:1).
///
/// Used by: DialogCard.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftWebDialogCardRecipe {
  static const String recipeName = 'webDialogCard';
  static const List<String> slotNames = [
    'root',
    'header',
    'title',
    'close',
    'defaultWidth',
    'glyph',
  ];
  static const List<RaftRecipeAxis> axes = [];

  static RaftWebDialogCardRecipeStyle resolve({
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
    return RaftWebDialogCardRecipeStyle(
      root: s[0],
      header: s[1],
      title: s[2],
      close: s[3],
      defaultWidth: s[4],
      glyph: s[5],
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
    [1929, 1598],
    [1434, 965, 1321, 1323, 1023],
    [1484, 1016, 1833, 1822],
    [100, 97, 1740],
    [1426],
    [1761],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5],
  ];
}
