import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/src/message_toolbar_glyphs.dart';

Future<Uint8List> raster(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('glyph-capture')),
  );
  return (await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      expect(image.width, 13);
      expect(image.height, 13);
      return (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
          .buffer
          .asUint8List();
    } finally {
      image.dispose();
    }
  }))!;
}

void main() {
  for (final reaction in [false, true]) {
    testWidgets(
      'source glyph stays13 and follows inherited control foreground: reaction=$reaction',
      (tester) async {
        Widget host(Color color) => MaterialApp(
          home: Center(
            child: IconTheme(
              data: IconThemeData(color: color),
              child: RepaintBoundary(
                key: const Key('glyph-capture'),
                child: reaction
                    ? const RaftMessageAddReactionGlyph()
                    : const RaftMessageThreadGlyph(),
              ),
            ),
          ),
        );
        await tester.pumpWidget(host(const Color(0xffff0000)));
        final red = await raster(tester);
        expect(
          [for (var i = 3; i < red.length; i += 4) red[i]].any((v) => v > 0),
          isTrue,
        );
        expect(
          [for (var i = 2; i < red.length; i += 4) red[i]].every((v) => v == 0),
          isTrue,
        );
        await tester.pumpWidget(host(const Color(0xff0000ff)));
        final blue = await raster(tester);
        expect(
          [for (var i = 3; i < blue.length; i += 4) blue[i]].any((v) => v > 0),
          isTrue,
        );
        expect(
          [for (var i = 0; i < blue.length; i += 4) blue[i]]
              .every((v) => v == 0),
          isTrue,
        );
        expect(red, isNot(orderedEquals(blue)));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
