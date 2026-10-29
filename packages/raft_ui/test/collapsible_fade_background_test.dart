import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  // The collapse fade must blend into whatever the row is painted on: a
  // highlighted (mention / focused) row is not the panel colour, and a
  // fixed-colour gradient over it shows as a white band.
  testWidgets('collapse fade blends into a highlighted row', (tester) async {
    const highlight = Color(0xFF8FE3F5);
    final boundary = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: RepaintBoundary(
              key: boundary,
              child: ColoredBox(
                color: highlight,
                child: RaftCollapsible(
                  child: SizedBox(
                    height: 700,
                    width: 400,
                    child: const ColoredBox(color: Color(0x00000000)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final clip = tester.getRect(find.byType(ClipRect).last);
    final origin = tester.getTopLeft(find.byKey(boundary));
    final image = await tester.runAsync(
      () =>
          (boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage(),
    );
    addTearDown(image!.dispose);
    final bytes = (await tester.runAsync(
      () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
    ))!;
    Color at(Offset p) {
      final x = (p.dx - origin.dx).round(), y = (p.dy - origin.dy).round();
      final i = (y * image.width + x) * 4;
      return Color.fromARGB(
        bytes.getUint8(i + 3),
        bytes.getUint8(i),
        bytes.getUint8(i + 1),
        bytes.getUint8(i + 2),
      );
    }

    // Inside the 48px fade, just above the clipped bottom edge.
    final sample = at(Offset(clip.center.dx, clip.bottom - 4));
    expect(
      (sample.r - highlight.r).abs() < 0.02 &&
          (sample.g - highlight.g).abs() < 0.02 &&
          (sample.b - highlight.b).abs() < 0.02,
      isTrue,
      reason: 'fade painted $sample over the $highlight row',
    );
  });
}
