// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.52 dist/index.mjs (sha256 742e86bfdb372e8f),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `lightbox`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftLightboxRecipe].
class RaftLightboxRecipeStyle {
  const RaftLightboxRecipeStyle({
    required this.backdrop,
    required this.content,
    required this.header,
    required this.toolbar,
    required this.headerMeta,
    required this.headerLabel,
    required this.title,
    required this.actions,
    required this.stage,
    required this.media,
    required this.navigationButton,
    required this.infoDock,
    required this.infoBar,
    required this.infoTitle,
    required this.infoActions,
    required this.thumbnailStrip,
    required this.thumbnail,
    required this.thumbnailOverlay,
    required this.close,
  });

  /// Slot `backdrop`.
  final RaftSlotStyle backdrop;

  /// Slot `content`.
  final RaftSlotStyle content;

  /// Slot `header`.
  final RaftSlotStyle header;

  /// Slot `toolbar`.
  final RaftSlotStyle toolbar;

  /// Slot `headerMeta`.
  final RaftSlotStyle headerMeta;

  /// Slot `headerLabel`.
  final RaftSlotStyle headerLabel;

  /// Slot `title`.
  final RaftSlotStyle title;

  /// Slot `actions`.
  final RaftSlotStyle actions;

  /// Slot `stage`.
  final RaftSlotStyle stage;

  /// Slot `media`.
  final RaftSlotStyle media;

  /// Slot `navigationButton`.
  final RaftSlotStyle navigationButton;

  /// Slot `infoDock`.
  final RaftSlotStyle infoDock;

  /// Slot `infoBar`.
  final RaftSlotStyle infoBar;

  /// Slot `infoTitle`.
  final RaftSlotStyle infoTitle;

  /// Slot `infoActions`.
  final RaftSlotStyle infoActions;

  /// Slot `thumbnailStrip`.
  final RaftSlotStyle thumbnailStrip;

  /// Slot `thumbnail`.
  final RaftSlotStyle thumbnail;

  /// Slot `thumbnailOverlay`.
  final RaftSlotStyle thumbnailOverlay;

  /// Slot `close`.
  final RaftSlotStyle close;

  Map<String, RaftSlotStyle> get slots => {
    'backdrop': backdrop,
    'content': content,
    'header': header,
    'toolbar': toolbar,
    'headerMeta': headerMeta,
    'headerLabel': headerLabel,
    'title': title,
    'actions': actions,
    'stage': stage,
    'media': media,
    'navigationButton': navigationButton,
    'infoDock': infoDock,
    'infoBar': infoBar,
    'infoTitle': infoTitle,
    'infoActions': infoActions,
    'thumbnailStrip': thumbnailStrip,
    'thumbnail': thumbnail,
    'thumbnailOverlay': thumbnailOverlay,
    'close': close,
  };
}

/// raft-ui recipe `lightbox` (`src/components/lightbox/lightbox.tsx`, index.mjs:5367).
///
/// Used by: LightboxActions, LightboxClose, LightboxContent, LightboxHeader, LightboxHeaderLabel, LightboxHeaderMeta, LightboxInfoActions, LightboxInfoBar, LightboxInfoDock, LightboxInfoTitle, LightboxMedia, LightboxNavigationButton, LightboxStage, LightboxThumbnail, LightboxThumbnailStrip, LightboxTitle, LightboxToolbar.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftLightboxRecipe {
  static const String recipeName = 'lightbox';
  static const List<String> slotNames = [
    'backdrop',
    'content',
    'header',
    'toolbar',
    'headerMeta',
    'headerLabel',
    'title',
    'actions',
    'stage',
    'media',
    'navigationButton',
    'infoDock',
    'infoBar',
    'infoTitle',
    'infoActions',
    'thumbnailStrip',
    'thumbnail',
    'thumbnailOverlay',
    'close',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftLightboxRecipeStyle resolve({
    required RaftRecipeTheme theme,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [theme.name],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftLightboxRecipeStyle(
      backdrop: s[0],
      content: s[1],
      header: s[2],
      toolbar: s[3],
      headerMeta: s[4],
      headerLabel: s[5],
      title: s[6],
      actions: s[7],
      stage: s[8],
      media: s[9],
      navigationButton: s[10],
      infoDock: s[11],
      infoBar: s[12],
      infoTitle: s[13],
      infoActions: s[14],
      thumbnailStrip: s[15],
      thumbnail: s[16],
      thumbnailOverlay: s[17],
      close: s[18],
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
    [1643, 2322, 3185, 824, 1454],
    [2739, 1643, 2322, 3186, 1644, 1646, 1454, 117, 116, 121, 120, 118],
    [2738, 2902, 1644, 2331, 1725, 2708, 2770, 2730, 2754, 863, 2894],
    [
      2738,
      2902,
      1644,
      2331,
      1725,
      1976,
      2771,
      2729,
      2753,
      78,
      76,
      79,
      77,
      891,
      892,
      868,
      2894,
    ],
    [1644, 2597, 1645, 2331, 1722],
    [
      2320,
      2902,
      2331,
      2778,
      2790,
      2956,
      2363,
      1709,
      3137,
      3096,
      878,
      892,
      836,
      1712,
      2994,
    ],
    [2597, 1645, 3133, 3053, 2356, 2757, 2704, 1712, 1717, 2994],
    [1644, 2902, 2331, 1722],
    [2739, 2804, 1644, 2583, 1645, 2331, 2336, 2679],
    [2738, 2386, 2498, 877, 863, 2894],
    [
      2738,
      586,
      3179,
      2320,
      2331,
      2336,
      878,
      916,
      830,
      3013,
      2897,
      3109,
      1626,
      2669,
      2673,
      2675,
      1667,
      1215,
      423,
      425,
      2920,
      2849,
      2242,
      1225,
      432,
    ],
    [2739, 586, 2815, 941, 2372, 3179, 1644, 2336],
    [
      2738,
      1644,
      2331,
      830,
      3013,
      3163,
      2499,
      2598,
      1723,
      2849,
      878,
      916,
      2790,
      2745,
      2723,
      2897,
      377,
    ],
    [2597, 1645, 3133, 1712, 1709, 3073, 3024],
    [2739, 586, 2809, 943, 2369, 3179, 1644, 2331, 2336, 1722],
    [
      1926,
      2738,
      2804,
      2908,
      2679,
      3111,
      1626,
      406,
      407,
      405,
      878,
      933,
      2653,
      2879,
      2268,
      2284,
      2285,
      1414,
      1417,
      1425,
      1428,
    ],
    [2739, 586, 2322, 3125, 1626, 2189],
    [2738, 429],
    [1643, 2322, 3185, 1454, 762, 685],
    [
      2739,
      1643,
      2322,
      3186,
      1644,
      1646,
      1454,
      117,
      116,
      121,
      120,
      118,
      119,
      221,
      220,
    ],
    [
      2738,
      2902,
      1644,
      2331,
      1725,
      1976,
      2771,
      2729,
      2753,
      78,
      76,
      79,
      77,
      889,
      912,
      830,
      2894,
    ],
    [
      2320,
      2902,
      2331,
      2778,
      2790,
      2956,
      2363,
      1709,
      3137,
      3096,
      2845,
      876,
      912,
      801,
      1716,
      3018,
    ],
    [2597, 1645, 3133, 3053, 2356, 2757, 2704, 1716, 1713, 3013],
    [1644, 2902, 2331, 1723],
    [
      2738,
      586,
      3179,
      2320,
      2331,
      2336,
      916,
      3109,
      1626,
      2669,
      2673,
      2675,
      1667,
      1215,
      423,
      425,
      2920,
      2845,
      877,
      871,
      686,
      993,
      1155,
      3018,
      1178,
      2894,
      2259,
      2295,
      1115,
      1133,
      606,
      1214,
      1224,
      1221,
      1031,
      1033,
      1218,
      1213,
      1032,
      431,
    ],
    [
      2738,
      1644,
      2331,
      3163,
      2499,
      2598,
      1723,
      2852,
      2790,
      2745,
      2723,
      760,
      3013,
      2894,
      684,
      988,
      1154,
      20,
      15,
      17,
      965,
      964,
    ],
    [2597, 1645, 3133, 1716, 3073, 1713, 2971, 1178],
    [1644, 2902, 2331, 1721],
    [
      1926,
      2738,
      2804,
      2908,
      2679,
      3111,
      1626,
      406,
      407,
      405,
      2852,
      876,
      2650,
      2894,
      932,
      2269,
      1418,
    ],
    [2739, 586, 2322, 874, 3125, 1626, 774, 1902, 1853],
    [2738],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 7, 14, 15, 16, 17],
    [18, 19, 2, 20, 4, 21, 22, 23, 8, 9, 24, 11, 25, 26, 27, 14, 28, 29, 30],
  ];
}
