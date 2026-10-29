// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `legacyTaskPanel`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftLegacyTaskPanelRecipe].
class RaftLegacyTaskPanelRecipeStyle {
  const RaftLegacyTaskPanelRecipeStyle({
    required this.frame,
    required this.icon,
    required this.title,
    required this.body,
    required this.status,
    required this.section,
    required this.field,
    required this.fieldLabel,
    required this.fieldTitle,
    required this.fieldText,
    required this.meta,
    required this.metaRow,
    required this.metaLabel,
    required this.metaValue,
  });

  /// Slot `frame`.
  final RaftSlotStyle frame;

  /// Slot `icon`.
  final RaftSlotStyle icon;

  /// Slot `title`.
  final RaftSlotStyle title;

  /// Slot `body`.
  final RaftSlotStyle body;

  /// Slot `status`.
  final RaftSlotStyle status;

  /// Slot `section`.
  final RaftSlotStyle section;

  /// Slot `field`.
  final RaftSlotStyle field;

  /// Slot `fieldLabel`.
  final RaftSlotStyle fieldLabel;

  /// Slot `fieldTitle`.
  final RaftSlotStyle fieldTitle;

  /// Slot `fieldText`.
  final RaftSlotStyle fieldText;

  /// Slot `meta`.
  final RaftSlotStyle meta;

  /// Slot `metaRow`.
  final RaftSlotStyle metaRow;

  /// Slot `metaLabel`.
  final RaftSlotStyle metaLabel;

  /// Slot `metaValue`.
  final RaftSlotStyle metaValue;

  Map<String, RaftSlotStyle> get slots => {
    'frame': frame,
    'icon': icon,
    'title': title,
    'body': body,
    'status': status,
    'section': section,
    'field': field,
    'fieldLabel': fieldLabel,
    'fieldTitle': fieldTitle,
    'fieldText': fieldText,
    'meta': meta,
    'metaRow': metaRow,
    'metaLabel': metaLabel,
    'metaValue': metaValue,
  };
}

/// raft-ui recipe `legacyTaskPanel` (`src/components/legacy-task-panel/legacy-task-panel.recipe.ts`, index.mjs:15713).
///
/// Used by: LegacyTaskPanelBody, LegacyTaskPanelField, LegacyTaskPanelFieldLabel, LegacyTaskPanelFieldText, LegacyTaskPanelFieldTitle, LegacyTaskPanelIcon, LegacyTaskPanelMeta, LegacyTaskPanelMetaLabel, LegacyTaskPanelMetaRow, LegacyTaskPanelMetaValue, LegacyTaskPanelRoot, LegacyTaskPanelSection, LegacyTaskPanelStatus, LegacyTaskPanelTitle.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftLegacyTaskPanelRecipe {
  static const String recipeName = 'legacyTaskPanel';
  static const List<String> slotNames = [
    'frame',
    'icon',
    'title',
    'body',
    'status',
    'section',
    'field',
    'fieldLabel',
    'fieldTitle',
    'fieldText',
    'meta',
    'metaRow',
    'metaLabel',
    'metaValue',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('framed', ['true', 'false'], null, true),
  ];

  static RaftLegacyTaskPanelRecipeStyle resolve({
    bool? framed,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [framed?.toString()],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftLegacyTaskPanelRecipeStyle(
      frame: s[0],
      icon: s[1],
      title: s[2],
      body: s[3],
      status: s[4],
      section: s[5],
      field: s[6],
      fieldLabel: s[7],
      fieldTitle: s[8],
      fieldText: s[9],
      meta: s[10],
      metaRow: s[11],
      metaLabel: s[12],
      metaValue: s[13],
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
    [1768, 1480, 1426, 1581, 1707, 620, 634, 595, 1736],
    [965, 1738, 1319, 1324, 1762, 1714, 581, 1825, 279],
    [965, 967, 1321, 1020, 1582, 1929],
    [1777, 1585, 1661, 1673],
    [965, 971, 1319, 1023],
    [1595, 1776, 1707, 620, 633, 596, 1736],
    [],
    [1430, 1016, 1819, 1013, 1822],
    [1357, 1935, 1808, 1017, 1820],
    [1357, 1931, 1935, 1843, 1825],
    [1595, 1840, 1772, 1707, 620, 633, 596, 1660, 1669, 1736],
    [965, 1323, 1025, 1478, 1319],
    [1016, 1819, 1013, 1822],
    [1839, 1811, 1820],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13],
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13],
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13],
  ];
}
