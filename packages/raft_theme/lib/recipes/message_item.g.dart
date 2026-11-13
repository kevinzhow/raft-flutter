// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `messageItem`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftMessageItemRecipe].
class RaftMessageItemRecipeStyle {
  const RaftMessageItemRecipeStyle({
    required this.root,
    required this.gutter,
    required this.avatarSlot,
    required this.continuationTime,
    required this.content,
    required this.header,
    required this.senderGroup,
    required this.sender,
    required this.senderButton,
    required this.senderBadges,
    required this.meta,
    required this.time,
    required this.inlineStatus,
    required this.delegatedBy,
    required this.delegatedByName,
    required this.delegatedByButton,
    required this.delegatedAvatar,
    required this.edited,
    required this.trailing,
    required this.body,
    required this.searchMatch,
    required this.embedded,
    required this.attachments,
    required this.footer,
    required this.toolbar,
    required this.toolbarButton,
  });

  /// Slot `root`.
  final RaftSlotStyle root;

  /// Slot `gutter`.
  final RaftSlotStyle gutter;

  /// Slot `avatarSlot`.
  final RaftSlotStyle avatarSlot;

  /// Slot `continuationTime`.
  final RaftSlotStyle continuationTime;

  /// Slot `content`.
  final RaftSlotStyle content;

  /// Slot `header`.
  final RaftSlotStyle header;

  /// Slot `senderGroup`.
  final RaftSlotStyle senderGroup;

  /// Slot `sender`.
  final RaftSlotStyle sender;

  /// Slot `senderButton`.
  final RaftSlotStyle senderButton;

  /// Slot `senderBadges`.
  final RaftSlotStyle senderBadges;

  /// Slot `meta`.
  final RaftSlotStyle meta;

  /// Slot `time`.
  final RaftSlotStyle time;

  /// Slot `inlineStatus`.
  final RaftSlotStyle inlineStatus;

  /// Slot `delegatedBy`.
  final RaftSlotStyle delegatedBy;

  /// Slot `delegatedByName`.
  final RaftSlotStyle delegatedByName;

  /// Slot `delegatedByButton`.
  final RaftSlotStyle delegatedByButton;

  /// Slot `delegatedAvatar`.
  final RaftSlotStyle delegatedAvatar;

  /// Slot `edited`.
  final RaftSlotStyle edited;

  /// Slot `trailing`.
  final RaftSlotStyle trailing;

  /// Slot `body`.
  final RaftSlotStyle body;

  /// Slot `searchMatch`.
  final RaftSlotStyle searchMatch;

  /// Slot `embedded`.
  final RaftSlotStyle embedded;

  /// Slot `attachments`.
  final RaftSlotStyle attachments;

  /// Slot `footer`.
  final RaftSlotStyle footer;

  /// Slot `toolbar`.
  final RaftSlotStyle toolbar;

  /// Slot `toolbarButton`.
  final RaftSlotStyle toolbarButton;

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'gutter': gutter,
    'avatarSlot': avatarSlot,
    'continuationTime': continuationTime,
    'content': content,
    'header': header,
    'senderGroup': senderGroup,
    'sender': sender,
    'senderButton': senderButton,
    'senderBadges': senderBadges,
    'meta': meta,
    'time': time,
    'inlineStatus': inlineStatus,
    'delegatedBy': delegatedBy,
    'delegatedByName': delegatedByName,
    'delegatedByButton': delegatedByButton,
    'delegatedAvatar': delegatedAvatar,
    'edited': edited,
    'trailing': trailing,
    'body': body,
    'searchMatch': searchMatch,
    'embedded': embedded,
    'attachments': attachments,
    'footer': footer,
    'toolbar': toolbar,
    'toolbarButton': toolbarButton,
  };
}

/// raft-ui recipe `messageItem` (`dist/components/message-item/message-item.recipe.mjs`, index.mjs:12024).
///
/// Used by: MessageItem, MessageItemAttachments, MessageItemAvatarSlot, MessageItemBody, MessageItemContent, MessageItemContinuationTime, MessageItemDelegatedAvatar, MessageItemDelegatedBy, MessageItemDelegatedByButton, MessageItemDelegatedByName, MessageItemEdited, MessageItemEmbedded, MessageItemFooter, MessageItemGutter, MessageItemHeader, MessageItemInlineStatus, MessageItemMeta, MessageItemSearchMatch, MessageItemSender, MessageItemSenderBadges, MessageItemSenderButton, MessageItemSenderGroup, MessageItemTime, MessageItemToolbar, MessageItemToolbarButton, MessageItemTrailing.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftMessageItemRecipe {
  static const String recipeName = 'messageItem';
  static const List<String> slotNames = [
    'root',
    'gutter',
    'avatarSlot',
    'continuationTime',
    'content',
    'header',
    'senderGroup',
    'sender',
    'senderButton',
    'senderBadges',
    'meta',
    'time',
    'inlineStatus',
    'delegatedBy',
    'delegatedByName',
    'delegatedByButton',
    'delegatedAvatar',
    'edited',
    'trailing',
    'body',
    'searchMatch',
    'embedded',
    'attachments',
    'footer',
    'toolbar',
    'toolbarButton',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('compact', ['true', 'false'], null, true),
  ];

  static RaftMessageItemRecipeStyle resolve({
    bool? compact,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [compact?.toString()],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftMessageItemRecipeStyle(
      root: s[0],
      gutter: s[1],
      avatarSlot: s[2],
      continuationTime: s[3],
      content: s[4],
      header: s[5],
      senderGroup: s[6],
      sender: s[7],
      senderButton: s[8],
      senderBadges: s[9],
      meta: s[10],
      time: s[11],
      inlineStatus: s[12],
      delegatedBy: s[13],
      delegatedByName: s[14],
      delegatedByButton: s[15],
      delegatedAvatar: s[16],
      edited: s[17],
      trailing: s[18],
      body: s[19],
      searchMatch: s[20],
      embedded: s[21],
      attachments: s[22],
      footer: s[23],
      toolbar: s[24],
      toolbarButton: s[25],
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
    [
      1613,
      2433,
      1400,
      1677,
      1468,
      1780,
      1781,
      1444,
      1445,
      1768,
      1769,
      1779,
      1443,
      1766,
      2098,
      2401,
      2432,
      961,
      963,
      890,
      1778,
      1765,
      875,
      565,
      2187,
      1273,
      1767,
      1757,
      1758,
      1723,
      1724,
      2247,
      1421,
      1422,
    ],
    [2433, 2499, 2490, 2714],
    [2433, 2499, 2489, 1400, 2714, 1869, 395],
    [691, 2437, 2483, 2729, 2556, 2646, 1454, 2616, 2565],
    [2116, 1401, 2585, 2598],
    [1994, 1400, 2116, 1863, 1465, 2252, 1908, 1755, 1756],
    [1400, 2116, 1863, 1465, 2252, 1402, 1981, 116, 120, 115, 118, 119, 117],
    [2116, 2681, 2622, 1449, 2598, 2457, 2247, 1439],
    [2116, 2681, 2622, 1449, 2598, 2457, 2247, 1439, 997, 1338, 2684, 1800],
    [1847, 2499, 1864, 1464],
    [2116, 2681, 2588, 2600],
    [2499, 2729, 1454, 2616, 2556, 2600],
    [2499, 2588, 2600],
    [1848, 1501, 1863, 2130, 2498, 2730, 1753, 1754, 1751, 1752, 2588, 2603],
    [2116, 2681],
    [2116, 2681, 997, 1336, 2684, 1800, 2457, 2247, 1439],
    [2527, 1534, 2471, 2247, 910, 883, 1170, 1171, 2492, 1000],
    [2141, 2729, 2588, 2600],
    [691, 1387, 965, 2747, 1400, 1679, 1864, 2484, 82],
    [2734, 2485, 83, 2585, 2598, 2486],
    [680, 2471, 936, 2408, 2431, 976, 2621],
    [2116, 2147],
    [2543, 2147],
    [2146, 1400, 1408, 1864, 1465],
    [
      691,
      2739,
      1400,
      1864,
      2227,
      687,
      2644,
      2083,
      2439,
      1464,
      2253,
      2462,
      2261,
      915,
      2445,
      2449,
      2447,
      2496,
    ],
    [
      1847,
      2499,
      1864,
      1869,
      474,
      2521,
      2461,
      2082,
      2077,
      940,
      933,
      2260,
      2603,
      1785,
      697,
      1277,
      1145,
      2247,
      1439,
      478,
    ],
    [
      1613,
      2433,
      1400,
      1677,
      1468,
      1780,
      1781,
      1444,
      1445,
      1768,
      1769,
      1779,
      1443,
      1766,
      2098,
      2401,
      2432,
      963,
      890,
      1778,
      1765,
      875,
      565,
      2187,
      1273,
      1767,
      1757,
      1758,
      1723,
      1724,
      2247,
      1421,
      1422,
      962,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [
      0,
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      9,
      10,
      11,
      12,
      13,
      14,
      15,
      16,
      17,
      18,
      19,
      20,
      21,
      22,
      23,
      24,
      25,
    ],
    [
      26,
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      9,
      10,
      11,
      12,
      13,
      14,
      15,
      16,
      17,
      18,
      19,
      20,
      21,
      22,
      23,
      24,
      25,
    ],
    [
      0,
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      9,
      10,
      11,
      12,
      13,
      14,
      15,
      16,
      17,
      18,
      19,
      20,
      21,
      22,
      23,
      24,
      25,
    ],
  ];
}
