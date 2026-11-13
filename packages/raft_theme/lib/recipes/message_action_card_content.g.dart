// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `messageActionCardContent`.
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
    required this.scopeListViewportContent,
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

  /// Slot `scopeListViewportContent`.
  final RaftSlotStyle scopeListViewportContent;

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
    'scopeListViewportContent': scopeListViewportContent,
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

/// raft-ui recipe `messageActionCardContent` (`dist/components/message-action-card/message-action-card-content.recipe.mjs`, index.mjs:13503).
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
    'scopeListViewportContent',
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
      scopeListViewportContent: s[8],
      scopeListLabel: s[9],
      scope: s[10],
      scopeName: s[11],
      scopeDescription: s[12],
      hintLabel: s[13],
      hint: s[14],
      notice: s[15],
      completion: s[16],
      actions: s[17],
      actionsNote: s[18],
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
    [1400, 1404, 1466, 2378],
    [1632, 2252, 2668, 1367, 1376, 2138, 1324, 1197],
    [1907, 1489, 1319, 1498, 1863, 1482, 1485],
    [992],
    [1957, 2116, 2734, 2597, 1453, 2600, 651],
    [1907, 2116, 2734, 2107, 2415, 2587, 2598, 652, 653],
    [2143, 2542],
    [1917],
    [2542, 2355],
    [2597, 1453, 2600],
    [2116, 939, 2262, 2463, 953, 911, 2402, 2417],
    [977, 1454, 2616, 1455, 2598],
    [2144, 2597, 2617, 2603],
    [951, 954, 2299, 2597, 2603, 647],
    [
      1400,
      1866,
      1466,
      351,
      348,
      1986,
      2463,
      895,
      2402,
      2417,
      2597,
      2603,
      341,
      360,
    ],
    [1847, 1864, 1465, 2597, 2603, 352, 348, 358],
    [2145],
    [2116, 805, 2597, 2603],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 9, 13, 14, 15, 16, 17],
  ];
}
