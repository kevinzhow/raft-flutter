import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

import 'task_typography_test.dart' show loadTaskFonts;

/// Device row just below the ink of a stem-only glyph ('I'), i.e. where the
/// rasterised baseline landed.
Future<int> paintedBaselineRow(WidgetTester tester, Key key) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  final image = (await tester.runAsync(() => boundary.toImage(pixelRatio: 3)))!;
  final bytes = (await tester.runAsync(
    () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
  ))!;
  var last = -1;
  for (var y = 0; y < image.height; y++) {
    var ink = 0;
    for (var x = 0; x < image.width; x++) {
      final i = (y * image.width + x) * 4;
      // Rows past the fractional box bottom are transparent, not ink.
      if (bytes.getUint8(i + 3) == 255) ink += 255 - bytes.getUint8(i);
    }
    if (ink > 200) last = y;
  }
  image.dispose();
  return last + 1;
}

void main() {
  // Chromium (device scale 3, unhinted) puts a CSS line's baseline at the
  // rounded font ascent plus the floored half-leading: 12px/20px Hanken
  // Grotesk -> 12 + floor((20 - 16) / 2) = 14 CSS px = device row 42.
  // SkParagraph reports 14.182 but rasterises at round(14.182) = 14, so a
  // line box aligning the reported value painted one device row too high.
  for (final (size, line, expected) in [
    (12.0, 20.0, 42),
    (14.0, 20.0, 45),
    (14.0, 22.75, 48),
  ]) {
    testWidgets('RaftCssText paints the Blink baseline: $size/$line', (
      tester,
    ) async {
      await loadTaskFonts(tester);
      const key = ValueKey('text');
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: RepaintBoundary(
              key: key,
              child: ColoredBox(
                color: const Color(0xFFFFFFFF),
                child: RaftCssText(
                  'I',
                  style: TextStyle(
                    fontFamily: 'packages/raft_ui/HankenGrotesk',
                    fontSize: size,
                    height: line / size,
                    leadingDistribution: TextLeadingDistribution.even,
                    color: const Color(0xFF000000),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(
        raftCssBaseline(
              TextStyle(
                fontFamily: 'packages/raft_ui/HankenGrotesk',
                fontSize: size,
                height: line / size,
              ),
            ) *
            3,
        expected,
      );
      expect(await paintedBaselineRow(tester, key), expected);
    });
  }
}
