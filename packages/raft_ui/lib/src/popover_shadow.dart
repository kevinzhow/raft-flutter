import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:raft_theme/recipes.dart';

/// Applies the floating surface's rectangular blur coverage to 8-bit
/// premultiplied channels, as Chromium does for CSS box shadows.
class RaftPopoverShadowPainter extends RaftOuterShadowPainter {
  const RaftPopoverShadowPainter(
    super.shadows,
    super.radius, {
    required super.devicePixelRatio,
    required this.origin,
  }) : super(cssGeometry: true);

  final Offset? Function() origin;

  @override
  void paint(Canvas canvas, Size size) {
    final global = origin();
    final scale = devicePixelRatio;
    if (global == null || !scale.isFinite || scale <= 0) {
      super.paint(canvas, size);
      return;
    }
    int snap(double value) => (value * scale + .5).floor();
    final left = snap(global.dx);
    final top = snap(global.dy);
    final right = snap(global.dx + size.width);
    final bottom = snap(global.dy + size.height);
    final snappedSize = Size((right - left) / scale, (bottom - top) / scale);
    final rect = Offset.zero & snappedSize;
    canvas.save();
    canvas.translate(left / scale - global.dx, top / scale - global.dy);
    final box = radius.toRRect(rect).scaleRadii();
    for (final shadow in shadows) {
      if (shadow.color.a == 0) continue;
      final spread = box.inflate(shadow.spreadRadius);
      if (spread.isEmpty) continue;
      if (shadow.blurRadius > 0 && spread.isRect) {
        canvas.save();
        canvas.clipPath(
          Path()
            ..fillType = PathFillType.evenOdd
            ..addRect(rect.inflate(1e4))
            ..addRRect(box),
        );
        _paintRectShadow(
          canvas,
          spread.outerRect.shift(shadow.offset),
          shadow,
          scale,
        );
        canvas.restore();
      } else {
        RaftOuterShadowPainter(
          [shadow],
          radius,
          cssGeometry: true,
        ).paint(canvas, snappedSize);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(RaftOuterShadowPainter old) =>
      old is! RaftPopoverShadowPainter || super.shouldRepaint(old);
}

void _paintRectShadow(
  Canvas canvas,
  Rect rect,
  BoxShadow shadow,
  double scale,
) {
  final sigma = shadow.blurSigma * scale;
  final x = _blurBands(rect.left * scale, rect.right * scale, sigma);
  final y = _blurBands(rect.top * scale, rect.bottom * scale, sigma);
  final ink = shadow.color;
  final alpha = (ink.a * 255).round();
  final red = (ink.r * alpha).round();
  final green = (ink.g * alpha).round();
  final blue = (ink.b * alpha).round();
  final paths = <int, Path>{};
  for (final row in y) {
    for (final column in x) {
      final coverage = (row.coverage * column.coverage + 127) ~/ 255 + 1;
      final a = (alpha * coverage) >> 8;
      if (a == 0) continue;
      int channel(int premultiplied) =>
          (((premultiplied * coverage) >> 8) * 255 / a).round();
      final argb =
          (a << 24) |
          (channel(red) << 16) |
          (channel(green) << 8) |
          channel(blue);
      paths
          .putIfAbsent(argb, Path.new)
          .addRect(
            Rect.fromLTRB(
              column.start / scale,
              row.start / scale,
              column.end / scale,
              row.end / scale,
            ),
          );
    }
  }
  final paint = Paint()..isAntiAlias = false;
  for (final MapEntry(:key, :value) in paths.entries) {
    canvas.drawPath(value, paint..color = Color(key));
  }
}

typedef _BlurBand = ({int start, int end, int coverage});

List<_BlurBand> _blurBands(double start, double end, double sigma) {
  final extent = (6 * sigma).ceil();
  final pad = extent ~/ 2;
  final first = (start - pad + .5).floor();
  final last = (end + pad + .5).floor();
  final length = last - first - extent;
  final center = (extent & ~1) - 1;
  final bands = <_BlurBand>[];
  for (var pixel = first; pixel < last; pixel++) {
    final unit = (pixel - first + .5) / (2 * sigma);
    final distance = (2 * (pixel - first) + 1 - (last - first)).abs();
    final offset = (distance - (length - center)) >> 1;
    final edge = (offset + .5 - pad) / (2 * sigma);
    final coverage = length < extent
        ? (255 *
                  (_boxIntegral(unit - 1.5) -
                      _boxIntegral(unit - 1.5 - length / (2 * sigma))))
              .floor()
        : offset <= 0
        ? 255
        : 255 - (255 * _boxIntegral(edge)).floor();
    if (coverage <= 0) continue;
    if (bands.isNotEmpty &&
        bands.last.coverage == coverage &&
        bands.last.end == pixel) {
      final previous = bands.removeLast();
      bands.add((start: previous.start, end: pixel + 1, coverage: coverage));
    } else {
      bands.add((start: pixel, end: pixel + 1, coverage: coverage));
    }
  }
  return bands;
}

double _boxIntegral(double x) {
  final distance = x.abs();
  final end = math.max(0.0, 1.5 - distance);
  final tail = distance <= .5
      ? .5 - .75 * distance + distance * distance * distance / 3
      : end * end * end / 6;
  return x < 0 ? tail : 1 - tail;
}
