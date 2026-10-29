// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `legacyTaskPanel`.
// ignore_for_file: type=lint

import '../recipe_runtime.dart';
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

/// raft-ui recipe `legacyTaskPanel` (`src/components/legacy-task-panel/legacy-task-panel.recipe.ts`, index.mjs:19568).
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
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
    RaftRecipeAxis('framed', ['true', 'false'], null, true),
  ];

  static RaftLegacyTaskPanelRecipeStyle resolve({
    required RaftRecipeTheme theme,
    bool? framed,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [theme.name, framed?.toString()],
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
    [2925, 2593, 2507, 2679, 878, 892, 2896],
    [1644, 2921, 2902, 2331, 2336, 878, 892, 836, 2994],
    [1644, 1646, 2333, 1720, 2680, 3171],
    [2940, 2684, 2784, 2798],
    [1644, 1650, 2331, 1723],
    [2696, 2938, 878, 892, 868, 2896],
    [],
    [2512, 1714, 3073, 2996],
    [2378, 3041, 3177, 1709, 2994],
    [2378, 3053, 3173, 3177, 3003],
    [2936, 2696, 3053, 878, 892, 868, 2896],
    [1644, 2333, 2335, 1725],
    [1714, 2998],
    [3048, 2994],
    [2925, 2593, 2507, 2679, 2854, 876, 912, 2897, 1029],
    [1644, 2921, 2902, 2331, 2336, 2848, 879, 912, 830, 3015],
    [2696, 2938, 2847, 879, 912, 830, 2899, 1029],
    [2512, 1714, 3073, 3018],
    [2378, 3041, 3177, 1712, 1713, 3013],
    [2378, 3053, 3173, 3177, 3034],
    [2936, 2696, 3053, 2847, 879, 912, 830, 2899, 1029],
    [1714, 3073, 3021],
    [3048, 3013],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13],
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13],
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13],
    [14, 15, 2, 3, 4, 16, 6, 17, 18, 19, 20, 11, 21, 22],
    [14, 15, 2, 3, 4, 16, 6, 17, 18, 19, 20, 11, 21, 22],
    [14, 15, 2, 3, 4, 16, 6, 17, 18, 19, 20, 11, 21, 22],
  ];
}
