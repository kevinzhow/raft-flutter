// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.7.0 dist/index.mjs (sha256 83bf0bff35092e3d),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `messageActionCardContent`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftMessageActionCardContentRecipe].
class RaftMessageActionCardContentRecipeStyle {
  const RaftMessageActionCardContentRecipeStyle({
    required this.root,
    required this.panel,
    required this.properties,
    required this.property,
    required this.propertyLabel,
    required this.propertyValue,
    required this.scopeList,
    required this.scopeListViewport,
    required this.scopeListLabel,
    required this.scope,
    required this.scopeName,
    required this.scopeDescription,
    required this.hintLabel,
    required this.hint,
    required this.notice,
    required this.completion,
    required this.actions,
    required this.actionsNote,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `panel`.
  final RaftSlotStyle panel;

  /// Slot `properties`.
  final RaftSlotStyle properties;

  /// Slot `property`.
  final RaftSlotStyle property;

  /// Slot `propertyLabel`.
  final RaftSlotStyle propertyLabel;

  /// Slot `propertyValue`.
  final RaftSlotStyle propertyValue;

  /// Slot `scopeList`.
  final RaftSlotStyle scopeList;

  /// Slot `scopeListViewport`.
  final RaftSlotStyle scopeListViewport;

  /// Slot `scopeListLabel`.
  final RaftSlotStyle scopeListLabel;

  /// Slot `scope`.
  final RaftSlotStyle scope;

  /// Slot `scopeName`.
  final RaftSlotStyle scopeName;

  /// Slot `scopeDescription`.
  final RaftSlotStyle scopeDescription;

  /// Slot `hintLabel`.
  final RaftSlotStyle hintLabel;

  /// Slot `hint`.
  final RaftSlotStyle hint;

  /// Slot `notice`.
  final RaftSlotStyle notice;

  /// Slot `completion`.
  final RaftSlotStyle completion;

  /// Slot `actions`.
  final RaftSlotStyle actions;

  /// Slot `actionsNote`.
  final RaftSlotStyle actionsNote;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'panel': panel,
    'properties': properties,
    'property': property,
    'propertyLabel': propertyLabel,
    'propertyValue': propertyValue,
    'scopeList': scopeList,
    'scopeListViewport': scopeListViewport,
    'scopeListLabel': scopeListLabel,
    'scope': scope,
    'scopeName': scopeName,
    'scopeDescription': scopeDescription,
    'hintLabel': hintLabel,
    'hint': hint,
    'notice': notice,
    'completion': completion,
    'actions': actions,
    'actionsNote': actionsNote,
  };
}

/// raft-ui recipe `messageActionCardContent` (`src/components/message-action-card/message-action-card-content.recipe.ts`, index.mjs:8363).
///
/// Used by: MessageActionCardActions, MessageActionCardActionsNote, MessageActionCardCompletion, MessageActionCardContent, MessageActionCardHint, MessageActionCardHintLabel, MessageActionCardNotice, MessageActionCardProperties, MessageActionCardProperty, MessageActionCardPropertyLabel, MessageActionCardPropertyValue, MessageActionCardScope, MessageActionCardScopeDescription, MessageActionCardScopeList, MessageActionCardScopeListLabel, MessageActionCardScopeListViewport, MessageActionCardScopeName.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftMessageActionCardContentRecipe {
  static const String recipeName = 'messageActionCardContent';
  static const List<String> slotNames = [
    'root',
    'panel',
    'properties',
    'property',
    'propertyLabel',
    'propertyValue',
    'scopeList',
    'scopeListViewport',
    'scopeListLabel',
    'scope',
    'scopeName',
    'scopeDescription',
    'hintLabel',
    'hint',
    'notice',
    'completion',
    'actions',
    'actionsNote',
  ];
  static const List<RaftRecipeAxis> axes = [];

  static RaftMessageActionCardContentRecipeStyle resolve({
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftMessageActionCardContentRecipeStyle(
      root: s[0],
      panel: s[1],
      properties: s[2],
      property: s[3],
      propertyLabel: s[4],
      propertyValue: s[5],
      scopeList: s[6],
      scopeListViewport: s[7],
      scopeListLabel: s[8],
      scope: s[9],
      scopeName: s[10],
      scopeDescription: s[11],
      hintLabel: s[12],
      hint: s[13],
      notice: s[14],
      completion: s[15],
      actions: s[16],
      actionsNote: s[17],
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
    [1594, 965, 967, 1023, 1658, 1640, 1605],
    [1166, 1581, 1885, 943, 950, 1503, 905, 845],
    [1357, 1040, 1401, 1400, 1047, 1319, 1035, 1037],
    [659],
    [1403, 1483, 1935, 1819, 1013, 1822],
    [1357, 1483, 1935, 1478, 1667, 1811, 1820],
    [1507, 1774],
    [1585, 1587, 1364, 1774, 1632],
    [1819, 1013, 1822],
    [1483, 620, 1592, 1708, 633, 596, 1657, 1669],
    [651, 1014, 1837, 1015, 1820],
    [1508, 1819, 1838, 1825],
    [631, 634, 1617, 1819, 1825, 406],
    [
      965,
      1321,
      1023,
      179,
      177,
      1429,
      1708,
      581,
      1657,
      1669,
      1819,
      1825,
      171,
      189,
    ],
    [1305, 1319, 1022, 1819, 1825, 180, 177, 187],
    [965, 971, 1319, 1325, 1509, 1023],
    [1483, 966, 509, 1819, 1825],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 8, 12, 13, 14, 15, 16],
  ];
}
