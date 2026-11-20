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
  int snap(double value) => (value * scale + .5).floor();
  final left = snap(rect.left);
  final right = snap(rect.right);
  final top = snap(rect.top);
  final bottom = snap(rect.bottom);
  final extent = (6 * sigma).ceil();
  final minimumAnalyticSpan = 2 * (extent ~/ 2) + 3;
  final ink = shadow.color;
  final tinted = ink.r != 0 || ink.g != 0 || ink.b != 0;
  final List<_BlurBand> x;
  final List<_BlurBand> y;
  final int Function(int, int) mask;
  if (scale > 1 &&
      tinted &&
      (right - left < minimumAnalyticSpan ||
          bottom - top < minimumAnalyticSpan)) {
    final blur = _BoxBlurKernel(sigma);
    x = blur.bands(left, right, blur.quantizeAlpha);
    y = blur.bands(top, bottom);
    mask = blur.applyVertical;
  } else {
    x = _analyticBands(left, right, extent, sigma);
    y = _analyticBands(top, bottom, extent, sigma);
    mask = (horizontal, vertical) => (horizontal * vertical + 127) ~/ 255;
  }
  final alpha = (ink.a * 255).round();
  final red = (ink.r * alpha).round();
  final green = (ink.g * alpha).round();
  final blue = (ink.b * alpha).round();
  final paths = <int, Path>{};
  for (final row in y) {
    for (final column in x) {
      final coverage = mask(column.coverage, row.coverage) + 1;
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

List<_BlurBand> _analyticBands(int start, int end, int extent, double sigma) {
  final padding = extent ~/ 2;
  final length = end - start - extent % 2;
  final first = start - padding;
  return _coverageBands(first, end + padding, (pixel) {
    if (length < extent) {
      final unit = (pixel - first + .5) / (2 * sigma) - 1.5;
      return (255 *
              (_boxIntegral(unit) - _boxIntegral(unit - length / (2 * sigma))))
          .floor();
    }
    final distance = (2 * pixel + 1 - start - end).abs();
    final center = length - (2 * padding - 1);
    final offset = (distance - center) >> 1;
    if (offset <= 0) return 255;
    final edge = (offset + .5 - padding) / (2 * sigma);
    return 255 - (255 * _boxIntegral(edge)).floor();
  });
}

class _BoxBlurKernel {
  _BoxBlurKernel(double sigma) {
    final window = math.max(
      1,
      (math.min(sigma, 135) * 3 * math.sqrt(2 * math.pi) / 4).round(),
    );
    var integral = [0, 1];
    for (final size in [window, window, window.isEven ? window + 1 : window]) {
      final source = integral;
      final sourceEnd = source.length - 1;
      integral = List.filled(source.length + size - 1, 0);
      for (var index = 1; index < integral.length; index++) {
        final sum =
            source[math.min(index, sourceEnd)] -
            source[math.max(index - size, 0)];
        integral[index] = integral[index - 1] + sum;
      }
    }
    _integral = integral;
    _radius = (integral.length - 1) ~/ 2;
    _weight = (_scale / integral.last).round();
  }

  static const _scale = 0x100000000;
  late final List<int> _integral;
  late final int _radius;
  late final int _weight;

  int quantizeAlpha(int sum) => applyVertical(255, sum);

  int applyVertical(int alpha, int sum) =>
      (alpha * sum * _weight + _scale ~/ 2) ~/ _scale;

  List<_BlurBand> bands(int start, int end, [int Function(int)? quantize]) =>
      _coverageBands(start - _radius, end + _radius, (pixel) {
        int integralAt(int edge) =>
            _integral[(pixel - edge + _radius + 1).clamp(
              0,
              _integral.length - 1,
            )];
        final sum = integralAt(start) - integralAt(end);
        return quantize?.call(sum) ?? sum;
      });
}

List<_BlurBand> _coverageBands(
  int first,
  int last,
  int Function(int) coverageAt,
) {
  final bands = <_BlurBand>[];
  for (var pixel = first; pixel < last; pixel++) {
    final coverage = coverageAt(pixel);
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
