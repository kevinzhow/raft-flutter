// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `kbdShortcut`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `size` axis of `kbdShortcut` (default `sm`).
enum RaftKbdShortcutRecipeSize {
  sm('sm'),
  md('md');

  const RaftKbdShortcutRecipeSize(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftKbdShortcutRecipe].
class RaftKbdShortcutRecipeStyle {
  const RaftKbdShortcutRecipeStyle({
    required this.root,
    required this.cap,
    required this.text,
    required this.icon,
    required this.label,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `cap`.
  final RaftSlotStyle cap;

  /// Slot `text`.
  final RaftSlotStyle text;

  /// Slot `icon`.
  final RaftSlotStyle icon;

  /// Slot `label`.
  final RaftSlotStyle label;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'cap': cap,
    'text': text,
    'icon': icon,
    'label': label,
  };
}

/// raft-ui recipe `kbdShortcut` (`dist/components/kbd/kbd-shortcut.mjs`, index.mjs:28091).
///
/// Used by: KbdShortcut.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftKbdShortcutRecipe {
  static const String recipeName = 'kbdShortcut';
  static const List<String> slotNames = [
    'root',
    'cap',
    'text',
    'icon',
    'label',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('size', ['sm', 'md'], 'sm', false),
  ];

  static RaftKbdShortcutRecipeStyle resolve({
    RaftKbdShortcutRecipeSize? size,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [size?.css],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftKbdShortcutRecipeStyle(
      root: s[0],
      cap: s[1],
      text: s[2],
      icon: s[3],
      label: s[4],
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
    [1847, 2499, 1864],
    [1028, 1654],
    [937, 1892, 690],
    [937, 2499],
    [2539],
    [1028],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4],
    [0, 5, 2, 3, 4],
  ];
}
