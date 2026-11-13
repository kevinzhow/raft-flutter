// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `notificationCenter`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `viewport` axis of `notificationCenter` (default `desktop`).
enum RaftNotificationCenterRecipeViewport {
  desktop('desktop'),
  mobile('mobile');

  const RaftNotificationCenterRecipeViewport(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// `size` axis of `notificationCenter` (default `md`).
enum RaftNotificationCenterRecipeSize {
  sm('sm'),
  md('md'),
  lg('lg');

  const RaftNotificationCenterRecipeSize(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// `status` axis of `notificationCenter` (default `info`).
enum RaftNotificationCenterRecipeStatus {
  error('error'),
  warning('warning'),
  info('info'),
  success('success');

  const RaftNotificationCenterRecipeStatus(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftNotificationCenterRecipe].
class RaftNotificationCenterRecipeStyle {
  const RaftNotificationCenterRecipeStyle({
    required this.trigger,
    required this.triggerIcon,
    required this.triggerBell,
    required this.triggerDot,
    required this.popup,
    required this.header,
    required this.title,
    required this.count,
    required this.scroller,
    required this.list,
    required this.item,
    required this.itemRow,
    required this.itemIcon,
    required this.itemContent,
    required this.itemTitle,
    required this.itemBody,
    required this.itemActions,
    required this.actionButton,
  });

  /// Slot `trigger`.
  final RaftSlotStyle trigger;

  /// Slot `triggerIcon`.
  final RaftSlotStyle triggerIcon;

  /// Slot `triggerBell`.
  final RaftSlotStyle triggerBell;

  /// Slot `triggerDot`.
  final RaftSlotStyle triggerDot;

  /// Slot `popup`.
  final RaftSlotStyle popup;

  /// Slot `header`.
  final RaftSlotStyle header;

  /// Slot `title`.
  final RaftSlotStyle title;

  /// Slot `count`.
  final RaftSlotStyle count;

  /// Slot `scroller`.
  final RaftSlotStyle scroller;

  /// Slot `list`.
  final RaftSlotStyle list;

  /// Slot `item`.
  final RaftSlotStyle item;

  /// Slot `itemRow`.
  final RaftSlotStyle itemRow;

  /// Slot `itemIcon`.
  final RaftSlotStyle itemIcon;

  /// Slot `itemContent`.
  final RaftSlotStyle itemContent;

  /// Slot `itemTitle`.
  final RaftSlotStyle itemTitle;

  /// Slot `itemBody`.
  final RaftSlotStyle itemBody;

  /// Slot `itemActions`.
  final RaftSlotStyle itemActions;

  /// Slot `actionButton`.
  final RaftSlotStyle actionButton;

  Map<String, RaftSlotStyle> get slots => {
    'trigger': trigger,
    'triggerIcon': triggerIcon,
    'triggerBell': triggerBell,
    'triggerDot': triggerDot,
    'popup': popup,
    'header': header,
    'title': title,
    'count': count,
    'scroller': scroller,
    'list': list,
    'item': item,
    'itemRow': itemRow,
    'itemIcon': itemIcon,
    'itemContent': itemContent,
    'itemTitle': itemTitle,
    'itemBody': itemBody,
    'itemActions': itemActions,
    'actionButton': actionButton,
  };
}

/// raft-ui recipe `notificationCenter` (`dist/components/notification-center/notification-center.mjs`, index.mjs:18333).
///
/// Used by: NotificationCenterActionButton, NotificationCenterCount, NotificationCenterHeader, NotificationCenterItem, NotificationCenterItemActions, NotificationCenterItemBody, NotificationCenterItemContent, NotificationCenterItemIcon, NotificationCenterItemRow, NotificationCenterItemTitle, NotificationCenterList, NotificationCenterPopup, NotificationCenterScroller, NotificationCenterTitle, NotificationCenterTrigger.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftNotificationCenterRecipe {
  static const String recipeName = 'notificationCenter';
  static const List<String> slotNames = [
    'trigger',
    'triggerIcon',
    'triggerBell',
    'triggerDot',
    'popup',
    'header',
    'title',
    'count',
    'scroller',
    'list',
    'item',
    'itemRow',
    'itemIcon',
    'itemContent',
    'itemTitle',
    'itemBody',
    'itemActions',
    'actionButton',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('viewport', ['desktop', 'mobile'], 'desktop', false),
    RaftRecipeAxis('size', ['sm', 'md', 'lg'], 'md', false),
    RaftRecipeAxis('read', ['true', 'false'], 'false', false),
    RaftRecipeAxis(
      'status',
      ['error', 'warning', 'info', 'success'],
      'info',
      false,
    ),
  ];

  static RaftNotificationCenterRecipeStyle resolve({
    RaftNotificationCenterRecipeViewport? viewport,
    RaftNotificationCenterRecipeSize? size,
    bool? read,
    RaftNotificationCenterRecipeStatus? status,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [viewport?.css, size?.css, read?.toString(), status?.css],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftNotificationCenterRecipeStyle(
      trigger: s[0],
      triggerIcon: s[1],
      triggerBell: s[2],
      triggerDot: s[3],
      popup: s[4],
      header: s[5],
      title: s[6],
      count: s[7],
      scroller: s[8],
      list: s[9],
      item: s[10],
      itemRow: s[11],
      itemIcon: s[12],
      itemContent: s[13],
      itemTitle: s[14],
      itemBody: s[15],
      itemActions: s[16],
      actionButton: s[17],
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
      2433,
      1847,
      2509,
      1864,
      1869,
      2253,
      2260,
      2463,
      941,
      963,
      933,
      2604,
      2483,
      2247,
      1784,
      696,
      1276,
      1439,
      480,
      474,
    ],
    [2433, 1847, 2519, 1864, 1869],
    [2519, 2499, 2592],
    [2346, 691, 2641, 2438],
    [1400, 1404, 2252, 2462, 915, 2598, 2496, 2445, 2449, 2715, 1657],
    [1400, 1864, 2405, 2101, 1466, 942, 954, 2412, 265, 267],
    [1456, 2609, 2598],
    [2132, 1454, 2616, 2600],
    [2098, 1401],
    [],
    [
      1616,
      2433,
      2405,
      2419,
      849,
      810,
      860,
      851,
      845,
      838,
      825,
      823,
      2203,
      1761,
      2229,
    ],
    [1400, 1866, 1468],
    [1400, 2499, 1864, 1869, 2143, 2529, 2463, 488, 935, 2598],
    [2116, 1401],
    [2734, 1456, 2622, 1449, 2598, 1575, 1576],
    [2144, 2734, 1901, 1456, 2587, 2603],
    [1400, 1864, 2147, 2131, 1408, 1873, 1466],
    [1400, 2499, 1864, 1869, 2143, 2529, 2463, 488, 907, 2598],
    [1400, 2499, 1864, 1869, 2143, 2529, 2463, 895, 2603, 488],
    [
      1616,
      2433,
      2405,
      2419,
      849,
      810,
      860,
      851,
      845,
      838,
      825,
      823,
      2203,
      1761,
      2361,
      747,
      723,
      756,
      748,
      754,
      750,
      725,
      727,
      724,
    ],
    [1400, 1404, 2252, 2462, 915, 2598, 2496, 2445, 2449, 2715, 1660],
    [1400, 1404, 2252, 2462, 915, 2598, 2496, 2445, 2449, 2715, 1663],
    [1400, 1404, 2252, 2462, 915, 2598, 2496, 2445, 2449, 2722, 1657],
    [1400, 1404, 2252, 2462, 915, 2598, 2496, 2445, 2449, 2722, 1660],
    [1400, 1404, 2252, 2462, 915, 2598, 2496, 2445, 2449, 2722, 1663],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 9],
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 9],
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 17, 13, 14, 15, 16, 9],
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 18, 13, 14, 15, 16, 9],
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 19, 11, 12, 13, 14, 15, 16, 9],
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 19, 11, 12, 13, 14, 15, 16, 9],
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 19, 11, 17, 13, 14, 15, 16, 9],
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 19, 11, 18, 13, 14, 15, 16, 9],
    [0, 1, 2, 3, 20, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 9],
    [0, 1, 2, 3, 20, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 9],
    [0, 1, 2, 3, 20, 5, 6, 7, 8, 9, 10, 11, 17, 13, 14, 15, 16, 9],
    [0, 1, 2, 3, 20, 5, 6, 7, 8, 9, 10, 11, 18, 13, 14, 15, 16, 9],
    [0, 1, 2, 3, 20, 5, 6, 7, 8, 9, 19, 11, 12, 13, 14, 15, 16, 9],
    [0, 1, 2, 3, 20, 5, 6, 7, 8, 9, 19, 11, 12, 13, 14, 15, 16, 9],
    [0, 1, 2, 3, 20, 5, 6, 7, 8, 9, 19, 11, 17, 13, 14, 15, 16, 9],
    [0, 1, 2, 3, 20, 5, 6, 7, 8, 9, 19, 11, 18, 13, 14, 15, 16, 9],
    [0, 1, 2, 3, 21, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 9],
    [0, 1, 2, 3, 21, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 9],
    [0, 1, 2, 3, 21, 5, 6, 7, 8, 9, 10, 11, 17, 13, 14, 15, 16, 9],
    [0, 1, 2, 3, 21, 5, 6, 7, 8, 9, 10, 11, 18, 13, 14, 15, 16, 9],
    [0, 1, 2, 3, 21, 5, 6, 7, 8, 9, 19, 11, 12, 13, 14, 15, 16, 9],
    [0, 1, 2, 3, 21, 5, 6, 7, 8, 9, 19, 11, 12, 13, 14, 15, 16, 9],
    [0, 1, 2, 3, 21, 5, 6, 7, 8, 9, 19, 11, 17, 13, 14, 15, 16, 9],
    [0, 1, 2, 3, 21, 5, 6, 7, 8, 9, 19, 11, 18, 13, 14, 15, 16, 9],
    [0, 1, 2, 3, 22, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 9],
    [0, 1, 2, 3, 22, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 9],
    [0, 1, 2, 3, 22, 5, 6, 7, 8, 9, 10, 11, 17, 13, 14, 15, 16, 9],
    [0, 1, 2, 3, 22, 5, 6, 7, 8, 9, 10, 11, 18, 13, 14, 15, 16, 9],
    [0, 1, 2, 3, 22, 5, 6, 7, 8, 9, 19, 11, 12, 13, 14, 15, 16, 9],
    [0, 1, 2, 3, 22, 5, 6, 7, 8, 9, 19, 11, 12, 13, 14, 15, 16, 9],
    [0, 1, 2, 3, 22, 5, 6, 7, 8, 9, 19, 11, 17, 13, 14, 15, 16, 9],
    [0, 1, 2, 3, 22, 5, 6, 7, 8, 9, 19, 11, 18, 13, 14, 15, 16, 9],
    [0, 1, 2, 3, 23, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 9],
    [0, 1, 2, 3, 23, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 9],
    [0, 1, 2, 3, 23, 5, 6, 7, 8, 9, 10, 11, 17, 13, 14, 15, 16, 9],
    [0, 1, 2, 3, 23, 5, 6, 7, 8, 9, 10, 11, 18, 13, 14, 15, 16, 9],
    [0, 1, 2, 3, 23, 5, 6, 7, 8, 9, 19, 11, 12, 13, 14, 15, 16, 9],
    [0, 1, 2, 3, 23, 5, 6, 7, 8, 9, 19, 11, 12, 13, 14, 15, 16, 9],
    [0, 1, 2, 3, 23, 5, 6, 7, 8, 9, 19, 11, 17, 13, 14, 15, 16, 9],
    [0, 1, 2, 3, 23, 5, 6, 7, 8, 9, 19, 11, 18, 13, 14, 15, 16, 9],
    [0, 1, 2, 3, 24, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 9],
    [0, 1, 2, 3, 24, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 9],
    [0, 1, 2, 3, 24, 5, 6, 7, 8, 9, 10, 11, 17, 13, 14, 15, 16, 9],
    [0, 1, 2, 3, 24, 5, 6, 7, 8, 9, 10, 11, 18, 13, 14, 15, 16, 9],
    [0, 1, 2, 3, 24, 5, 6, 7, 8, 9, 19, 11, 12, 13, 14, 15, 16, 9],
    [0, 1, 2, 3, 24, 5, 6, 7, 8, 9, 19, 11, 12, 13, 14, 15, 16, 9],
    [0, 1, 2, 3, 24, 5, 6, 7, 8, 9, 19, 11, 17, 13, 14, 15, 16, 9],
    [0, 1, 2, 3, 24, 5, 6, 7, 8, 9, 19, 11, 18, 13, 14, 15, 16, 9],
  ];
}
