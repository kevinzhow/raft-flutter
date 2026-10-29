// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `progress`.
// ignore_for_file: type=lint

import '../recipe_runtime.dart';
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

/// raft-ui recipe `progress` (`src/components/progress/progress.tsx`, index.mjs:11986).
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
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
    RaftRecipeAxis(
      'variant',
      ['primary', 'information', 'accent', 'success', 'warning', 'danger'],
      'primary',
      false,
    ),
    RaftRecipeAxis('size', ['sm', 'md', 'lg'], 'md', false),
  ];

  static RaftProgressRecipeStyle resolve({
    required RaftRecipeTheme theme,
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
      [theme.name, variant?.css, size?.css],
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
    [1930, 1742, 3168, 2597, 1722, 519, 529, 1712, 514, 523],
    [1644, 2597, 2331, 2335, 1725],
    [2597, 3133, 3073, 1709, 3013],
    [2902, 2946, 1714, 3073, 1709, 3032],
    [2804, 3168, 2679, 1962, 1832, 1809, 878, 916, 830, 2899, 1859],
    [874, 1980, 741, 3123, 1629, 1637, 1510, 1253, 1519, 1515, 1511],
    [1930, 1742, 3168, 2597, 1722, 519, 529, 1712, 513, 522],
    [1930, 1742, 3168, 2597, 1722, 519, 529, 1712, 511, 520],
    [1930, 1742, 3168, 2597, 1722, 519, 529, 1712, 515, 524],
    [1930, 1742, 3168, 2597, 1722, 519, 529, 1712, 516, 525],
    [1930, 1742, 3168, 2597, 1722, 519, 529, 1712, 512, 521],
    [
      1930,
      1742,
      3168,
      2597,
      1722,
      1716,
      518,
      528,
      1509,
      974,
      527,
      975,
      976,
      1068,
      514,
      523,
    ],
    [2597, 3133, 2962, 1713, 2354, 3024],
    [2902, 2946, 1714, 2958, 1713, 2354, 3021],
    [2804, 3168, 2679, 742, 1958, 1831, 1808, 2845, 1160, 1148],
    [
      874,
      1980,
      741,
      3123,
      1629,
      1637,
      1510,
      1253,
      1515,
      2845,
      1520,
      1513,
      1512,
      1070,
      1158,
    ],
    [
      1930,
      1742,
      3168,
      2597,
      1722,
      1716,
      518,
      528,
      1509,
      974,
      527,
      975,
      976,
      1068,
      513,
      522,
    ],
    [
      1930,
      1742,
      3168,
      2597,
      1722,
      1716,
      518,
      528,
      1509,
      974,
      527,
      975,
      976,
      1068,
      511,
      520,
    ],
    [
      1930,
      1742,
      3168,
      2597,
      1722,
      1716,
      518,
      528,
      1509,
      974,
      527,
      975,
      976,
      1068,
      515,
      524,
    ],
    [
      1930,
      1742,
      3168,
      2597,
      1722,
      1716,
      518,
      528,
      1509,
      974,
      527,
      975,
      976,
      1068,
      516,
      525,
    ],
    [
      1930,
      1742,
      3168,
      2597,
      1722,
      1716,
      518,
      528,
      1509,
      974,
      527,
      975,
      976,
      1068,
      512,
      521,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
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
    [9, 1, 2, 3, 4, 5],
    [9, 1, 2, 3, 4, 5],
    [9, 1, 2, 3, 4, 5],
    [10, 1, 2, 3, 4, 5],
    [10, 1, 2, 3, 4, 5],
    [10, 1, 2, 3, 4, 5],
    [11, 1, 12, 13, 14, 15],
    [11, 1, 12, 13, 14, 15],
    [11, 1, 12, 13, 14, 15],
    [16, 1, 12, 13, 14, 15],
    [16, 1, 12, 13, 14, 15],
    [16, 1, 12, 13, 14, 15],
    [17, 1, 12, 13, 14, 15],
    [17, 1, 12, 13, 14, 15],
    [17, 1, 12, 13, 14, 15],
    [18, 1, 12, 13, 14, 15],
    [18, 1, 12, 13, 14, 15],
    [18, 1, 12, 13, 14, 15],
    [19, 1, 12, 13, 14, 15],
    [19, 1, 12, 13, 14, 15],
    [19, 1, 12, 13, 14, 15],
    [20, 1, 12, 13, 14, 15],
    [20, 1, 12, 13, 14, 15],
    [20, 1, 12, 13, 14, 15],
  ];
}
