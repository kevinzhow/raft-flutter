// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `legacyTaskPanel`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftLegacyTaskPanelRecipe].
class RaftLegacyTaskPanelRecipeStyle {
  const RaftLegacyTaskPanelRecipeStyle({required this.frame, required this.icon, required this.title, required this.body, required this.status, required this.section, required this.field, required this.fieldLabel, required this.fieldTitle, required this.fieldText, required this.meta, required this.metaRow, required this.metaLabel, required this.metaValue});

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

  Map<String, RaftSlotStyle> get slots => {'frame': frame, 'icon': icon, 'title': title, 'body': body, 'status': status, 'section': section, 'field': field, 'fieldLabel': fieldLabel, 'fieldTitle': fieldTitle, 'fieldText': fieldText, 'meta': meta, 'metaRow': metaRow, 'metaLabel': metaLabel, 'metaValue': metaValue};
}

/// raft-ui recipe `legacyTaskPanel` (`src/components/legacy-task-panel/legacy-task-panel.recipe.ts`, index.mjs:19419).
///
/// Used by: LegacyTaskPanelBody, LegacyTaskPanelField, LegacyTaskPanelFieldLabel, LegacyTaskPanelFieldText, LegacyTaskPanelFieldTitle, LegacyTaskPanelIcon, LegacyTaskPanelMeta, LegacyTaskPanelMetaLabel, LegacyTaskPanelMetaRow, LegacyTaskPanelMetaValue, LegacyTaskPanelRoot, LegacyTaskPanelSection, LegacyTaskPanelStatus, LegacyTaskPanelTitle.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftLegacyTaskPanelRecipe {
  static const String recipeName = 'legacyTaskPanel';
  static const List<String> slotNames = ['frame', 'icon', 'title', 'body', 'status', 'section', 'field', 'fieldLabel', 'fieldTitle', 'fieldText', 'meta', 'metaRow', 'metaLabel', 'metaValue'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
    RaftRecipeAxis('framed', ['true', 'false'], null, true),
  ];

  static RaftLegacyTaskPanelRecipeStyle resolve({required RaftRecipeTheme theme, bool? framed, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name, framed?.toString()], states, tokens);
    return RaftLegacyTaskPanelRecipeStyle(frame: s[0], icon: s[1], title: s[2], body: s[3], status: s[4], section: s[5], field: s[6], fieldLabel: s[7], fieldTitle: s[8], fieldText: s[9], meta: s[10], metaRow: s[11], metaLabel: s[12], metaValue: s[13]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [2890, 2570, 2486, 2656, 866, 876, 2862],
    [1620, 2886, 2867, 2312, 2317, 866, 876, 831, 2956],
    [1620, 1622, 2314, 1695, 2657, 3130],
    [2905, 2661, 2756, 2769],
    [1620, 1626, 2312, 1698],
    [2673, 2903, 866, 876, 856, 2862],
    [],
    [2491, 1689, 3032, 2959],
    [2359, 3004, 3136, 1684, 2956],
    [2359, 3017, 3132, 3136, 2966],
    [2901, 2673, 3017, 866, 876, 856, 2862],
    [1620, 2314, 2316, 1700],
    [1689, 2961],
    [3012, 2956],
    [2890, 2570, 2486, 2656, 2824, 864, 896, 2863, 1009],
    [1620, 2886, 2867, 2312, 2317, 2818, 867, 896, 825, 2978],
    [2673, 2903, 2817, 867, 896, 825, 2865, 1009],
    [2491, 1689, 3032, 2981],
    [2359, 3004, 3136, 1687, 1688, 2976],
    [2359, 3017, 3132, 3136, 2997],
    [2901, 2673, 3017, 2817, 867, 896, 825, 2865, 1009],
    [1689, 3032, 2984],
    [3012, 2976],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13], [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13], [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13], [14, 15, 2, 3, 4, 16, 6, 17, 18, 19, 20, 11, 21, 22], [14, 15, 2, 3, 4, 16, 6, 17, 18, 19, 20, 11, 21, 22], [14, 15, 2, 3, 4, 16, 6, 17, 18, 19, 20, 11, 21, 22],
  ];
}
