import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_theme/raft_theme.dart' show builtInBrutalTheme;
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

import 'control_paint.dart';

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
  testWidgets(
    'frozen Brutal picker press has no generic Brutal translation or shadow',
    (tester) async {
      var picked = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(pack: builtInBrutalTheme),
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
      final control = find.byType(RaftPickerTriggerButton);
      final transform = controlTransform(tester, control);
      expect(transform.storage[12], 0);
      expect(transform.storage[13], 0);
      // Controls cast no drop shadow; the only layer is the 1px hairline ring
      // that stands in for the outline border.
      for (final shadow
          in controlDecoration(tester, control).boxShadow ?? const []) {
        expect(shadow.offset, Offset.zero);
        expect(shadow.blurRadius, 0);
      }
      await gesture.up();
      expect(picked, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
