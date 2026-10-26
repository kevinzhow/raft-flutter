// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
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

/// raft-ui recipe `label` (`src/components/label/label.tsx`, index.mjs:4981).
///
/// Used by: AppShellSidebarTrigger, ComboboxLabel, ContextMenuLabel, DropdownMenuLabel, FieldLabel, Label, LabelAsterisk, LabelSub, ProgressLabel, SearchTriggerLabel, SegmentedControlLabel, SelectLabel, SidebarItemThreadCount, SortableComposerAttachment, TabsLabel, ToggleGroupLabel.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftLabelRecipe {
  static const String recipeName = 'label';
  static const List<String> slotNames = ['root', 'asterisk', 'sub'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('size', ['sm', 'md'], 'md', false),
  ];

  static RaftLabelRecipeStyle resolve({
    RaftLabelRecipeSize? size,
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
    [1147, 1304, 1923, 1318, 1020, 664, 1723, 831, 836, 1015, 1823, 1810, 1016],
    [1114, 1820],
    [1525, 1114, 1014, 1869, 1820],
    [1147, 1304, 1923, 1318, 1020, 664, 1723, 831, 836, 1015, 1823, 1817, 1016],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2],
    [3, 1, 2],
  ];
}
