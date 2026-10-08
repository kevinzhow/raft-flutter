// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `label`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
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
  const RaftLabelRecipeStyle({required this.root, required this.asterisk, required this.sub});

  /// Slot `root`.
  final RaftSlotStyle root;
  /// Slot `asterisk`.
  final RaftSlotStyle asterisk;
  /// Slot `sub`.
  final RaftSlotStyle sub;

  Map<String, RaftSlotStyle> get slots => {'root': root, 'asterisk': asterisk, 'sub': sub};
}

/// raft-ui recipe `label` (`src/components/label/label.tsx`, index.mjs:6194).
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

  static RaftLabelRecipeStyle resolve({required RaftRecipeTheme theme, RaftLabelRecipeSize? size, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name, size?.css], states, tokens);
    return RaftLabelRecipeStyle(root: s[0], asterisk: s[1], sub: s[2]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [1924, 2301, 3126, 2312, 1696, 942, 2834, 1442, 1452, 1684, 2976, 3032],
    [2950, 1839],
    [2612, 1839, 1684, 3055, 2990],
    [1924, 2301, 3126, 2312, 1696, 942, 2834, 1442, 1452, 1684, 2976, 3017],
    [1924, 2301, 3126, 2312, 1696, 942, 2834, 1442, 1452, 1688, 2987, 1164, 3032],
    [1690, 2612, 1839, 2990],
    [1924, 2301, 3126, 2312, 1696, 942, 2834, 1442, 1452, 1688, 2987, 1164, 3017],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2], [3, 1, 2], [4, 1, 5], [6, 1, 5],
  ];
}
