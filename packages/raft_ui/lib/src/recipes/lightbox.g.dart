// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `lightbox`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// Resolved slots of [RaftLightboxRecipe].
class RaftLightboxRecipeStyle {
  const RaftLightboxRecipeStyle({required this.backdrop, required this.content, required this.header, required this.toolbar, required this.headerMeta, required this.headerLabel, required this.title, required this.actions, required this.stage, required this.media, required this.navigationButton, required this.infoDock, required this.infoBar, required this.infoTitle, required this.infoActions, required this.thumbnailStrip, required this.thumbnail, required this.thumbnailOverlay, required this.close});

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

  Map<String, RaftSlotStyle> get slots => {'backdrop': backdrop, 'content': content, 'header': header, 'toolbar': toolbar, 'headerMeta': headerMeta, 'headerLabel': headerLabel, 'title': title, 'actions': actions, 'stage': stage, 'media': media, 'navigationButton': navigationButton, 'infoDock': infoDock, 'infoBar': infoBar, 'infoTitle': infoTitle, 'infoActions': infoActions, 'thumbnailStrip': thumbnailStrip, 'thumbnail': thumbnail, 'thumbnailOverlay': thumbnailOverlay, 'close': close};
}

/// raft-ui recipe `lightbox` (`src/components/lightbox/lightbox.tsx`, index.mjs:5355).
///
/// Used by: LightboxActions, LightboxClose, LightboxContent, LightboxHeader, LightboxHeaderLabel, LightboxHeaderMeta, LightboxInfoActions, LightboxInfoBar, LightboxInfoDock, LightboxInfoTitle, LightboxMedia, LightboxNavigationButton, LightboxStage, LightboxThumbnail, LightboxThumbnailStrip, LightboxTitle, LightboxToolbar.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftLightboxRecipe {
  static const String recipeName = 'lightbox';
  static const List<String> slotNames = ['backdrop', 'content', 'header', 'toolbar', 'headerMeta', 'headerLabel', 'title', 'actions', 'stage', 'media', 'navigationButton', 'infoDock', 'infoBar', 'infoTitle', 'infoActions', 'thumbnailStrip', 'thumbnail', 'thumbnailOverlay', 'close'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftLightboxRecipeStyle resolve({required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [theme.name], states, tokens);
    return RaftLightboxRecipeStyle(backdrop: s[0], content: s[1], header: s[2], toolbar: s[3], headerMeta: s[4], headerLabel: s[5], title: s[6], actions: s[7], stage: s[8], media: s[9], navigationButton: s[10], infoDock: s[11], infoBar: s[12], infoTitle: s[13], infoActions: s[14], thumbnailStrip: s[15], thumbnail: s[16], thumbnailOverlay: s[17], close: s[18]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [1619, 2303, 3144, 819, 1432],
    [2716, 1619, 2303, 3145, 1620, 1622, 1432, 117, 116, 121, 120, 118],
    [2715, 2867, 1620, 2312, 1700, 2685, 2743, 2707, 2729, 850, 2860],
    [2715, 2867, 1620, 2312, 1700, 1974, 2744, 2706, 2728, 78, 76, 79, 77, 875, 876, 856, 2860],
    [1620, 2574, 1621, 2312, 1697],
    [2301, 2867, 2312, 2750, 2761, 2918, 2344, 1684, 3096, 3055, 866, 876, 831, 1687, 2956],
    [2574, 1621, 3092, 3017, 2337, 2732, 2681, 1687, 1692, 2956],
    [1620, 2867, 2312, 1697],
    [2716, 2775, 1620, 2560, 1621, 2312, 2317, 2656],
    [2715, 2367, 2477, 865, 850, 2860],
    [2715, 580, 3138, 2301, 2312, 2317, 866, 900, 825, 2976, 2863, 3068, 1602, 2646, 2650, 2652, 1643, 1196, 425, 427, 2885, 2819, 2223, 1206, 434],
    [2716, 580, 2786, 928, 2353, 3138, 1620, 2317],
    [2715, 1620, 2312, 825, 2976, 3122, 2478, 2575, 1698, 2819, 866, 900, 2761, 2719, 2700, 2863, 379],
    [2574, 1621, 3092, 1687, 1684, 3032, 2987],
    [2716, 580, 2780, 930, 2350, 3138, 1620, 2312, 2317, 1697],
    [1925, 2715, 2775, 2873, 2656, 3070, 1602, 408, 409, 407, 866, 920, 2630, 2845, 2249, 2265, 2266, 1392, 1395, 1403, 1406],
    [2716, 580, 2303, 3084, 1602, 2174],
    [2715, 431],
    [1619, 2303, 3144, 1432, 756, 679],
    [2716, 1619, 2303, 3145, 1620, 1622, 1432, 117, 116, 121, 120, 118, 119, 223, 222],
    [2715, 2867, 1620, 2312, 1700, 1974, 2744, 2706, 2728, 78, 76, 79, 77, 873, 896, 825, 2860],
    [2301, 2867, 2312, 2750, 2761, 2918, 2344, 1684, 3096, 3055, 2815, 864, 896, 795, 1691, 2981],
    [2574, 1621, 3092, 3017, 2337, 2732, 2681, 1691, 1688, 2976],
    [1620, 2867, 2312, 1698],
    [2715, 580, 3138, 2301, 2312, 2317, 900, 3068, 1602, 2646, 2650, 2652, 1643, 1196, 425, 427, 2885, 2815, 865, 859, 680, 973, 1136, 2981, 1159, 2860, 2240, 2276, 1095, 1113, 600, 1195, 1205, 1202, 1011, 1013, 1199, 1194, 1012, 433],
    [2715, 1620, 2312, 3122, 2478, 2575, 1698, 2822, 2761, 2719, 2700, 754, 2976, 2860, 678, 968, 1135, 20, 15, 17, 945, 944],
    [2574, 1621, 3092, 1691, 3032, 1688, 2933, 1159],
    [1620, 2867, 2312, 1696],
    [1925, 2715, 2775, 2873, 2656, 3070, 1602, 408, 409, 407, 2822, 864, 2627, 2860, 919, 2250, 1396],
    [2716, 580, 2303, 862, 3084, 1602, 768, 1897, 1828],
    [2715],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 7, 14, 15, 16, 17], [18, 19, 2, 20, 4, 21, 22, 23, 8, 9, 24, 11, 25, 26, 27, 14, 28, 29, 30],
  ];
}
