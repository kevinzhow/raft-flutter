import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
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
