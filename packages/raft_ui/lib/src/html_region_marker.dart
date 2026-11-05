import 'package:flutter/material.dart';

import 'html_region_native_types.dart';
import 'raft/ui_tokens.dart';
import 'tokens/tokens.dart';
import 'theme.dart';

/// One recipe serves Flutter paint and system-native overlay adapters.
class RaftHtmlRegionMarkerRecipe {
  const RaftHtmlRegionMarkerRecipe({
    required this.rect,
    required this.fill,
    required this.border,
    required this.width,
    required this.radius,
    required this.dashed,
    required this.progress,
  });
  factory RaftHtmlRegionMarkerRecipe.resolve(
    BuildContext context,
    Rect rect, {
    bool drag = false,
    double progress = 0,
  }) {
    final t = RaftTokens.of(context);
    final strength = progress <= .35
        ? 1.0
        : progress >= 1
        ? 0.0
        : 1 - Curves.easeOut.transform((progress - .35) / .65);
    final base = t.ui[drag ? 'brand-soft' : 'info-soft'];
    return RaftHtmlRegionMarkerRecipe(
      rect: rect,
      fill: base.withValues(alpha: base.a * (drag ? .5 : strength)),
      border: t.ui['line-seam'],
      width: RaftScale.space(.25),
      radius: drag ? 0 : RaftScale.space(.5),
      dashed: drag,
      progress: progress,
    );
  }
  final Rect rect;
  final Color fill, border;
  final double width, radius, progress;
  final bool dashed;

  /// The existing CSS-equivalent three-width dashes, distributed per side.
  /// Explicit geometry keeps platform code from inventing its own dash recipe.
  List<Rect> get borderSegments {
    if (!dashed) return const [];
    final result = <Rect>[];
    void side(Offset start, Offset direction, double length, bool vertical) {
      final dash = width * 3;
      final count = ((length + dash) / (dash * 2)).floor().clamp(1, 10000);
      final gap = count > 1 ? (length - count * dash) / (count - 1) : 0.0;
      for (var i = 0; i < count; i++) {
        final o = start + direction * (i * (dash + gap));
        result.add(
          vertical
              ? Rect.fromLTWH(o.dx, o.dy, width, dash)
              : Rect.fromLTWH(o.dx, o.dy, dash, width),
        );
      }
    }

    side(rect.topLeft, const Offset(1, 0), rect.width, false);
    side(
      Offset(rect.left, rect.bottom - width),
      const Offset(1, 0),
      rect.width,
      false,
    );
    side(rect.topLeft, const Offset(0, 1), rect.height, true);
    side(
      Offset(rect.right - width, rect.top),
      const Offset(0, 1),
      rect.height,
      true,
    );
    return result;
  }

  RaftHtmlNativeRegionMarker normalized(Size host) {
    Rect normalize(Rect value) => Rect.fromLTWH(
      value.left / host.width,
      value.top / host.height,
      value.width / host.width,
      value.height / host.height,
    );
    return RaftHtmlNativeRegionMarker(
      rect: normalize(rect),
      fill: fill,
      border: border,
      strokeWidth: width,
      radius: radius,
      dashed: dashed,
      borderSegments: List.unmodifiable(
        borderSegments
            .where((rect) => rect.overlaps(Offset.zero & host))
            .map((rect) => normalize(rect.intersect(Offset.zero & host))),
      ),
      progress: progress,
    );
  }
}

class RaftHtmlRegionMarkerPainter extends CustomPainter {
  const RaftHtmlRegionMarkerPainter(this.recipe);
  final RaftHtmlRegionMarkerRecipe recipe;
  @override
  void paint(Canvas canvas, Size size) {
    final r = recipe;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    if (r.rect.overlaps(Offset.zero & size)) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(r.rect, Radius.circular(r.radius)),
        Paint()..color = r.fill,
      );
      if (r.dashed) {
        final paint = Paint()
          ..color = r.border
          ..isAntiAlias = false;
        for (final segment in r.borderSegments) {
          canvas.drawRect(segment, paint);
        }
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            r.rect.deflate(r.width / 2),
            Radius.circular(r.radius),
          ),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r.width
            ..color = r.border,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(RaftHtmlRegionMarkerPainter old) =>
      recipe.rect != old.recipe.rect ||
      recipe.fill != old.recipe.fill ||
      recipe.border != old.recipe.border ||
      recipe.width != old.recipe.width ||
      recipe.radius != old.recipe.radius ||
      recipe.dashed != old.recipe.dashed;
}
