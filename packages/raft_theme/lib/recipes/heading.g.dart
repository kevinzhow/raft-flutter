// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `heading`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `level` axis of `heading` (default `1`).
enum RaftHeadingRecipeLevel {
  v1('1'),
  v2('2'),
  v3('3'),
  v4('4'),
  v5('5'),
  v6('6');

  const RaftHeadingRecipeLevel(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// `variant` axis of `heading`.
enum RaftHeadingRecipeVariant {
  default_('default'),
  primary('primary'),
  information('information'),
  muted('muted'),
  placeholder('placeholder'),
  accent('accent'),
  success('success'),
  warning('warning'),
  danger('danger');

  const RaftHeadingRecipeVariant(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftHeadingRecipe].
class RaftHeadingRecipeStyle {
  const RaftHeadingRecipeStyle({required this.base});

  /// Slot `base`.
  final RaftSlotStyle base;

  Map<String, RaftSlotStyle> get slots => {'base': base};
}

/// raft-ui recipe `heading` (`src/components/text/text.tsx`, index.mjs:9984).
///
/// Used by: MarkdownHeading, PanelHeading, TaskBoardColumnHeading, TaskSectionHeading, TextHeading.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftHeadingRecipe {
  static const String recipeName = 'heading';
  static const List<String> slotNames = ['base'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('level', ['1', '2', '3', '4', '5', '6'], '1', false),
    RaftRecipeAxis(
      'variant',
      [
        'default',
        'primary',
        'information',
        'muted',
        'placeholder',
        'accent',
        'success',
        'warning',
        'danger',
      ],
      null,
      true,
    ),
  ];

  static RaftHeadingRecipeStyle resolve({
    RaftHeadingRecipeLevel? level,
    RaftHeadingRecipeVariant? variant,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [level?.css, variant?.css],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftHeadingRecipeStyle(base: s[0]);
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
    [1357, 1012, 1013, 1822, 1805, 1872, 1335],
    [1357, 1012, 1013, 1805, 1872, 1335, 1822],
    [1357, 1012, 1013, 1805, 1872, 1335, 1811],
    [1357, 1012, 1013, 1805, 1872, 1335, 1834],
    [1357, 1012, 1013, 1805, 1872, 1335, 1827],
    [1357, 1012, 1013, 1805, 1872, 1335, 1824],
    [1357, 1012, 1013, 1805, 1872, 1335, 1806],
    [1357, 1012, 1013, 1805, 1872, 1335, 1846],
    [1357, 1012, 1013, 1805, 1872, 1335, 1855],
    [1357, 1012, 1013, 1805, 1872, 1335, 1818],
    [1357, 1012, 1013, 1822, 1791, 1872, 1334],
    [1357, 1012, 1013, 1791, 1872, 1334, 1822],
    [1357, 1012, 1013, 1791, 1872, 1334, 1811],
    [1357, 1012, 1013, 1791, 1872, 1334, 1834],
    [1357, 1012, 1013, 1791, 1872, 1334, 1827],
    [1357, 1012, 1013, 1791, 1872, 1334, 1824],
    [1357, 1012, 1013, 1791, 1872, 1334, 1806],
    [1357, 1012, 1013, 1791, 1872, 1334, 1846],
    [1357, 1012, 1013, 1791, 1872, 1334, 1855],
    [1357, 1012, 1013, 1791, 1872, 1334, 1818],
    [1357, 1012, 1013, 1822, 1803, 1872, 1333],
    [1357, 1012, 1013, 1803, 1872, 1333, 1822],
    [1357, 1012, 1013, 1803, 1872, 1333, 1811],
    [1357, 1012, 1013, 1803, 1872, 1333, 1834],
    [1357, 1012, 1013, 1803, 1872, 1333, 1827],
    [1357, 1012, 1013, 1803, 1872, 1333, 1824],
    [1357, 1012, 1013, 1803, 1872, 1333, 1806],
    [1357, 1012, 1013, 1803, 1872, 1333, 1846],
    [1357, 1012, 1013, 1803, 1872, 1333, 1855],
    [1357, 1012, 1013, 1803, 1872, 1333, 1818],
    [1357, 1012, 1013, 1822, 1802, 1871, 1332],
    [1357, 1012, 1013, 1802, 1871, 1332, 1822],
    [1357, 1012, 1013, 1802, 1871, 1332, 1811],
    [1357, 1012, 1013, 1802, 1871, 1332, 1834],
    [1357, 1012, 1013, 1802, 1871, 1332, 1827],
    [1357, 1012, 1013, 1802, 1871, 1332, 1824],
    [1357, 1012, 1013, 1802, 1871, 1332, 1806],
    [1357, 1012, 1013, 1802, 1871, 1332, 1846],
    [1357, 1012, 1013, 1802, 1871, 1332, 1855],
    [1357, 1012, 1013, 1802, 1871, 1332, 1818],
    [1357, 1012, 1013, 1822, 1790, 1341],
    [1357, 1012, 1013, 1790, 1341, 1822],
    [1357, 1012, 1013, 1790, 1341, 1811],
    [1357, 1012, 1013, 1790, 1341, 1834],
    [1357, 1012, 1013, 1790, 1341, 1827],
    [1357, 1012, 1013, 1790, 1341, 1824],
    [1357, 1012, 1013, 1790, 1341, 1806],
    [1357, 1012, 1013, 1790, 1341, 1846],
    [1357, 1012, 1013, 1790, 1341, 1855],
    [1357, 1012, 1013, 1790, 1341, 1818],
    [1357, 1012, 1013, 1822, 1859, 1340],
    [1357, 1012, 1013, 1859, 1340, 1822],
    [1357, 1012, 1013, 1859, 1340, 1811],
    [1357, 1012, 1013, 1859, 1340, 1834],
    [1357, 1012, 1013, 1859, 1340, 1827],
    [1357, 1012, 1013, 1859, 1340, 1824],
    [1357, 1012, 1013, 1859, 1340, 1806],
    [1357, 1012, 1013, 1859, 1340, 1846],
    [1357, 1012, 1013, 1859, 1340, 1855],
    [1357, 1012, 1013, 1859, 1340, 1818],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0],
    [1],
    [2],
    [3],
    [4],
    [5],
    [6],
    [7],
    [8],
    [9],
    [10],
    [11],
    [12],
    [13],
    [14],
    [15],
    [16],
    [17],
    [18],
    [19],
    [20],
    [21],
    [22],
    [23],
    [24],
    [25],
    [26],
    [27],
    [28],
    [29],
    [30],
    [31],
    [32],
    [33],
    [34],
    [35],
    [36],
    [37],
    [38],
    [39],
    [40],
    [41],
    [42],
    [43],
    [44],
    [45],
    [46],
    [47],
    [48],
    [49],
    [50],
    [51],
    [52],
    [53],
    [54],
    [55],
    [56],
    [57],
    [58],
    [59],
  ];
}
