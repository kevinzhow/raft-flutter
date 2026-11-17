import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

// raft-ui 0.95.3 mobile-nav.mjs:12: the docked bar pads its bottom with
// max(8, min(inset, 34)); a system inset the host paints below the bar counts
// toward the 8. 52 = 1 (seam) + 6 (top) + 45 (item).
const _items = [
  RaftMobileNavItem(id: 'chat', label: 'Home', glyph: RaftGlyph.home),
  RaftMobileNavItem(id: 'tasks', label: 'Tasks', glyph: RaftGlyph.listTodo),
];

Future<double> _height(
  WidgetTester t, {
  required bool dark,
  required double barInset,
  required double systemInset,
}) async {
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(dark: dark),
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(390, 844),
          viewPadding: EdgeInsets.only(bottom: systemInset),
        ),
        child: Scaffold(
          body: Align(
            alignment: Alignment.bottomLeft,
            child: SizedBox(
              width: 390,
              child: RaftMobileNav(
                items: _items,
                selectedId: 'chat',
                onSelected: (_) {},
                bottomInset: barInset,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  return t.getSize(find.byType(RaftMobileNav)).height;
}

void main() {
  for (final dark in [false, true]) {
    testWidgets('bar pads its own inset with an 8 floor, capped at 34 '
        'dark=$dark', (t) async {
      for (final (inset, height) in [
        (0.0, 60.0),
        (4.0, 60.0),
        (24.0, 76.0),
        (48.0, 86.0),
      ]) {
        expect(
          await _height(t, dark: dark, barInset: inset, systemInset: inset),
          height,
          reason: 'bar inset $inset',
        );
      }
    });

    testWidgets('a system inset painted below the bar counts toward the 8 '
        'dark=$dark', (t) async {
      for (final (system, height) in [
        (0.0, 60.0),
        (4.0, 56.0),
        (24.0, 52.0),
        (48.0, 52.0),
      ]) {
        expect(
          await _height(t, dark: dark, barInset: 0, systemInset: system),
          height,
          reason: 'system inset $system below the bar',
        );
      }
    });
  }
}
