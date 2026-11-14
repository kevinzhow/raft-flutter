// GENERATED — do not edit. Regenerate with `tool/recipes/run`.
// Source: raft-ui 0.95.3 dist/index.mjs (sha256 63bb2df77b8bd7a2),
// tailwindcss 4.3.3 with raft-ui styles.css + Web @theme overrides. Recipe `messageImageGallery`.
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
  const RaftMessageImageGalleryRecipeStyle({
    required this.root,
    required this.row,
    required this.item,
    required this.media,
    required this.overlay,
    required this.preview,
    required this.action,
  });

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

  Map<String, RaftSlotStyle> get slots => {
    'root': root,
    'row': row,
    'item': item,
    'media': media,
    'overlay': overlay,
    'preview': preview,
    'action': action,
  };
}

/// raft-ui recipe `messageImageGallery` (`dist/components/message-attachment/message-image-gallery.recipe.mjs`, index.mjs:13989).
///
/// Used by: MessageImageGallery, MessageImageGalleryAction, MessageImageGalleryItem, MessageImageGalleryMedia, MessageImageGalleryOverlay, MessageImageGalleryPreview, MessageImageGalleryRow.
///
/// Class lists are the exact tailwind-variants + tailwind-merge output for
/// every variant combination; [resolve] applies the CSS cascade for [states].
abstract final class RaftMessageImageGalleryRecipe {
  static const String recipeName = 'messageImageGallery';
  static const List<String> slotNames = [
    'root',
    'row',
    'item',
    'media',
    'overlay',
    'preview',
    'action',
  ];
  static const List<RaftRecipeAxis> axes = [
    RaftRecipeAxis('count', ['1', '2', '3'], null, true),
    RaftRecipeAxis('single', ['true', 'false'], 'false', false),
    RaftRecipeAxis('laidOut', ['true', 'false'], null, true),
    RaftRecipeAxis('fit', ['cover', 'contain'], null, true),
  ];

  static RaftMessageImageGalleryRecipeStyle resolve({
    RaftMessageImageGalleryRecipeCount? count,
    bool? single,
    bool? laidOut,
    RaftMessageImageGalleryRecipeFit? fit,
    RaftRecipeStates states = RaftRecipeStates.none,
    RaftTokenResolver? tokens,
  }) {
    final s = raftResolveRecipe(
      raftRecipeEngine,
      axes,
      _lists,
      _combos,
      [count?.css, single?.toString(), laidOut?.toString(), fit?.css],
      states,
      tokens,
      recipeName: recipeName,
      slotNames: slotNames,
    );
    return RaftMessageImageGalleryRecipeStyle(
      root: s[0],
      row: s[1],
      item: s[2],
      media: s[3],
      overlay: s[4],
      preview: s[5],
      action: s[6],
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
    [197, 2725, 1978, 2541],
    [1489, 1464],
    [1608, 2433, 2252, 2613, 939, 953, 895, 1846, 2724, 1963, 1872, 2462],
    [937, 2538],
    [691, 1849, 1400, 1864, 1869, 917],
    [691, 1849, 2675, 1372, 1787, 2247, 1421, 1422],
    [
      691,
      2747,
      1776,
      1864,
      1869,
      1447,
      1583,
      2443,
      973,
      2522,
      2461,
      941,
      955,
      911,
      2598,
      1794,
      699,
      2247,
      1439,
      478,
    ],
    [1608, 2433, 2252, 2613, 939, 953, 895, 1846, 2724, 1963, 1872, 2462, 430],
    [
      1608,
      2433,
      2252,
      2613,
      939,
      953,
      895,
      1846,
      2724,
      1963,
      1872,
      2462,
      429,
      427,
    ],
    [
      1608,
      2433,
      2252,
      2613,
      939,
      953,
      895,
      1846,
      2724,
      1963,
      1872,
      2462,
      428,
      432,
    ],
    [
      1608,
      2433,
      2252,
      2613,
      939,
      953,
      895,
      1846,
      2724,
      1963,
      1872,
      2462,
      428,
      432,
      430,
    ],
    [
      1608,
      2433,
      2252,
      2613,
      939,
      953,
      895,
      1846,
      2724,
      1963,
      1872,
      2462,
      428,
      432,
      429,
      427,
    ],
    [1608, 2433, 2252, 2613, 2463, 939, 953, 895],
    [1608, 2433, 2252, 2613, 2463, 939, 953, 895, 430],
    [1608, 2433, 2252, 2613, 2463, 939, 953, 895, 429, 427],
    [1608, 2433, 2252, 2613, 2463, 939, 953, 895, 428, 432],
    [1608, 2433, 2252, 2613, 2463, 939, 953, 895, 428, 432, 430],
    [1608, 2433, 2252, 2613, 2463, 939, 953, 895, 428, 432, 429, 427],
    [1489, 1464, 1490],
    [1489, 1464, 1491],
    [1489, 1464, 1492],
  ];

  /// Per combination (mixed radix over [axes]): class list per slot.
  static const List<List<int>> _combos = [
    [0, 1, 2, 3, 4, 5, 6],
    [0, 1, 7, 3, 4, 5, 6],
    [0, 1, 8, 3, 4, 5, 6],
    [0, 1, 9, 3, 4, 5, 6],
    [0, 1, 10, 3, 4, 5, 6],
    [0, 1, 11, 3, 4, 5, 6],
    [0, 1, 2, 3, 4, 5, 6],
    [0, 1, 7, 3, 4, 5, 6],
    [0, 1, 8, 3, 4, 5, 6],
    [0, 1, 12, 3, 4, 5, 6],
    [0, 1, 13, 3, 4, 5, 6],
    [0, 1, 14, 3, 4, 5, 6],
    [0, 1, 15, 3, 4, 5, 6],
    [0, 1, 16, 3, 4, 5, 6],
    [0, 1, 17, 3, 4, 5, 6],
    [0, 1, 12, 3, 4, 5, 6],
    [0, 1, 13, 3, 4, 5, 6],
    [0, 1, 14, 3, 4, 5, 6],
    [0, 18, 2, 3, 4, 5, 6],
    [0, 18, 7, 3, 4, 5, 6],
    [0, 18, 8, 3, 4, 5, 6],
    [0, 18, 9, 3, 4, 5, 6],
    [0, 18, 10, 3, 4, 5, 6],
    [0, 18, 11, 3, 4, 5, 6],
    [0, 18, 2, 3, 4, 5, 6],
    [0, 18, 7, 3, 4, 5, 6],
    [0, 18, 8, 3, 4, 5, 6],
    [0, 18, 12, 3, 4, 5, 6],
    [0, 18, 13, 3, 4, 5, 6],
    [0, 18, 14, 3, 4, 5, 6],
    [0, 18, 15, 3, 4, 5, 6],
    [0, 18, 16, 3, 4, 5, 6],
    [0, 18, 17, 3, 4, 5, 6],
    [0, 18, 12, 3, 4, 5, 6],
    [0, 18, 13, 3, 4, 5, 6],
    [0, 18, 14, 3, 4, 5, 6],
    [0, 19, 2, 3, 4, 5, 6],
    [0, 19, 7, 3, 4, 5, 6],
    [0, 19, 8, 3, 4, 5, 6],
    [0, 19, 9, 3, 4, 5, 6],
    [0, 19, 10, 3, 4, 5, 6],
    [0, 19, 11, 3, 4, 5, 6],
    [0, 19, 2, 3, 4, 5, 6],
    [0, 19, 7, 3, 4, 5, 6],
    [0, 19, 8, 3, 4, 5, 6],
    [0, 19, 12, 3, 4, 5, 6],
    [0, 19, 13, 3, 4, 5, 6],
    [0, 19, 14, 3, 4, 5, 6],
    [0, 19, 15, 3, 4, 5, 6],
    [0, 19, 16, 3, 4, 5, 6],
    [0, 19, 17, 3, 4, 5, 6],
    [0, 19, 12, 3, 4, 5, 6],
    [0, 19, 13, 3, 4, 5, 6],
    [0, 19, 14, 3, 4, 5, 6],
    [0, 20, 2, 3, 4, 5, 6],
    [0, 20, 7, 3, 4, 5, 6],
    [0, 20, 8, 3, 4, 5, 6],
    [0, 20, 9, 3, 4, 5, 6],
    [0, 20, 10, 3, 4, 5, 6],
    [0, 20, 11, 3, 4, 5, 6],
    [0, 20, 2, 3, 4, 5, 6],
    [0, 20, 7, 3, 4, 5, 6],
    [0, 20, 8, 3, 4, 5, 6],
    [0, 20, 12, 3, 4, 5, 6],
    [0, 20, 13, 3, 4, 5, 6],
    [0, 20, 14, 3, 4, 5, 6],
    [0, 20, 15, 3, 4, 5, 6],
    [0, 20, 16, 3, 4, 5, 6],
    [0, 20, 17, 3, 4, 5, 6],
    [0, 20, 12, 3, 4, 5, 6],
    [0, 20, 13, 3, 4, 5, 6],
    [0, 20, 14, 3, 4, 5, 6],
  ];
}
