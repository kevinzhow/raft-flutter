import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/src/css_recipe_decoration.dart';

import 'control_transition_paint_test.dart' show pixel;

/// CSS clips an outer `box-shadow` to outside the border box; Flutter paints
/// a BoxShadow as a full shape beneath the box, so a translucent or
/// transparent fill would composite over a solid shadow. These assert the
/// interior stays "fill over page background" while the shadow still paints
/// outside.
void main() {
  const page = Color(0xffffffff);

  Widget host(Widget child) => MaterialApp(
    theme: raftTheme(),
    home: Align(
      alignment: Alignment.topLeft,
      child: RepaintBoundary(
        key: const ValueKey('paint'),
        child: ColoredBox(
          color: page,
          child: Padding(padding: const EdgeInsets.all(8), child: child),
        ),
      ),
    ),
  );

  void expectClose(Color actual, Color expected) {
    for (final (a, e) in [
      (actual.r, expected.r),
      (actual.g, expected.g),
      (actual.b, expected.b),
    ]) {
      expect((a - e).abs() * 255, lessThanOrEqualTo(1.5), reason: '$actual');
    }
  }

  testWidgets(
    'RaftRecipeDecoration keeps its shadow out of a translucent fill',
    (tester) async {
      await tester.pumpWidget(
        host(
          DecoratedBox(
            decoration: RaftRecipeDecoration(
              color: const Color(0x4000b4d8),
              boxShadow: const [BoxShadow(offset: Offset(4, 4))],
            ),
            child: const SizedBox(width: 60, height: 40),
          ),
        ),
      );
      expectClose(
        await pixel(tester, const Offset(8 + 30, 8 + 20)),
        Color.alphaBlend(const Color(0x4000b4d8), page),
      );
      expect(await pixel(tester, const Offset(8 + 40, 8 + 42)), Colors.black);
    },
  );

  testWidgets(
    'RaftFieldSurface casts no shadow and keeps its box transparent',
    (tester) async {
      await tester.pumpWidget(
        host(const RaftFieldSurface(child: SizedBox(width: 80, height: 40))),
      );
      final box = tester.getTopLeft(find.byType(RaftFieldSurface));
      // Nothing is painted inside the box and controls cast no shadow below it.
      expect(await pixel(tester, box + const Offset(40, 20)), page);
      expect(await pixel(tester, box + const Offset(40, 41)), page);
    },
  );
}
