import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

import 'flutter_test_config.dart' show leakDebt;
import 'support/close_support.dart';

// The chat page lives in a different shell below and above the desktop
// breakpoint (a page of the phone navigator vs the desktop workspace). The
// expanded Markdown editor is one route over the composer's draft, so the
// composer must survive the shell switch: same editor, same text, same caret,
// same focus, and an input method composition keeps running.

const _text = 'one\ntwo\nthree';
final _expand = find.byKey(const ValueKey('composer-expand'));
final _view = find.byType(RaftComposerExpandedView);
final _sheet = find.byType(BottomSheet);

const _phone = Size(390, 844);
const _desktop = Size(1200, 800);
const _up = [Size(600, 800), Size(900, 800), _desktop];
const _down = [Size(900, 800), Size(600, 800), _phone];

EditableTextState _live(WidgetTester t) =>
    t.state<EditableTextState>(find.byType(EditableText).last);

Future<void> _resize(WidgetTester t, List<Size> steps) async {
  for (final s in steps) {
    t.view.physicalSize = s;
    await t.pump();
  }
  await t.pumpAndSettle();
}

/// The workspace at [size] with [_text] in the composer, caret at 6, and the
/// expanded editor open. [compose] leaves an input method composition running.
Future<EditableTextState> _open(
  WidgetTester t,
  Size size, {
  bool compose = false,
}) async {
  await mountWorkspace(t, size);
  addTearDown(() => t.pumpWidget(const SizedBox.shrink()));
  await t.tap(find.byType(TextField).last);
  await t.pump();
  t.testTextInput.enterText(_text);
  await t.pump();
  _live(t).widget.controller.selection = const TextSelection.collapsed(
    offset: 6,
  );
  await t.pump();
  await t.tap(_expand);
  await t.pumpAndSettle();
  expect(_view, findsOneWidget);
  if (compose) {
    for (var i = 1; i <= 3; i++) {
      t.testTextInput.updateEditingValue(
        TextEditingValue(
          text: '$_text${'nihao'.substring(0, i)}',
          selection: TextSelection.collapsed(offset: _text.length + i),
          composing: TextRange(start: _text.length, end: _text.length + i),
        ),
      );
      await t.pump();
    }
  }
  return _live(t);
}

void main() {
  leakDebt(const ['SourceChannelFilesStore']);

  for (final (name, from, steps, sheetFirst) in [
    ('phone to desktop', _phone, _up, true),
    ('desktop to phone', _desktop, _down, false),
  ]) {
    for (final compose in [false, true]) {
      testWidgets(
        '$name${compose ? ' mid-composition' : ''}: the expanded editor '
        'stays, with text, caret and focus',
        (t) async {
          final editor = await _open(t, from, compose: compose);
          expect(_sheet.evaluate().isNotEmpty, sheetFirst);
          final before = editor.widget.controller.value;
          expect(before.text, startsWith(_text));
          expect(
            before.selection.baseOffset,
            compose ? _text.length + 3 : 6,
            reason: 'the fixture put the caret where the test expects it',
          );
          expect(before.composing.isValid, compose);
          t.testTextInput.log.clear();

          await _resize(t, steps);

          expect(_view, findsOneWidget, reason: 'stays expanded');
          expect(_sheet.evaluate().isNotEmpty, !sheetFirst, reason: 'form');
          final live = _live(t);
          expect(
            identical(live.widget.controller, editor.widget.controller),
            isTrue,
            reason: 'same controller: the composer was moved, not rebuilt',
          );
          expect(live.widget.controller.value, before);
          expect(live.widget.focusNode.hasFocus, isTrue);
          final calls = [for (final c in t.testTextInput.log) c.method];
          expect(
            calls,
            isNot(contains('TextInput.clearClient')),
            reason: 'the input method connection was never dropped',
          );
          expect(
            calls,
            isNot(contains('TextInput.setClient')),
            reason: 'nothing else attached: the editor keeps its client',
          );
          // The macOS engine routes keystrokes to the input method only after
          // `show` (it registers its key responder); a drag of the window may
          // leave that behind, so the editor asks again once it moved.
          expect(
            calls,
            contains('TextInput.show'),
            reason: 'the input connection is shown again after the resize',
          );
          // Keystrokes then reach the editor the way the engine delivers them.
          final controller = live.widget.controller;
          final typed = controller.text.length;
          t.testTextInput.updateEditingValue(
            TextEditingValue(
              text: '${controller.text}x',
              selection: TextSelection.collapsed(offset: typed + 1),
              composing: compose
                  ? TextRange(start: _text.length, end: typed + 1)
                  : TextRange.empty,
            ),
          );
          await t.pump();
          expect(controller.text.length, typed + 1);
          for (final key in [
            LogicalKeyboardKey.keyA,
            LogicalKeyboardKey.space,
          ]) {
            expect(
              await t.sendKeyDownEvent(key),
              isFalse,
              reason: 'not consumed',
            );
            await t.sendKeyUpEvent(key);
          }
          expect(t.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.macOS),
      );
    }
  }
}
