// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `messageItem`.
// ignore_for_file: type=lint

import '../recipe_runtime.dart';
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
    required this.sender,
    required this.senderBadges,
    required this.meta,
    required this.time,
    required this.inlineStatus,
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

  /// Slot `sender`.
  final RaftSlotStyle sender;

  /// Slot `senderBadges`.
  final RaftSlotStyle senderBadges;

  /// Slot `meta`.
  final RaftSlotStyle meta;

  /// Slot `time`.
  final RaftSlotStyle time;

  /// Slot `inlineStatus`.
  final RaftSlotStyle inlineStatus;

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
    'sender': sender,
    'senderBadges': senderBadges,
    'meta': meta,
    'time': time,
    'inlineStatus': inlineStatus,
    'body': body,
    'searchMatch': searchMatch,
    'embedded': embedded,
    'attachments': attachments,
    'footer': footer,
    'toolbar': toolbar,
    'toolbarButton': toolbarButton,
  };
}

/// raft-ui recipe `messageItem` (`src/components/message-item/message-item.recipe.ts`, index.mjs:8998).
///
/// Used by: MessageItem, MessageItemAttachments, MessageItemAvatarSlot, MessageItemBody, MessageItemContent, MessageItemContinuationTime, MessageItemEmbedded, MessageItemFooter, MessageItemGutter, MessageItemHeader, MessageItemInlineStatus, MessageItemMeta, MessageItemSearchMatch, MessageItemSender, MessageItemSenderBadges, MessageItemSenderButton, MessageItemTime, MessageItemToolbar, MessageItemToolbarButton.
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
    'sender',
    'senderBadges',
    'meta',
    'time',
    'inlineStatus',
    'body',
    'searchMatch',
    'embedded',
    'attachments',
    'footer',
    'toolbar',
    'toolbarButton',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
    RaftRecipeAxis('compact', ['true', 'false'], null, true),
  ];

  static RaftMessageItemRecipeStyle resolve({
    required RaftRecipeTheme theme,
    bool? compact,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [theme.name, compact?.toString()],
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
      sender: s[6],
      senderBadges: s[7],
      meta: s[8],
      time: s[9],
      inlineStatus: s[10],
      body: s[11],
      searchMatch: s[12],
      embedded: s[13],
      attachments: s[14],
      footer: s[15],
      toolbar: s[16],
      toolbarButton: s[17],
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
      1927,
      2804,
      1644,
      1979,
      2592,
      1725,
      2197,
      2198,
      1694,
      1695,
      2184,
      2185,
      2512,
      2622,
      878,
      930,
      2778,
      2791,
      1495,
      2266,
      2242,
      1553,
      1549,
      2188,
      2187,
      2195,
      2182,
      2158,
      2156,
      2166,
      2160,
    ],
    [2804, 3158, 2902, 2872, 2480],
    [2804, 3158, 2902, 2871, 2480, 2412, 1644, 2336, 375, 374],
    [586, 2809, 3078, 2868, 2946, 1714, 2956, 2363, 2949],
    [2597, 1645, 3053],
    [1644, 2597, 2679, 2741, 2331, 1723],
    [2597, 2902, 3133, 1370, 3053, 1709, 2994, 1372, 1371, 1373],
    [2320, 2902, 2331, 1721],
    [2597, 3133, 1714, 3073, 2996],
    [2902, 3172, 1714, 3073, 2996],
    [2902, 2956, 1709, 2996],
    [3177, 2869, 84, 3053, 2994],
    [845, 3037, 582, 1019],
    [2622, 2597],
    [2621, 2936],
    [2622, 1644, 1650, 2331, 1722],
    [586, 3180, 1644, 2331, 2679, 2648, 584, 150, 2812, 878, 916, 868, 2897],
    [
      2320,
      2902,
      2331,
      2336,
      425,
      2918,
      2998,
      2247,
      2291,
      1550,
      1561,
      1430,
      1421,
      437,
    ],
    [
      1927,
      2804,
      1644,
      1979,
      1725,
      2197,
      2198,
      1694,
      1695,
      2184,
      2185,
      2512,
      878,
      930,
      2778,
      1495,
      2266,
      2242,
      1553,
      1549,
      2188,
      2187,
      2195,
      2182,
      2158,
      2156,
      2166,
      2160,
      2619,
      2583,
      2791,
    ],
    [
      1927,
      2804,
      1644,
      1979,
      2592,
      1725,
      2197,
      2198,
      1694,
      1695,
      2184,
      2185,
      876,
      930,
      2431,
      2788,
      2768,
      2708,
      2466,
      2457,
      1246,
      1247,
      1496,
      2240,
      1547,
      2186,
      2196,
      2183,
      2159,
      2157,
      2165,
      2161,
      2162,
      2164,
      2163,
    ],
    [2804, 3158, 2902, 2871, 1644, 2336, 375, 373, 372, 371, 2480, 2412],
    [586, 2809, 2868, 2946, 3077, 2759, 1716, 3073, 2363, 2949],
    [2597, 1645, 3053, 2355, 3088],
    [1644, 2597, 2679, 2741, 2330, 1722],
    [2597, 2902, 3133, 1370, 3053, 1717, 2363, 3018, 1372, 1371, 1373],
    [2597, 3133, 1716, 3073, 2363, 3014],
    [2902, 3172, 1716, 3073, 2363, 2946, 3014],
    [2902, 1716, 2958, 1713, 2363, 3014],
    [
      3177,
      2869,
      84,
      2622,
      2513,
      2454,
      2452,
      3053,
      2355,
      3088,
      3018,
      1753,
      1752,
    ],
    [1644, 1650, 2331, 1722, 2624, 2455],
    [
      586,
      3180,
      1644,
      2331,
      2679,
      2648,
      584,
      3078,
      2816,
      1720,
      2847,
      2777,
      2790,
      879,
      912,
      830,
      2899,
      1029,
    ],
    [
      2320,
      2902,
      2331,
      2336,
      425,
      2919,
      2848,
      876,
      930,
      863,
      2690,
      3015,
      2231,
      2299,
      1546,
      1563,
      1678,
      1691,
      1434,
      1424,
      428,
    ],
    [
      1927,
      2804,
      1644,
      1979,
      1725,
      2197,
      2198,
      1694,
      1695,
      2184,
      2185,
      876,
      930,
      2431,
      2788,
      1246,
      1247,
      1496,
      2240,
      1547,
      2186,
      2196,
      2183,
      2159,
      2157,
      2165,
      2161,
      2162,
      2164,
      2163,
      2619,
      2583,
      2759,
      2705,
      2465,
      2457,
    ],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17],
    [18, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17],
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17],
    [19, 1, 20, 21, 22, 23, 24, 7, 25, 26, 27, 28, 12, 13, 14, 29, 30, 31],
    [32, 1, 20, 21, 22, 23, 24, 7, 25, 26, 27, 28, 12, 13, 14, 29, 30, 31],
    [19, 1, 20, 21, 22, 23, 24, 7, 25, 26, 27, 28, 12, 13, 14, 29, 30, 31],
  ];
}
