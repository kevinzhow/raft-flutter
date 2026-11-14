import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

/// Web v1.24 `FormField`: a `labelAction` (Forgot password) is drawn at the end
/// of the label row but comes after the control in the markup, so Tab reaches
/// the field first; label and action are `gap-x-2` (8px) apart.
void main() {
  testWidgets('Tab reaches the control before the label action', (t) async {
    final field = FocusNode(), action = FocusNode();
    addTearDown(field.dispose);
    addTearDown(action.dispose);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: RaftField(
            label: 'Password',
            labelAction: Focus(
              focusNode: action,
              child: const Text('Forgot password?', key: Key('action')),
            ),
            child: RaftTextInput(focusNode: field),
          ),
        ),
      ),
    );
    // Reading order would put the action (it sits in the label row, above the
    // control) first; the Web markup puts it after the control.
    field.requestFocus();
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.pump();
    expect(action.hasFocus, isTrue);
    await t.sendKeyDownEvent(LogicalKeyboardKey.shift);
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.sendKeyUpEvent(LogicalKeyboardKey.shift);
    await t.pump();
    expect(field.hasFocus, isTrue);
  });

  testWidgets('label and its action are 8px apart', (t) async {
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: RaftField(
              label: 'Password',
              labelAction: const SizedBox(width: 40, height: 16, key: Key('a')),
              child: const RaftTextInput(),
            ),
          ),
        ),
      ),
    );
    final labelRight = t.getTopRight(find.text('Password')).dx;
    final actionLeft = t.getTopLeft(find.byKey(const Key('a'))).dx;
    // The label cell is `minmax(0,1fr)`: it fills to the action minus gap-x-2.
    expect(actionLeft, 300 - 40 + t.getTopLeft(find.byType(Scaffold)).dx);
    expect(labelRight, lessThanOrEqualTo(actionLeft - 8));
  });
}
