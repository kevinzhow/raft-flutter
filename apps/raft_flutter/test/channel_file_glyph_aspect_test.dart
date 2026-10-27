import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/source_channel_file_glyph.dart';
import 'package:raft_ui/raft_ui.dart';

Future<Uint8List> _pixels(WidgetTester t, Widget glyph, Size slot) async {
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(),
      home: Center(
        child: RepaintBoundary(
          key: const Key('glyph'),
          child: SizedBox.fromSize(size: slot, child: glyph),
        ),
      ),
    ),
  );
  await t.pump();
  final boundary = t.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('glyph')),
  );
  return (await t.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    try {
      return (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
          .buffer
          .asUint8List();
    } finally {
      image.dispose();
    }
  }))!;
}

void main() {
  for (final glyph in SourceChannelFileGlyph.values) {
    testWidgets('channel file ${glyph.name} keeps square artwork', (t) async {
      addTearDown(() => t.pumpWidget(const SizedBox()));
      for (final slot in [
        const Size(64, 24),
        const Size(10, 24),
        const Size(24, 10),
      ]) {
        final extent = slot.shortestSide.clamp(0.0, 18.0);
        final control = await _pixels(
          t,
          Center(
            child: SizedBox.square(
              dimension: extent,
              child: ChannelFileGlyph(glyph, color: Colors.black),
            ),
          ),
          slot,
        );
        final actual = await _pixels(
          t,
          ChannelFileGlyph(glyph, color: Colors.black),
          slot,
        );
        final paint = find.descendant(
          of: find.byType(ChannelFileGlyph),
          matching: find.byType(CustomPaint),
        );
        expect(t.getSize(paint), Size.square(extent), reason: '$slot');
        expect(actual, control, reason: 'paint differs in $slot');
        expect([
          for (var i = 3; i < actual.length; i += 4) actual[i],
        ], contains(isPositive));
      }
      expect(t.takeException(), isNull);
    });
  }
}
