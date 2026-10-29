import 'dart:ui' show CheckedState;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final theme in raftThemeMatrix([(false), (true)])) {
    final (dark) = theme;
    Widget host(Widget child) => MaterialApp(
      theme: raftTheme(dark: dark),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );
    testWidgets(
      '$theme five choices retain selection, keyboard and radio semantics',
      (tester) async {
        final semantics = tester.ensureSemantics();
        var selected = RaftAppIconPalette.yellow;
        await tester.pumpWidget(
          host(
            StatefulBuilder(
              builder: (context, update) => RaftAppIconChoices(
                selected: selected,
                onChanged: (value) => update(() => selected = value),
              ),
            ),
          ),
        );
        expect(find.byType(RaftBrandMark), findsNWidgets(6));
        final blue = find.byKey(const ValueKey('app-icon-blue'));
        await tester.tap(blue);
        await tester.pump();
        expect(selected, RaftAppIconPalette.blue);
        expect(
          tester
              .getSemantics(blue)
              .getSemanticsData()
              .flagsCollection
              .isChecked,
          CheckedState.isTrue,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(selected, RaftAppIconPalette.green);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );
    testWidgets(
      '$theme pending choice keeps existing selection and disables pointer/keyboard',
      (tester) async {
        var calls = 0;
        await tester.pumpWidget(
          host(
            RaftAppIconChoices(
              selected: RaftAppIconPalette.pink,
              busy: true,
              onChanged: (_) => calls++,
            ),
          ),
        );
        await tester.tap(find.byKey(const ValueKey('app-icon-blue')));
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(calls, 0);
        expect(find.text('Changing icon…'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
