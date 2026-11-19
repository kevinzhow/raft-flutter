import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  for (final (platform, modifier) in [
    (TargetPlatform.linux, LogicalKeyboardKey.controlLeft),
    (TargetPlatform.macOS, LogicalKeyboardKey.metaLeft),
  ]) {
    testWidgets('modified Enter sends and bare Enter inserts on $platform', (
      tester,
    ) async {
      final sent = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(dark: false).copyWith(platform: platform),
          home: Scaffold(
            body: RaftComposerSendKeyScope(
              sendKey: RaftComposerSendKey.modifiedEnter,
              child: RaftComposer(
                onSend: (text) async {
                  sent.add(text);
                  return true;
                },
              ),
            ),
          ),
        ),
      );
      final field = find.byType(TextField);
      await tester.enterText(field, 'first line');
      await tester.pump();
      expect(
        find.text(
          platform == TargetPlatform.macOS
              ? '⌘Enter to send'
              : 'Ctrl+Enter to send',
        ),
        findsOneWidget,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(sent, isEmpty);
      expect(tester.widget<TextField>(field).controller!.text, 'first line\n');

      await tester.enterText(field, 'first line\nsecond line');
      await tester.sendKeyDownEvent(modifier);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(modifier);
      await tester.pump();
      expect(sent, ['first line\nsecond line']);
      expect(find.textContaining('to send'), findsNothing);
    });
  }
}
