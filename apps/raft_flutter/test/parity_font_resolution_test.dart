import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

import 'parity/parity_harness.dart';

// Compare the selected product font to its bundled asset after the real
// screenshot loader runs. A family string alone cannot prove a glyph resolved.
Future<Uint8List> _raster(String family) async {
  final painter = TextPainter(
    text: TextSpan(
      text: 'Wiilgy 0123 @Raft',
      style: TextStyle(fontFamily: family, fontSize: 18, color: Colors.black),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..drawColor(Colors.white, BlendMode.src);
  painter.paint(canvas, const Offset(4, 8));
  final picture = recorder.endRecording();
  final image = await picture.toImage(300, 48);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  picture.dispose();
  painter.dispose();
  return bytes!.buffer.asUint8List();
}

void main() {
  for (final (id, dark, heading, sans, mono) in raftThemeMatrix([
    (raftThemePackId, false, 'SpaceGrotesk', 'SpaceGrotesk', 'SpaceMono'),
    (raftThemePackId, true, 'SpaceGrotesk', 'SpaceGrotesk', 'SpaceMono'),
    (elegantThemePackId, false, 'Inter', 'Geist', 'GeistMono'),
    (elegantThemePackId, true, 'Inter', 'Geist', 'GeistMono'),
    (brutalThemePackId, false, 'HankenGrotesk', 'HankenGrotesk', 'GeistMono'),
    (brutalThemePackId, true, 'Inter', 'Geist', 'GeistMono'),
  ], look: (v) => raftLookOf(v.$1))) {
    for (final role in ['heading', 'sans', 'mono']) {
      testWidgets('$id dark=$dark $role draws the bundled glyphs', (t) async {
        await t.runAsync(loadParityFonts);
        final tokens = RaftTokens.theme(pack: packForThemeId(id), dark: dark);
        final family = switch (role) {
          'heading' => tokens.headingFont,
          'sans' => tokens.bodyFont,
          _ => tokens.monoFont,
        };
        final reference = switch (role) {
          'heading' => heading,
          'sans' => sans,
          _ => mono,
        };
        await t.runAsync(() async {
          final actual = await _raster(family);
          final expected = await _raster('packages/raft_ui/$reference');
          final fallback = await _raster('__parity_unregistered_font__');
          expect(
            expected,
            isNot(orderedEquals(fallback)),
            reason: 'reference must not be Ahem',
          );
          expect(
            actual,
            orderedEquals(expected),
            reason: '$family must resolve to $reference',
          );
        });
      });
    }
  }
}
