import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets('App profile supports keyboard and code point counter $dark', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(dark: dark),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, update) => RaftAppWhenToUseField(
                controller: controller,
                onChanged: (_) => update(() {}),
              ),
            ),
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isTrue,
      );
      await tester.enterText(find.byType(TextField), '📚');
      await tester.pump();
      expect(find.text('1 / 160 characters'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'x' * 161);
      await tester.pump();
      expect(
        find.text('Use no more than 160 characters before saving.'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), 'x');
      await tester.pump();
      expect(
        find.text('Use no more than 160 characters before saving.'),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
