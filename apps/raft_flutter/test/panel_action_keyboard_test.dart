import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      'panel action genuine Tab/Enter/Space and disabled semantics ${dark ? 'dark' : 'light'}',
      (t) async {
        int count = 0;
        Future<void> host(bool enabled) => t.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: Scaffold(
              body: Row(
                children: [
                  RaftPanelAction(
                    glyph: RaftGlyph.arrowLeft,
                    tooltip: 'Back',
                    onPressed: enabled ? () => count++ : null,
                  ),
                  TextButton(onPressed: () {}, child: const Text('Next')),
                ],
              ),
            ),
          ),
        );
        await host(true);
        final size = t.getSize(find.byType(RaftPanelAction));
        await t.sendKeyEvent(LogicalKeyboardKey.tab);
        await t.pump();
        await t.sendKeyEvent(LogicalKeyboardKey.enter);
        await t.pump();
        expect(count, 1);
        await t.sendKeyEvent(LogicalKeyboardKey.space);
        await t.pump();
        expect(count, 2);
        expect(t.getSize(find.byType(RaftPanelAction)), size);
        await host(false);
        await t.sendKeyEvent(LogicalKeyboardKey.enter);
        await t.sendKeyEvent(LogicalKeyboardKey.space);
        await t.pump();
        expect(count, 2);
        expect(
          t
              .getSemantics(find.byType(RaftPanelAction))
              .getSemanticsData()
              .hasAction(SemanticsAction.tap),
          false,
        );
        expect(t.takeException(), isNull);
      },
    );
  }
}
