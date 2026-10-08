import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      '$family dark=$dark source picker density keeps keyboard selection',
      (tester) async {
        var selected = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
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
        expect(
          tester.getSize(trigger).height,
          family == RaftFamily.brutal ? 32 : 28,
        );
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
  testWidgets('picker press has no generic Brutal translation or shadow', (
    tester,
  ) async {
    var picked = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.brutal),
        home: Scaffold(
          body: RaftDensityScope(
            density: RaftDensity.desktop,
            child: Align(
              alignment: Alignment.topLeft,
              child: RaftPickerTriggerButton(
                label: 'Channel',
                glyph: RaftGlyph.hash,
                onPressed: () => picked++,
              ),
            ),
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(RaftPickerTriggerButton)),
    );
    await tester.pump(const Duration(milliseconds: 110));
    final surface = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer),
    );
    expect(surface.transform!.storage[12], 0);
    expect(surface.transform!.storage[13], 0);
    expect((surface.decoration! as BoxDecoration).boxShadow, isEmpty);
    await gesture.up();
    expect(picked, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
