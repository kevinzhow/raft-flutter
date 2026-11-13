import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      'selection scroll content keeps the source inset ${dark ? 'dark' : 'light'}',
      (tester) async {
        const rowKey = ValueKey('selection-content-row');
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: RaftSelectionPopover(
                  title: 'Channels',
                  showHeader: false,
                  width: 220,
                  options: [
                    RaftSelectionOption(
                      rowKey: rowKey,
                      label: 'Design',
                      checked: false,
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        final viewport = tester.getRect(find.byType(SingleChildScrollView));
        final row = tester.getRect(find.byKey(rowKey));
        // Web v1.24 SelectionPopover.tsx: ScrollArea contentClassName="p-1".
        // This inset is inside the scroller, independent of the caller surface.
        expect(row.left - viewport.left, 4);
        expect(row.top - viewport.top, 4);
        expect(viewport.right - row.right, 4);
        expect(viewport.bottom - row.bottom, 4);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'selection buttons preserve keyboard, checked and disabled ${dark ? 'dark' : 'light'}',
      (tester) async {
        var clears = 0, selected = 0, disabled = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: Scaffold(
              body: Center(
                child: RaftSelectionPopover(
                  title: 'Channels',
                  width: 310,
                  onClear: () => clears++,
                  options: [
                    RaftSelectionOption(
                      label: 'design',
                      checked: true,
                      onTap: () => selected++,
                    ),
                    RaftSelectionOption(
                      label: 'unavailable',
                      checked: false,
                      disabled: true,
                      onTap: () => disabled++,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        expect(clears, 1);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pump();
        expect(selected, 1);
        await tester.tap(find.text('unavailable'));
        expect(disabled, 0);
        expect(tester.getSize(find.byType(RaftSelectionPopover)).width, 310);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
