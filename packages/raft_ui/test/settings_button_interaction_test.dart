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
    testWidgets('$family/$dark settings buttons support keyboard and revoke', (
      tester,
    ) async {
      var saves = 0;
      var enabled = true;
      late StateSetter update;
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(family, dark: dark),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return Column(
                  children: [
                    RaftSettingsRecipeButton(
                      label: 'Save',
                      onPressed: enabled ? () => saves++ : null,
                    ),
                    const RaftSettingsRecipeButton(label: 'Unavailable'),
                  ],
                );
              },
            ),
          ),
        ),
      );
      final button = find.widgetWithText(RaftSettingsRecipeButton, 'Save');
      final before = tester.getRect(button);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(tester.getRect(button), before);
      final saveInteractive = find.descendant(
        of: button,
        matching: find.byType(RaftInteractive),
      );
      expect(
        tester.getSemantics(saveInteractive),
        matchesSemantics(
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          isFocused: true,
          hasTapAction: true,
          hasFocusAction: true,
          label: 'Save',
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(saves, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(saves, 2);
      update(() => enabled = false);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.tap(button);
      expect(saves, 2);
      expect(tester.getRect(button), before);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }
}
