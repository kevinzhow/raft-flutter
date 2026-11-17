// Raft source geometry is covered
// by framework_navigation_contract_test and framework_sidebar_phone_contract_test.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  testWidgets(
    'GitBranch renders pinned branch stem and two open node circles',
    (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: RepaintBoundary(
              key: key,
              child: const SizedBox.square(
                dimension: 24,
                child: RaftIcon(
                  RaftGlyph.gitBranch,
                  size: 24,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ),
      );
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 4);
        try {
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          int alpha(int x, int y) =>
              bytes.getUint8(((y * 4) * image.width + x * 4) * 4 + 3);
          expect(alpha(6, 8), greaterThan(200)); // branch stem
          expect(
            alpha(9, 9),
            greaterThan(100),
          ); // curved branch, not a Link glyph
          expect(alpha(18, 3), greaterThan(100)); // top node ring
          expect(alpha(6, 15), greaterThan(100)); // bottom node ring
          expect(alpha(18, 6), 0); // open circle centers, unlike a filled glyph
          expect(alpha(6, 18), 0);
          expect(alpha(1, 1), 0);
        } finally {
          image.dispose();
        }
      });
      await tester.pumpWidget(const SizedBox());
    },
  );
}
