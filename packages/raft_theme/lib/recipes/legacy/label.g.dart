// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `label`.
// ignore_for_file: type=lint

import '../recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `size` axis of `label` (default `md`).
enum RaftLabelRecipeSize {
  sm('sm'),
  md('md');

  const RaftLabelRecipeSize(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftLabelRecipe].
class RaftLabelRecipeStyle {
  const RaftLabelRecipeStyle({
    required this.root,
    required this.asterisk,
    required this.sub,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `asterisk`.
  final RaftSlotStyle asterisk;

  /// Slot `sub`.
  final RaftSlotStyle sub;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'asterisk': asterisk,
    'sub': sub,
  };
}

/// raft-ui recipe `label` (`src/components/label/label.tsx`, index.mjs:6206).
///
/// Used by: AppShellSidebarTrigger, ComboboxLabel, ContextMenuLabel, DropdownMenuLabel, FieldLabel, Label, LabelAsterisk, LabelSub, ProgressLabel, SegmentedControlLabel, SelectLabel, SortableComposerAttachment, TabsLabel, ToggleGroupLabel.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftLabelRecipe {
  static const String recipeName = 'label';
  static const List<String> slotNames = ['root', 'asterisk', 'sub'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
    RaftRecipeAxis('size', ['sm', 'md'], 'md', false),
  ];

  static RaftLabelRecipeStyle resolve({
    required RaftRecipeTheme theme,
    RaftLabelRecipeSize? size,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [theme.name, size?.css],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftLabelRecipeStyle(root: s[0], asterisk: s[1], sub: s[2]);
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
    [1925, 2320, 3167, 2331, 1721, 962, 2868, 1464, 1474, 1709, 3013, 3073],
    [2988, 1864],
    [2634, 1864, 1709, 3096, 3027],
    [1925, 2320, 3167, 2331, 1721, 962, 2868, 1464, 1474, 1709, 3013, 3053],
    [
      1925,
      2320,
      3167,
      2331,
      1721,
      962,
      2868,
      1464,
      1474,
      1713,
      3024,
      1183,
      3073,
    ],
    [1715, 2634, 1864, 3027],
    [
      1925,
      2320,
      3167,
      2331,
      1721,
      962,
      2868,
      1464,
      1474,
      1713,
      3024,
      1183,
      3053,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2],
    [3, 1, 2],
    [4, 1, 5],
    [6, 1, 5],
  ];
}
