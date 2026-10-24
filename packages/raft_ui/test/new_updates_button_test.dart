import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      '${dark ? 'dark' : 'light'} pinned to the top centre; tap and semantics',
      (tester) async {
        final semantics = tester.ensureSemantics();
        var taps = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(pack: packForThemeId(elegantThemePackId), dark: dark),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  key: const Key('list'),
                  width: 390,
                  height: 360,
                  child: Stack(
                    children: [
                      RaftNewUpdatesButton(
                        label: '3 New Updates',
                        onPressed: () => taps++,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        final list = tester.getRect(find.byKey(const Key('list')));
        final button = tester.getRect(find.byType(RaftRecipeButton));
        expect(button.center.dx, list.center.dx);
        expect(button.top, list.top);
        // `sm` outline Button with `py-1.5 text-xs` (16px line box).
        expect(button.height, greaterThanOrEqualTo(28));
        final icon = tester.getSize(
          find.descendant(
            of: find.byType(RaftRecipeButton),
            matching: find.byType(RaftIcon),
          ),
        );
        expect(icon, const Size.square(14));
        final text = tester.widget<Text>(find.text('3 New Updates'));
        expect(text.style?.fontSize, 12);
        expect(
          tester.getSemantics(find.byType(RaftRecipeButton)),
          matchesSemantics(
            isButton: true,
            hasTapAction: true,
            isFocusable: true,
            hasFocusAction: true,
            hasEnabledState: true,
            isEnabled: true,
            label: '3 New Updates',
          ),
        );
        await tester.tap(find.text('3 New Updates'));
        await tester.pumpAndSettle();
        expect(taps, 1);
        // Keyboard activation (Web Button).
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(taps, 2);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );
  }
}
