import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

import 'task_typography_test.dart' show loadTaskFonts;

void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    testWidgets(
      '${dark ? 'dark' : 'light'} CSS editor keeps native selection and IME',
      (tester) async {
        await loadTaskFonts(tester);
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
        addTearDown(tester.view.reset);
        final sent = <String>[];
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topCenter,
                child: RaftComposer(
                  initialDraft: 'Alpha\nBeta',
                  onSend: (value) async {
                    sent.add(value);
                    return false;
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        final field = find.byType(TextField);
        final lineBox = find.ancestor(
          of: field,
          matching: find.byType(RaftCssLineBox),
        );
        expect(lineBox, findsOneWidget);
        // Current Raft uses two 24px lines; keep native input/IME checks below.
        expect(tester.getSize(lineBox).height, 48);
        final textField = tester.widget<TextField>(field);
        final tokens = RaftTokens.of(tester.element(field));
        expect(textField.style!.color, tokens.strong);
        final editable = tester
            .state<EditableTextState>(find.byType(EditableText))
            .renderEditable;
        final cursor = editable.getLocalRectForCaret(
          const TextPosition(offset: 3),
        );
        await tester.tapAt(editable.localToGlobal(cursor.center));
        await tester.pump();
        expect(
          textField.controller!.selection,
          const TextSelection.collapsed(offset: 3),
        );
        expect(textField.focusNode!.hasFocus, true);
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: 'Alpha\n日本語',
            selection: TextSelection.collapsed(offset: 9),
            composing: TextRange(start: 6, end: 9),
          ),
        );
        await tester.pump();
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pump();
        expect(sent, isEmpty);
        expect(
          textField.controller!.value.composing,
          const TextRange(start: 6, end: 9),
        );
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: 'Alpha\n日本語',
            selection: TextSelection(baseOffset: 6, extentOffset: 9),
          ),
        );
        await tester.pump();
        expect(
          textField.controller!.selection,
          const TextSelection(baseOffset: 6, extentOffset: 9),
        );
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pump();
        expect(sent, ['Alpha\n日本語']);
        expect(tester.getSize(lineBox).height, 48);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );

    testWidgets(
      '${dark ? 'dark' : 'light'} pending actions bind keyboard receipts',
      (tester) async {
        final marked = <(String, RaftPendingMentionState)>[];
        final dismissed = <String>[];
        final executing = ValueNotifier<bool>(false);
        addTearDown(executing.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: Scaffold(
              body: ValueListenableBuilder<bool>(
                valueListenable: executing,
                builder: (_, busy, _) => RaftPendingMentionActionStrip(
                  actions: const [
                    RaftPendingMention(
                      resolutionId: 'outside-member',
                      targetType: 'user',
                      targetHandle: 'Cindy',
                      availableActions: ['add', 'notify'],
                    ),
                  ],
                  channelName: 'general',
                  executing: busy
                      ? {'outside-member': RaftPendingMentionState.added}
                      : const {},
                  onMark: (id, state) => marked.add((id, state)),
                  onDismiss: dismissed.add,
                ),
              ),
            ),
          ),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(marked, [('outside-member', RaftPendingMentionState.added)]);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pump();
        expect(marked.last, (
          'outside-member',
          RaftPendingMentionState.notified,
        ));
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(dismissed, ['outside-member']);
        executing.value = true;
        await tester.pump();
        final buttons = tester.widgetList<RaftRecipeButton>(
          find.byType(RaftRecipeButton),
        );
        expect(buttons.take(2).every((button) => button.disabled), true);
        await tester.tap(find.text('Add'));
        await tester.tap(find.text('Notify'));
        await tester.pump();
        expect(marked.length, 2);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
