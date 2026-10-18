// Pixel-level vertical alignment of glyph ink.
//
// `vertical_alignment.dart` compares laid-out boxes. That cannot see the
// "text sits low in its chip" bug: a CJK label's line box can be exactly
// centred while the glyphs inside it are 2 logical px lower (the font's ascent
// and descent are not symmetric about the ink). This helper rasterises the
// capture boundary and measures where the ink really is.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// A rasterised [RepaintBoundary] to query the ink of regions of.
class InkSnapshot {
  InkSnapshot._(this._rgba, this._width, this._height, this.ratio, this.png);

  final Uint8List _rgba;
  final int _width, _height;

  /// The capture as a PNG, to look at.
  final Uint8List png;

  /// Device pixels per logical pixel of the capture.
  final double ratio;

  /// Captures the boundary behind [key] at [ratio] device px per logical px.
  static Future<InkSnapshot> capture(
    WidgetTester t,
    GlobalKey key, {
    double ratio = 4,
  }) async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    return (await t.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: ratio);
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      final snapshot = InkSnapshot._(
        data!.buffer.asUint8List(),
        image.width,
        image.height,
        ratio,
        png!.buffer.asUint8List(),
      );
      image.dispose();
      return snapshot;
    }))!;
  }

  int _pixel(int x, int y) {
    final i = (y * _width + x) * 4;
    return (_rgba[i] << 24) |
        (_rgba[i + 1] << 16) |
        (_rgba[i + 2] << 8) |
        _rgba[i + 3];
  }

  /// Bounding box (logical px, in the boundary's coordinates) of the pixels in
  /// [region] that differ from the region's dominant colour (its background),
  /// or null when the region is empty of ink.
  Rect? inkIn(Rect region, {double relative = .3}) {
    final x0 = (region.left * ratio).floor().clamp(0, _width - 1);
    final x1 = (region.right * ratio).ceil().clamp(x0 + 1, _width);
    final y0 = (region.top * ratio).floor().clamp(0, _height - 1);
    final y1 = (region.bottom * ratio).ceil().clamp(y0 + 1, _height);
    final counts = <int, int>{};
    for (var y = y0; y < y1; y++) {
      for (var x = x0; x < x1; x++) {
        counts.update(_pixel(x, y), (n) => n + 1, ifAbsent: () => 1);
      }
    }
    final background = counts.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
    int ch(int p, int shift) => (p >> shift) & 0xff;
    int distance(int p) =>
        (ch(p, 24) - ch(background, 24)).abs() +
        (ch(p, 16) - ch(background, 16)).abs() +
        (ch(p, 8) - ch(background, 8)).abs();
    // Ink is whatever is a good part of the way from the background to the
    // most contrasting pixel of the region, so pale text (muted grey on white)
    // and black text are measured alike.
    var strongest = 0;
    for (var y = y0; y < y1; y++) {
      for (var x = x0; x < x1; x++) {
        final d = distance(_pixel(x, y));
        if (d > strongest) strongest = d;
      }
    }
    if (strongest < 48) return null;
    final threshold = strongest * relative;
    int? top, bottom, left, right;
    for (var y = y0; y < y1; y++) {
      for (var x = x0; x < x1; x++) {
        if (distance(_pixel(x, y)) < threshold) continue;
        top = top == null || y < top ? y : top;
        bottom = bottom == null || y > bottom ? y : bottom;
        left = left == null || x < left ? x : left;
        right = right == null || x > right ? x : right;
      }
    }
    if (top == null) return null;
    return Rect.fromLTRB(
      left! / ratio,
      top / ratio,
      (right! + 1) / ratio,
      (bottom! + 1) / ratio,
    );
  }
}
