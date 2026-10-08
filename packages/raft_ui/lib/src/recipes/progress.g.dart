// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
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
  const RaftProgressRecipeStyle({required this.root, required this.header, required this.label, required this.value, required this.track, required this.indicator});

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

  Map<String, RaftSlotStyle> get slots => {'root': root, 'header': header, 'label': label, 'value': value, 'track': track, 'indicator': indicator};
}

/// raft-ui recipe `progress` (`src/components/progress/progress.tsx`, index.mjs:11943).
///
/// Used by: ComposerAttachmentUploadProgressBar, Progress, ProgressHeader, ProgressIndicator, ProgressLabel, ProgressTrack, ProgressValue, ToastProgress, toast.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftProgressRecipe {
  static const String recipeName = 'progress';
  static const List<String> slotNames = ['root', 'header', 'label', 'value', 'track', 'indicator'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
    RaftRecipeAxis('variant', ['primary', 'information', 'accent', 'success', 'warning', 'danger'], 'primary', false),
    RaftRecipeAxis('size', ['sm', 'md', 'lg'], 'md', false),
  ];

  static RaftProgressRecipeStyle resolve({required RaftRecipeTheme theme, RaftProgressRecipeVariant? variant, RaftProgressRecipeSize? size, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name, variant?.css, size?.css], states, tokens);
    return RaftProgressRecipeStyle(root: s[0], header: s[1], label: s[2], value: s[3], track: s[4], indicator: s[5]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [1929, 1717, 3127, 2574, 1697, 518, 528, 1687, 513, 522],
    [1620, 2574, 2312, 2316, 1700],
    [2574, 3092, 3032, 1684, 2976],
    [2867, 2911, 1689, 3032, 1684, 2995],
    [2775, 3127, 2656, 1960, 1807, 1784, 866, 900, 825, 2865, 1834],
    [862, 1978, 735, 3082, 1605, 1613, 1486, 1231, 1495, 1491, 1487],
    [1929, 1717, 3127, 2574, 1697, 518, 528, 1687, 512, 521],
    [1929, 1717, 3127, 2574, 1697, 518, 528, 1687, 510, 519],
    [1929, 1717, 3127, 2574, 1697, 518, 528, 1687, 514, 523],
    [1929, 1717, 3127, 2574, 1697, 518, 528, 1687, 515, 524],
    [1929, 1717, 3127, 2574, 1697, 518, 528, 1687, 511, 520],
    [1929, 1717, 3127, 2574, 1697, 1691, 517, 527, 1485, 954, 526, 955, 956, 1048, 513, 522],
    [2574, 3092, 2924, 1688, 2335, 2987],
    [2867, 2911, 1689, 2920, 1688, 2335, 2984],
    [2775, 3127, 2656, 736, 1956, 1806, 1783, 2815, 1141, 1129],
    [862, 1978, 735, 3082, 1605, 1613, 1486, 1231, 1491, 2815, 1496, 1489, 1488, 1050, 1139],
    [1929, 1717, 3127, 2574, 1697, 1691, 517, 527, 1485, 954, 526, 955, 956, 1048, 512, 521],
    [1929, 1717, 3127, 2574, 1697, 1691, 517, 527, 1485, 954, 526, 955, 956, 1048, 510, 519],
    [1929, 1717, 3127, 2574, 1697, 1691, 517, 527, 1485, 954, 526, 955, 956, 1048, 514, 523],
    [1929, 1717, 3127, 2574, 1697, 1691, 517, 527, 1485, 954, 526, 955, 956, 1048, 515, 524],
    [1929, 1717, 3127, 2574, 1697, 1691, 517, 527, 1485, 954, 526, 955, 956, 1048, 511, 520],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5], [0, 1, 2, 3, 4, 5], [0, 1, 2, 3, 4, 5], [6, 1, 2, 3, 4, 5], [6, 1, 2, 3, 4, 5], [6, 1, 2, 3, 4, 5], [7, 1, 2, 3, 4, 5], [7, 1, 2, 3, 4, 5], [7, 1, 2, 3, 4, 5], [8, 1, 2, 3, 4, 5], [8, 1, 2, 3, 4, 5], [8, 1, 2, 3, 4, 5], [9, 1, 2, 3, 4, 5], [9, 1, 2, 3, 4, 5], [9, 1, 2, 3, 4, 5], [10, 1, 2, 3, 4, 5],
    [10, 1, 2, 3, 4, 5], [10, 1, 2, 3, 4, 5], [11, 1, 12, 13, 14, 15], [11, 1, 12, 13, 14, 15], [11, 1, 12, 13, 14, 15], [16, 1, 12, 13, 14, 15], [16, 1, 12, 13, 14, 15], [16, 1, 12, 13, 14, 15], [17, 1, 12, 13, 14, 15], [17, 1, 12, 13, 14, 15], [17, 1, 12, 13, 14, 15], [18, 1, 12, 13, 14, 15], [18, 1, 12, 13, 14, 15], [18, 1, 12, 13, 14, 15], [19, 1, 12, 13, 14, 15], [19, 1, 12, 13, 14, 15],
    [19, 1, 12, 13, 14, 15], [20, 1, 12, 13, 14, 15], [20, 1, 12, 13, 14, 15], [20, 1, 12, 13, 14, 15],
  ];
}
