import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets('$family/$dark focus paint retains live input, IME and clear', (
      t,
    ) async {
      final controller = TextEditingController();
      final focus = FocusNode();
      final changes = <String>[];
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(family, dark: dark),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 320,
                child: RaftSearchInput(
                  controller: controller,
                  focusNode: focus,
                  hint: 'Search messages',
                  clearLabel: 'Clear search',
                  showEscape: true,
                  onChanged: changes.add,
                  onClear: controller.clear,
                ),
              ),
            ),
          ),
        ),
      );
      final before = t.state(find.byType(EditableText));
      await t.showKeyboard(find.byType(TextField));
      t.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'ni',
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange(start: 0, end: 2),
        ),
      );
      await t.pump();
      expect(t.state(find.byType(EditableText)), same(before));
      expect(focus.hasFocus, true);
      t.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '你',
          selection: TextSelection.collapsed(offset: 1),
        ),
      );
      await t.pump();
      expect(controller.text, '你');
      expect(changes, ['ni', '你']);
      await t.tap(find.byTooltip('Clear search'));
      await t.pump();
      expect(controller.text, isEmpty);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      focus.dispose();
      controller.dispose();
    });
  }
}
