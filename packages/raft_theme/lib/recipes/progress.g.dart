// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `progress`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `variant` axis of `progress` (default `primary`).
enum RaftProgressRecipeVariant {
  primary('primary'),
  information('information'),
  accent('accent'),
  success('success'),
  warning('warning'),
  danger('danger');

  const RaftProgressRecipeVariant(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// `size` axis of `progress` (default `md`).
enum RaftProgressRecipeSize {
  sm('sm'),
  md('md'),
  lg('lg');

  const RaftProgressRecipeSize(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftProgressRecipe].
class RaftProgressRecipeStyle {
  const RaftProgressRecipeStyle({
    required this.root,
    required this.header,
    required this.label,
    required this.value,
    required this.track,
    required this.indicator,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `header`.
  final RaftSlotStyle header;

  /// Slot `label`.
  final RaftSlotStyle label;

  /// Slot `value`.
  final RaftSlotStyle value;

  /// Slot `track`.
  final RaftSlotStyle track;

  /// Slot `indicator`.
  final RaftSlotStyle indicator;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'header': header,
    'label': label,
    'value': value,
    'track': track,
    'indicator': indicator,
  };
}

/// raft-ui recipe `progress` (`src/components/progress/progress.tsx`, index.mjs:9612).
///
/// Used by: ComposerAttachmentUploadProgressBar, Progress, ProgressHeader, ProgressIndicator, ProgressLabel, ProgressTrack, ProgressValue, ToastProgress, toast.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftProgressRecipe {
  static const String recipeName = 'progress';
  static const List<String> slotNames = [
    'root',
    'header',
    'label',
    'value',
    'track',
    'indicator',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis(
      'variant',
      ['primary', 'information', 'accent', 'success', 'warning', 'danger'],
      'primary',
      false,
    ),
    RaftRecipeAxis('size', ['sm', 'md', 'lg'], 'md', false),
  ];

  static RaftProgressRecipeStyle resolve({
    RaftProgressRecipeVariant? variant,
    RaftProgressRecipeSize? size,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [variant?.css, size?.css],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftProgressRecipeStyle(
      root: s[0],
      header: s[1],
      label: s[2],
      value: s[3],
      track: s[4],
      indicator: s[5],
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
    [1155, 1040, 1926, 1483, 1022, 347, 353, 1016, 823, 343, 349],
    [965, 1483, 1319, 1323, 1025],
    [1483, 1895, 1819, 1017, 1820],
    [1738, 1781, 1014, 1837, 1822],
    [1680, 1926, 1581, 567, 1178, 1091, 1081, 1714],
    [618, 1198, 566, 1889, 943, 950, 863, 697, 867, 865, 864, 1704, 1310, 1313],
    [1155, 1040, 1926, 1483, 1022, 347, 353, 1016, 823, 344, 350],
    [1155, 1040, 1926, 1483, 1022, 347, 353, 1016, 823, 345, 351],
    [1155, 1040, 1926, 1483, 1022, 347, 353, 1016, 823, 342, 348],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5],
    [0, 1, 2, 3, 4, 5],
    [0, 1, 2, 3, 4, 5],
    [0, 1, 2, 3, 4, 5],
    [0, 1, 2, 3, 4, 5],
    [0, 1, 2, 3, 4, 5],
    [0, 1, 2, 3, 4, 5],
    [0, 1, 2, 3, 4, 5],
    [0, 1, 2, 3, 4, 5],
    [6, 1, 2, 3, 4, 5],
    [6, 1, 2, 3, 4, 5],
    [6, 1, 2, 3, 4, 5],
    [7, 1, 2, 3, 4, 5],
    [7, 1, 2, 3, 4, 5],
    [7, 1, 2, 3, 4, 5],
    [8, 1, 2, 3, 4, 5],
    [8, 1, 2, 3, 4, 5],
    [8, 1, 2, 3, 4, 5],
  ];
}
