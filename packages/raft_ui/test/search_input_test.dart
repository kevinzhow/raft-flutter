import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      '${dark ? 'dark' : 'light'} focus paint retains live input, IME and clear',
      (t) async {
        final controller = TextEditingController();
        final focus = FocusNode();
        final changes = <String>[];
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 320,
                  child: RaftSearchInput(
                    controller: controller,
                    focusNode: focus,
                    hint: 'Search messages',
                    clearLabel: 'Clear Search',
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
        final frame = find
            .ancestor(
              of: find.byType(TextField),
              matching: find.byType(RaftRecipeBox),
            )
            .first;
        List<double> focusSpreads() {
          final box = t.widget<RaftRecipeBox>(frame);
          return box.style
              .decoration(box.tokens)
              .boxShadow!
              .where((shadow) => shadow.color.a > 0)
              .map((shadow) => shadow.spreadRadius)
              .toList();
        }

        expect(focusSpreads(), isEmpty);
        await t.tap(find.byType(TextField));
        await t.pump();
        expect(focusSpreads(), unorderedEquals([2, 4]));
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
        await t.tap(find.byTooltip('Clear Search'));
        await t.pump();
        expect(controller.text, isEmpty);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        focus.dispose();
        controller.dispose();
      },
    );
  }
}
