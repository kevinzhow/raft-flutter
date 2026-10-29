// Web MessageInput `mentionUndoSnapshotRef` (v1.21.23): Cmd/Ctrl+Z straight
// after a mention is auto-inserted (picker choice or "mention sender") puts
// back the text, the cursor and the mention set from before the insert.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

const _alice = RaftComposerSuggestion(type: 'user', id: 'u1', name: 'alice');

void main() {
  late List<List<Map<String, dynamic>>> sent;
  Widget host({RaftComposerHandle? handle}) {
    sent = [];
    return MaterialApp(
      theme: raftTheme().copyWith(platform: TargetPlatform.macOS),
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: RaftComposer(
            handle: handle,
            suggestions: const [_alice],
            onSend: (_) async => true,
            onSendWithMentions: (text, mentions) async {
              sent.add(mentions);
              return true;
            },
          ),
        ),
      ),
    );
  }

  TextEditingController field(WidgetTester t) =>
      t.widget<TextField>(find.byType(TextField)).controller!;

  Future<void> undo(
    WidgetTester t, {
    bool shift = false,
    bool meta = true,
  }) async {
    await t.sendKeyDownEvent(
      meta ? LogicalKeyboardKey.metaLeft : LogicalKeyboardKey.controlLeft,
    );
    if (shift) await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.keyZ);
    if (shift) await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await t.sendKeyUpEvent(
      meta ? LogicalKeyboardKey.metaLeft : LogicalKeyboardKey.controlLeft,
    );
    await t.pump();
  }

  testWidgets(
    'undo after a picker insert restores "@al" and drops the mention',
    (t) async {
      await t.pumpWidget(host());
      await t.tap(find.byType(TextField));
      await t.enterText(find.byType(TextField), 'hi @al');
      await t.pump();
      await t.tap(find.text('alice').first);
      await t.pump();
      final c = field(t);
      expect(c.text, 'hi @alice ');
      await undo(t);
      expect(c.text, 'hi @al');
      expect(c.selection.baseOffset, 6);
      // The popup stays closed until the user types again.
      expect(find.text('alice'), findsNothing);
      await t.enterText(find.byType(TextField), 'hi @al ');
      await t.tap(find.byKey(const ValueKey('composer-submit')));
      await t.pump();
      expect(sent.single, isEmpty);
    },
  );

  testWidgets('undo after mention-sender restores the draft and the cursor', (
    t,
  ) async {
    final handle = RaftComposerHandle();
    await t.pumpWidget(host(handle: handle));
    await t.enterText(find.byType(TextField), 'look');
    final c = field(t);
    c.selection = const TextSelection.collapsed(offset: 2);
    expect(handle.insertMention(_alice), isTrue);
    await t.pump();
    expect(c.text, 'lo @alice ok');
    await undo(t, meta: false);
    expect(c.text, 'look');
    expect(c.selection.baseOffset, 2);
  });

  testWidgets(
    'typing after the insert ends the undo; other shortcuts do not undo it',
    (t) async {
      final handle = RaftComposerHandle();
      await t.pumpWidget(host(handle: handle));
      await t.enterText(find.byType(TextField), 'a');
      expect(handle.insertMention(_alice), isTrue);
      await t.pump();
      final c = field(t);
      expect(c.text, 'a @alice ');
      // Cmd+Shift+Z is redo, not the mention undo.
      await undo(t, shift: true);
      expect(c.text, 'a @alice ');
      await t.enterText(find.byType(TextField), 'a @alice x');
      await undo(t);
      // No mention snapshot any more: the ordinary editor undo ran (or nothing),
      // but the text is never the pre-insert "a".
      expect(c.text, isNot('a'));
    },
  );
}
