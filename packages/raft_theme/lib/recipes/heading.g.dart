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
    [1356, 1011, 1012, 1818, 1801, 1868, 1334],
    [1356, 1011, 1012, 1801, 1868, 1334, 1818],
    [1356, 1011, 1012, 1801, 1868, 1334, 1807],
    [1356, 1011, 1012, 1801, 1868, 1334, 1830],
    [1356, 1011, 1012, 1801, 1868, 1334, 1823],
    [1356, 1011, 1012, 1801, 1868, 1334, 1820],
    [1356, 1011, 1012, 1801, 1868, 1334, 1802],
    [1356, 1011, 1012, 1801, 1868, 1334, 1842],
    [1356, 1011, 1012, 1801, 1868, 1334, 1851],
    [1356, 1011, 1012, 1801, 1868, 1334, 1814],
    [1356, 1011, 1012, 1818, 1787, 1868, 1333],
    [1356, 1011, 1012, 1787, 1868, 1333, 1818],
    [1356, 1011, 1012, 1787, 1868, 1333, 1807],
    [1356, 1011, 1012, 1787, 1868, 1333, 1830],
    [1356, 1011, 1012, 1787, 1868, 1333, 1823],
    [1356, 1011, 1012, 1787, 1868, 1333, 1820],
    [1356, 1011, 1012, 1787, 1868, 1333, 1802],
    [1356, 1011, 1012, 1787, 1868, 1333, 1842],
    [1356, 1011, 1012, 1787, 1868, 1333, 1851],
    [1356, 1011, 1012, 1787, 1868, 1333, 1814],
    [1356, 1011, 1012, 1818, 1799, 1868, 1332],
    [1356, 1011, 1012, 1799, 1868, 1332, 1818],
    [1356, 1011, 1012, 1799, 1868, 1332, 1807],
    [1356, 1011, 1012, 1799, 1868, 1332, 1830],
    [1356, 1011, 1012, 1799, 1868, 1332, 1823],
    [1356, 1011, 1012, 1799, 1868, 1332, 1820],
    [1356, 1011, 1012, 1799, 1868, 1332, 1802],
    [1356, 1011, 1012, 1799, 1868, 1332, 1842],
    [1356, 1011, 1012, 1799, 1868, 1332, 1851],
    [1356, 1011, 1012, 1799, 1868, 1332, 1814],
    [1356, 1011, 1012, 1818, 1798, 1867, 1331],
    [1356, 1011, 1012, 1798, 1867, 1331, 1818],
    [1356, 1011, 1012, 1798, 1867, 1331, 1807],
    [1356, 1011, 1012, 1798, 1867, 1331, 1830],
    [1356, 1011, 1012, 1798, 1867, 1331, 1823],
    [1356, 1011, 1012, 1798, 1867, 1331, 1820],
    [1356, 1011, 1012, 1798, 1867, 1331, 1802],
    [1356, 1011, 1012, 1798, 1867, 1331, 1842],
    [1356, 1011, 1012, 1798, 1867, 1331, 1851],
    [1356, 1011, 1012, 1798, 1867, 1331, 1814],
    [1356, 1011, 1012, 1818, 1786, 1340],
    [1356, 1011, 1012, 1786, 1340, 1818],
    [1356, 1011, 1012, 1786, 1340, 1807],
    [1356, 1011, 1012, 1786, 1340, 1830],
    [1356, 1011, 1012, 1786, 1340, 1823],
    [1356, 1011, 1012, 1786, 1340, 1820],
    [1356, 1011, 1012, 1786, 1340, 1802],
    [1356, 1011, 1012, 1786, 1340, 1842],
    [1356, 1011, 1012, 1786, 1340, 1851],
    [1356, 1011, 1012, 1786, 1340, 1814],
    [1356, 1011, 1012, 1818, 1855, 1339],
    [1356, 1011, 1012, 1855, 1339, 1818],
    [1356, 1011, 1012, 1855, 1339, 1807],
    [1356, 1011, 1012, 1855, 1339, 1830],
    [1356, 1011, 1012, 1855, 1339, 1823],
    [1356, 1011, 1012, 1855, 1339, 1820],
    [1356, 1011, 1012, 1855, 1339, 1802],
    [1356, 1011, 1012, 1855, 1339, 1842],
    [1356, 1011, 1012, 1855, 1339, 1851],
    [1356, 1011, 1012, 1855, 1339, 1814],
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
