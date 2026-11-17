import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'human_avatar_art.dart';
import 'human_avatar_recipe.dart';

/// A person's built pixel avatar (`pixel-human:v1:...`) filling its frame
/// (Web `HumanPixelAvatar`): the whole picture at every size, scaled
/// nearest-neighbour (Web: crisp-edge SVG in an `image-rendering: pixelated`
/// img, `rounded-[2px]`). The image is built synchronously on first use and
/// kept per look, so the first frame is final. A value that is not a built
/// avatar shows [fallback].
class RaftHumanPixelAvatar extends StatelessWidget {
  /// Web `rounded-[2px]` on the img.
  static const _imageRadius = 2.0;

  const RaftHumanPixelAvatar({
    super.key,
    required this.avatarUrl,
    this.fallback,
  });

  final String avatarUrl;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final recipe = RaftHumanAvatarRecipe.read(avatarUrl);
    if (recipe == null) return fallback ?? const SizedBox.shrink();
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_imageRadius),
        child: CustomPaint(
          painter: RaftHumanPixelPainter(raftHumanAvatarImage(recipe)),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// Draws [image] over the whole canvas, nearest-neighbour.
class RaftHumanPixelPainter extends CustomPainter {
  const RaftHumanPixelPainter(this.image);
  final ui.Image image;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Offset.zero & size,
      Paint()
        ..filterQuality = FilterQuality.none
        ..isAntiAlias = false,
    );
  }

  @override
  bool shouldRepaint(RaftHumanPixelPainter old) => old.image != image;
}

const _cacheCapacity = 128;
final _images = <String, ui.Image>{};

/// Disposes every kept image. The app never calls it (a look's pixels never
/// change); tests do after each test so the leak report stays about the test.
void raftReleaseHumanAvatarImages() {
  for (final image in _images.values) {
    image.dispose();
  }
  _images.clear();
}

/// The 112 px image of [recipe] (one per look, the last [_cacheCapacity]
/// kept). Rows of one colour are one rect, as in Web's SVG.
ui.Image raftHumanAvatarImage(RaftHumanAvatarRecipe recipe) {
  final key = recipe.serialize();
  final hit = _images.remove(key);
  if (hit != null) return _images[key] = hit;
  final art = composeRaftHumanAvatar(recipe);
  final size = art.size;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final paint = Paint()..isAntiAlias = false;
  canvas.drawRect(
    Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
    paint..color = Color(art.background),
  );
  for (var y = 0; y < size; y++) {
    var x = 0;
    while (x < size) {
      final color = art.pixels[y * size + x];
      var end = x + 1;
      while (end < size && art.pixels[y * size + end] == color) {
        end++;
      }
      if (color != 0) {
        canvas.drawRect(
          Rect.fromLTRB(x.toDouble(), y.toDouble(), end.toDouble(), y + 1.0),
          paint..color = Color(color),
        );
      }
      x = end;
    }
  }
  final picture = recorder.endRecording();
  final image = picture.toImageSync(size, size);
  picture.dispose();
  _images[key] = image;
  if (_images.length > _cacheCapacity) _images.remove(_images.keys.first);
  return image;
}

/// The art's own hair colour for a `hairColor` option id, for the builder's
/// swatches.
Color raftHumanAvatarHairColor(String hairColorId) =>
    Color(raftHumanAvatarHairSwatch(hairColorId));
