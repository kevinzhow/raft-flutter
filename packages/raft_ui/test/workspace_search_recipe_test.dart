import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

// Published raft-ui 0.95.3 SearchTrigger (dist/components/search/search-trigger.mjs): bg-layer-card with one
// `active:overlay-medium` and no hover wash. Exercise the public toolbar search entry.
void main() {
  for (final dark in [false, true]) {
    testWidgets('search $dark keeps its paper fill under hover and press', (
      tester,
    ) async {
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      });
      const paint = Key('search-paint');
      late RaftTokens tokens;
      var opened = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(dark: dark),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: Builder(
                builder: (context) {
                  tokens = RaftTokens.of(context);
                  return RepaintBoundary(
                    key: paint,
                    child: SizedBox(
                      width: 360,
                      child: RaftWorkspaceSearchTrigger(
                        onPressed: () => opened++,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(paint),
      );
      Future<Color> fill() async {
        return (await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          try {
            final bytes = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
            final offset = (18 * image.width + 180) * 4;
            return Color.fromARGB(
              bytes.getUint8(offset + 3),
              bytes.getUint8(offset),
              bytes.getUint8(offset + 1),
              bytes.getUint8(offset + 2),
            );
          } finally {
            image.dispose();
          }
        }))!;
      }

      final paper = tokens.colors['layer-card']!;
      // Chromium composites with the 8-bit alpha (chrome-headless-shell 1234: dark fill-medium over layer-card
      // paints 50,50,47), not Dart's float Color.alphaBlend (50,50,48).
      final wash = raftChromeBlend(tokens.colors['fill-medium']!, paper);
      expect(await fill(), paper);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(700, 500));
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.byKey(paint)));
      await tester.pumpAndSettle();
      expect(
        await fill(),
        paper,
        reason: 'The 0.95.3 source has no hover wash on the search box.',
      );
      await mouse.down(tester.getCenter(find.byKey(paint)));
      await tester.pumpAndSettle();
      expect(
        await fill(),
        wash,
        reason:
            'The source overlays the fill on press, retaining readable ink.',
      );
      await mouse.up();
      await tester.pumpAndSettle();
      expect(opened, 1);
      await mouse.moveTo(const Offset(700, 500));
      await tester.pumpAndSettle();
      expect(await fill(), paper);
      // Check intermediate frames as well as settled hover: no opaque black
      // frame may replace the paper when the hover state changes.
      await mouse.moveTo(tester.getCenter(find.byKey(paint)));
      for (final ms in [0, 16, 32, 64, 150]) {
        await tester.pump(Duration(milliseconds: ms));
        final luminance = (await fill()).computeLuminance();
        final a = paper.computeLuminance();
        final b = wash.computeLuminance();
        expect(
          luminance,
          inInclusiveRange((a < b ? a : b) - .001, (a > b ? a : b) + .001),
        );
      }
      await tester.pumpAndSettle();
      expect(await fill(), paper);
      expect(tester.getSize(find.byKey(paint)).height, 36);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('search $dark retains keyboard activation and source label', (
      tester,
    ) async {
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      });
      var opened = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(dark: dark),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                child: RaftWorkspaceSearchTrigger(onPressed: () => opened++),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(opened, 1);
      // raft-ui 0.7.0 SearchTrigger: text-body (16px/24px).
      final label = tester.renderObject<RenderParagraph>(find.text('Search'));
      expect(label.text.style!.fontSize, 16);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
}
