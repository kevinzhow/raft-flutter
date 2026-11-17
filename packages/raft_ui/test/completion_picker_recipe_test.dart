import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final dark in raftThemeMatrix([false, true], full: true)) {
    testWidgets(
      '${dark ? 'dark' : 'light'} source picker density keeps keyboard selection',
      (tester) async {
        var selected = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: Scaffold(
              body: RaftDensityScope(
                density: RaftDensity.desktop,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: RaftDropdownMenu(
                    label: 'Recent',
                    triggerStyle: RaftDropdownTriggerStyle.picker,
                    glyph: RaftGlyph.arrowDownUp,
                    trailingGlyph: RaftGlyph.chevronDown,
                    entries: [
                      RaftMenuEntry(
                        label: 'Relevance',
                        onPressed: () => selected++,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        final trigger = find.widgetWithText(RaftControl, 'Recent');
        expect(tester.getSize(trigger).height, 28);
        final control = tester.widget<RaftControl>(trigger);
        expect(control.recipe, isA<RaftPickerTriggerRecipe>());
        expect(control.recipe!.textStyle.fontSize, 12);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(find.byType(RaftMenuItem), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(selected, 1);
        expect(find.byType(RaftMenuItem), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
