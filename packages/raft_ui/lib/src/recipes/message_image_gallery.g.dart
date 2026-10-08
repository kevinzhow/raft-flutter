// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.5.27 dist/index.mjs (sha256 eb843b9c5ce26766),
// tailwindcss 4.2.2 with raft-ui styles.css + Web @theme overrides. Recipe `messageImageGallery`.
// ignore_for_file: type=lint

import 'recipe_runtime.dart';
import 'recipe_utilities.g.dart';

/// `count` axis of `messageImageGallery`.
enum RaftMessageImageGalleryRecipeCount {
  v1('1'),
  v2('2'),
  v3('3');

  const RaftMessageImageGalleryRecipeCount(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// `fit` axis of `messageImageGallery`.
enum RaftMessageImageGalleryRecipeFit {
  cover('cover'),
  contain('contain');

  const RaftMessageImageGalleryRecipeFit(this.css);

  /// Variant value as written in the raft-ui source.
  final String css;
}

/// Resolved slots of [RaftMessageImageGalleryRecipe].
class RaftMessageImageGalleryRecipeStyle {
  const RaftMessageImageGalleryRecipeStyle({required this.root, required this.row, required this.item, required this.media, required this.overlay, required this.preview, required this.action});

  /// Slot `root`.
  final RaftSlotStyle root;
  /// Slot `row`.
  final RaftSlotStyle row;
  /// Slot `item`.
  final RaftSlotStyle item;
  /// Slot `media`.
  final RaftSlotStyle media;
  /// Slot `overlay`.
  final RaftSlotStyle overlay;
  /// Slot `preview`.
  final RaftSlotStyle preview;
  /// Slot `action`.
  final RaftSlotStyle action;

  Map<String, RaftSlotStyle> get slots => {'root': root, 'row': row, 'item': item, 'media': media, 'overlay': overlay, 'preview': preview, 'action': action};
}

/// raft-ui recipe `messageImageGallery` (`src/components/message-attachment/message-image-gallery.recipe.ts`, index.mjs:11084).
///
/// Used by: MessageImageGallery, MessageImageGalleryAction, MessageImageGalleryItem, MessageImageGalleryMedia, MessageImageGalleryOverlay, MessageImageGalleryPreview, MessageImageGalleryRow.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftMessageImageGalleryRecipe {
  static const String recipeName = 'messageImageGallery';
  static const List<String> slotNames = ['root', 'row', 'item', 'media', 'overlay', 'preview', 'action'];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('count', ['1', '2', '3'], null, true),
    RaftRecipeAxis('single', ['true', 'false'], 'false', false),
    RaftRecipeAxis('laidOut', ['true', 'false'], null, true),
    RaftRecipeAxis('fit', ['cover', 'contain'], null, true),
    RaftRecipeAxis('theme', ['brutal', 'elegant'], null, false),
  ];

  static RaftMessageImageGalleryRecipeStyle resolve({RaftMessageImageGalleryRecipeCount? count, bool? single, bool? laidOut, RaftMessageImageGalleryRecipeFit? fit, required RaftRecipeTheme theme, RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [count?.css, single?.toString(), laidOut?.toString(), fit?.css, theme.name], states, tokens);
    return RaftMessageImageGalleryRecipeStyle(root: s[0], row: s[1], item: s[2], media: s[3], overlay: s[4], preview: s[5], action: s[6]);
  }

  /// Resolve by raw tailwind-variants props (`{'size': 'md'}`); for tooling and tests.
  static Map<String, RaftSlotStyle> resolveProps(Map<String, String?> props, {RaftRecipeStates states = RaftRecipeStates.none, RaftTokenResolver? tokens}) {
    final s = raftResolveRecipe(raftRecipeEngine, axes, _lists, _combos, [for (final a in axes) props[a.name]], states, tokens);
    return {for (var i = 0; i < slotNames.length; i++) slotNames[i]: s[i]};
  }

  /// Distinct class lists (indices into [raftRecipeUtilities]).
  static const List<List<int>> _lists = [
    [2482, 2537, 2901],
    [1717, 1698],
    [1922, 2775, 2656, 3003, 2300, 3126, 2470, 2320, 866, 876, 771, 2253, 2144, 2143],
    [862, 2890],
    [580, 2303, 1620, 2312, 2317],
    [580, 2303, 1639, 1628, 1642],
    [580, 2781, 926, 3138, 2174, 2883, 2312, 2317, 1676, 1896, 429, 864, 876, 860, 2961, 2272, 1639, 1647, 1642],
    [1922, 2775, 2656, 3003, 2300, 3126, 2470, 2320, 2818, 795, 2865, 3086, 1602, 2269, 2144],
    [580, 2303, 1639, 1628, 1644],
    [580, 2781, 926, 3138, 2174, 2883, 2312, 2317, 1676, 1896, 429, 2815, 865, 859, 2981, 2860, 680, 1147, 1112, 3068, 1602, 2240, 2276, 600, 2646, 2650, 2652, 1643],
    [1922, 2775, 2656, 3003, 2300, 3126, 2470, 2320, 407, 866, 876, 771, 2253, 2144, 2143],
    [1922, 2775, 2656, 3003, 2300, 3126, 2470, 2320, 407, 2818, 795, 2865, 3086, 1602, 2269, 2144],
    [1922, 2775, 2656, 3003, 2300, 3126, 2470, 2320, 406, 404, 866, 876, 771, 2253, 2144, 2143],
    [1922, 2775, 2656, 3003, 2300, 3126, 2470, 2320, 406, 404, 2818, 795, 2865, 3086, 1602, 2269, 2144],
    [1922, 2775, 2656, 3003, 2300, 3126, 2470, 2320, 405, 409, 866, 876, 771, 2253, 2144, 2143],
    [1922, 2775, 2656, 3003, 2300, 3126, 2470, 2320, 405, 409, 2818, 795, 2865, 3086, 1602, 2269, 2144],
    [1922, 2775, 2656, 3003, 2300, 3126, 2470, 2320, 405, 409, 407, 866, 876, 771, 2253, 2144, 2143],
    [1922, 2775, 2656, 3003, 2300, 3126, 2470, 2320, 405, 409, 407, 2818, 795, 2865, 3086, 1602, 2269, 2144],
    [1922, 2775, 2656, 3003, 2300, 3126, 2470, 2320, 405, 409, 406, 404, 866, 876, 771, 2253, 2144, 2143],
    [1922, 2775, 2656, 3003, 2300, 3126, 2470, 2320, 405, 409, 406, 404, 2818, 795, 2865, 3086, 1602, 2269, 2144],
    [1922, 2775, 2656, 3003, 866, 876, 771, 2253, 2144, 2143],
    [1922, 2775, 2656, 3003, 2818, 795, 2865, 3086, 1602, 2269, 2144],
    [1922, 2775, 2656, 3003, 407, 866, 876, 771, 2253, 2144, 2143],
    [1922, 2775, 2656, 3003, 407, 2818, 795, 2865, 3086, 1602, 2269, 2144],
    [1922, 2775, 2656, 3003, 406, 404, 866, 876, 771, 2253, 2144, 2143],
    [1922, 2775, 2656, 3003, 406, 404, 2818, 795, 2865, 3086, 1602, 2269, 2144],
    [1922, 2775, 2656, 3003, 405, 409, 866, 876, 771, 2253, 2144, 2143],
    [1922, 2775, 2656, 3003, 405, 409, 2818, 795, 2865, 3086, 1602, 2269, 2144],
    [1922, 2775, 2656, 3003, 405, 409, 407, 866, 876, 771, 2253, 2144, 2143],
    [1922, 2775, 2656, 3003, 405, 409, 407, 2818, 795, 2865, 3086, 1602, 2269, 2144],
    [1922, 2775, 2656, 3003, 405, 409, 406, 404, 866, 876, 771, 2253, 2144, 2143],
    [1922, 2775, 2656, 3003, 405, 409, 406, 404, 2818, 795, 2865, 3086, 1602, 2269, 2144],
    [1717, 1698, 1718],
    [1717, 1698, 1719],
    [1717, 1698, 1719, 2523],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6], [0, 1, 7, 3, 4, 8, 9], [0, 1, 10, 3, 4, 5, 6], [0, 1, 11, 3, 4, 8, 9], [0, 1, 12, 3, 4, 5, 6], [0, 1, 13, 3, 4, 8, 9], [0, 1, 14, 3, 4, 5, 6], [0, 1, 15, 3, 4, 8, 9], [0, 1, 16, 3, 4, 5, 6], [0, 1, 17, 3, 4, 8, 9], [0, 1, 18, 3, 4, 5, 6], [0, 1, 19, 3, 4, 8, 9], [0, 1, 2, 3, 4, 5, 6], [0, 1, 7, 3, 4, 8, 9], [0, 1, 10, 3, 4, 5, 6], [0, 1, 11, 3, 4, 8, 9],
    [0, 1, 12, 3, 4, 5, 6], [0, 1, 13, 3, 4, 8, 9], [0, 1, 20, 3, 4, 5, 6], [0, 1, 21, 3, 4, 8, 9], [0, 1, 22, 3, 4, 5, 6], [0, 1, 23, 3, 4, 8, 9], [0, 1, 24, 3, 4, 5, 6], [0, 1, 25, 3, 4, 8, 9], [0, 1, 26, 3, 4, 5, 6], [0, 1, 27, 3, 4, 8, 9], [0, 1, 28, 3, 4, 5, 6], [0, 1, 29, 3, 4, 8, 9], [0, 1, 30, 3, 4, 5, 6], [0, 1, 31, 3, 4, 8, 9], [0, 1, 20, 3, 4, 5, 6], [0, 1, 21, 3, 4, 8, 9],
    [0, 1, 22, 3, 4, 5, 6], [0, 1, 23, 3, 4, 8, 9], [0, 1, 24, 3, 4, 5, 6], [0, 1, 25, 3, 4, 8, 9], [0, 32, 2, 3, 4, 5, 6], [0, 32, 7, 3, 4, 8, 9], [0, 32, 10, 3, 4, 5, 6], [0, 32, 11, 3, 4, 8, 9], [0, 32, 12, 3, 4, 5, 6], [0, 32, 13, 3, 4, 8, 9], [0, 32, 14, 3, 4, 5, 6], [0, 32, 15, 3, 4, 8, 9], [0, 32, 16, 3, 4, 5, 6], [0, 32, 17, 3, 4, 8, 9], [0, 32, 18, 3, 4, 5, 6], [0, 32, 19, 3, 4, 8, 9],
    [0, 32, 2, 3, 4, 5, 6], [0, 32, 7, 3, 4, 8, 9], [0, 32, 10, 3, 4, 5, 6], [0, 32, 11, 3, 4, 8, 9], [0, 32, 12, 3, 4, 5, 6], [0, 32, 13, 3, 4, 8, 9], [0, 32, 20, 3, 4, 5, 6], [0, 32, 21, 3, 4, 8, 9], [0, 32, 22, 3, 4, 5, 6], [0, 32, 23, 3, 4, 8, 9], [0, 32, 24, 3, 4, 5, 6], [0, 32, 25, 3, 4, 8, 9], [0, 32, 26, 3, 4, 5, 6], [0, 32, 27, 3, 4, 8, 9], [0, 32, 28, 3, 4, 5, 6], [0, 32, 29, 3, 4, 8, 9],
    [0, 32, 30, 3, 4, 5, 6], [0, 32, 31, 3, 4, 8, 9], [0, 32, 20, 3, 4, 5, 6], [0, 32, 21, 3, 4, 8, 9], [0, 32, 22, 3, 4, 5, 6], [0, 32, 23, 3, 4, 8, 9], [0, 32, 24, 3, 4, 5, 6], [0, 32, 25, 3, 4, 8, 9], [0, 33, 2, 3, 4, 5, 6], [0, 33, 7, 3, 4, 8, 9], [0, 33, 10, 3, 4, 5, 6], [0, 33, 11, 3, 4, 8, 9], [0, 33, 12, 3, 4, 5, 6], [0, 33, 13, 3, 4, 8, 9], [0, 33, 14, 3, 4, 5, 6], [0, 33, 15, 3, 4, 8, 9],
    [0, 33, 16, 3, 4, 5, 6], [0, 33, 17, 3, 4, 8, 9], [0, 33, 18, 3, 4, 5, 6], [0, 33, 19, 3, 4, 8, 9], [0, 33, 2, 3, 4, 5, 6], [0, 33, 7, 3, 4, 8, 9], [0, 33, 10, 3, 4, 5, 6], [0, 33, 11, 3, 4, 8, 9], [0, 33, 12, 3, 4, 5, 6], [0, 33, 13, 3, 4, 8, 9], [0, 33, 20, 3, 4, 5, 6], [0, 33, 21, 3, 4, 8, 9], [0, 33, 22, 3, 4, 5, 6], [0, 33, 23, 3, 4, 8, 9], [0, 33, 24, 3, 4, 5, 6], [0, 33, 25, 3, 4, 8, 9],
    [0, 33, 26, 3, 4, 5, 6], [0, 33, 27, 3, 4, 8, 9], [0, 33, 28, 3, 4, 5, 6], [0, 33, 29, 3, 4, 8, 9], [0, 33, 30, 3, 4, 5, 6], [0, 33, 31, 3, 4, 8, 9], [0, 33, 20, 3, 4, 5, 6], [0, 33, 21, 3, 4, 8, 9], [0, 33, 22, 3, 4, 5, 6], [0, 33, 23, 3, 4, 8, 9], [0, 33, 24, 3, 4, 5, 6], [0, 33, 25, 3, 4, 8, 9], [0, 34, 2, 3, 4, 5, 6], [0, 34, 7, 3, 4, 8, 9], [0, 34, 10, 3, 4, 5, 6], [0, 34, 11, 3, 4, 8, 9],
    [0, 34, 12, 3, 4, 5, 6], [0, 34, 13, 3, 4, 8, 9], [0, 34, 14, 3, 4, 5, 6], [0, 34, 15, 3, 4, 8, 9], [0, 34, 16, 3, 4, 5, 6], [0, 34, 17, 3, 4, 8, 9], [0, 34, 18, 3, 4, 5, 6], [0, 34, 19, 3, 4, 8, 9], [0, 34, 2, 3, 4, 5, 6], [0, 34, 7, 3, 4, 8, 9], [0, 34, 10, 3, 4, 5, 6], [0, 34, 11, 3, 4, 8, 9], [0, 34, 12, 3, 4, 5, 6], [0, 34, 13, 3, 4, 8, 9], [0, 34, 20, 3, 4, 5, 6], [0, 34, 21, 3, 4, 8, 9],
    [0, 34, 22, 3, 4, 5, 6], [0, 34, 23, 3, 4, 8, 9], [0, 34, 24, 3, 4, 5, 6], [0, 34, 25, 3, 4, 8, 9], [0, 34, 26, 3, 4, 5, 6], [0, 34, 27, 3, 4, 8, 9], [0, 34, 28, 3, 4, 5, 6], [0, 34, 29, 3, 4, 8, 9], [0, 34, 30, 3, 4, 5, 6], [0, 34, 31, 3, 4, 8, 9], [0, 34, 20, 3, 4, 5, 6], [0, 34, 21, 3, 4, 8, 9], [0, 34, 22, 3, 4, 5, 6], [0, 34, 23, 3, 4, 8, 9], [0, 34, 24, 3, 4, 5, 6], [0, 34, 25, 3, 4, 8, 9],
  ];
}
