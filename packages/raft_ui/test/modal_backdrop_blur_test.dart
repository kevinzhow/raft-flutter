import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final pack in raftThemeMatrix([
    raftThemePackId,
    elegantThemePackId,
    brutalThemePackId,
  ], look: raftLookOf)) {
    for (final dark in [false, true]) {
      testWidgets('modal backdrop keeps source blur for $pack dark=$dark', (
        t,
      ) async {
        t.view.physicalSize = const Size(800, 600);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final boundary = GlobalKey();
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(pack: packForThemeId(pack), dark: dark),
            home: RepaintBoundary(
              key: boundary,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: ColoredBox(color: Colors.red)),
                      Expanded(child: ColoredBox(color: Colors.blue)),
                    ],
                  ),
                  const RaftModalBackdrop(
                    child: SizedBox(width: 80, height: 80),
                  ),
                ],
              ),
            ),
          ),
        );
        final render =
            boundary.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
        await t.runAsync(() async {
          final image = await render.toImage();
          try {
            final pixels = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
            int pixel(int x) => pixels.getUint32((20 * image.width + x) * 4);
            // Web v1.21.23 Modal explicitly has no blur. a57 ModalBackdrop
            // blurs by 2px in both frozen packs and modes. A real painted edge
            // stays sharp only for Raft; check away from the centred card.
            if (pack == raftThemePackId) {
              expect(pixel(399), pixel(100));
              expect(pixel(400), pixel(700));
            } else {
              expect(pixel(399), isNot(pixel(100)));
              expect(pixel(400), isNot(pixel(700)));
            }
          } finally {
            image.dispose();
          }
        });
        expect(t.takeException(), isNull);
      });
    }
  }
}
