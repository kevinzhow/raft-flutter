import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

const choices = [
  RaftComposerSuggestion(
    type: 'user',
    id: 'human-id',
    name: 'same',
    title: 'Human Same',
  ),
  RaftComposerSuggestion(
    type: 'agent',
    id: 'agent-id',
    name: 'same',
    title: 'Agent Same',
  ),
  RaftComposerSuggestion(type: 'channel', id: 'channel-id', name: 'design'),
];
void main() {
  test('structured identity appears only in visible exact handle, including adjacent Chinese text', () {
    expect(raftStructuredMentionAppears('草案@Mona', 'Mona'), isTrue);
    expect(raftStructuredMentionAppears('draft@Mona', 'Mona'), isTrue);
    expect(raftStructuredMentionAppears('草案@Mona继续', 'Mona'), isFalse);
    expect(raftStructuredMentionAppears('`@Mona`', 'Mona'), isFalse);
    expect(raftStructuredMentionAppears('```\n@Mona\n```', 'Mona'), isFalse);
    expect(
      raftStructuredMentionAppears('[@Mona](<app:system.test>)', 'Mona'),
      isFalse,
    );
  });
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      'keyboard binds selected duplicate handle identity and failed retry retains it: $family/$dark',
      (tester) async {
        final sends = <List<Map<String, dynamic>>>[];
        var success = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: Scaffold(
              body: Column(
                children: [
                  const Spacer(),
                  RaftComposer(
                    suggestions: choices,
                    onSend: (_) async => false,
                    onSendWithMentions: (_, mentions) async {
                      sends.add(mentions);
                      return success;
                    },
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.enterText(find.byType(TextField), '@sa');
        await tester.pump();
        expect(
          find.byKey(const ValueKey('composer-suggestion-user-human-id')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('composer-suggestion-agent-agent-id')),
          findsOneWidget,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .controller
              .text,
          '@same ',
        );
        expect(sends, isEmpty); // Enter accepts completion rather than sending.
        await tester.tap(find.byTooltip('Send message (Ctrl+Enter)'));
        await tester.pump();
        expect(sends.single, [
          {'type': 'agent', 'id': 'agent-id', 'name': 'same'},
        ]);
        success = true;
        await tester.tap(find.byTooltip('Send message (Ctrl+Enter)'));
        await tester.pump();
        expect(sends.last, sends.first);
        expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .controller
              .text,
          isEmpty,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'channel name keeps intrinsic basis and description receives remaining width',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.brutal),
          home: Scaffold(
            body: Column(
              children: [
                const Spacer(),
                RaftComposer(
                  suggestions: const [
                    RaftComposerSuggestion(
                      type: 'channel',
                      id: 'design',
                      name: 'design',
                      detail: 'Product and UI decisions',
                    ),
                  ],
                  onSend: (_) async => true,
                ),
              ],
            ),
          ),
        ),
      );
      await t.enterText(find.byType(TextField), '#');
      await t.pump();
      final title = find.text('design'),
          meta = find.text('Product and UI decisions');
      expect(t.getTopLeft(meta).dx - t.getTopRight(title).dx, closeTo(6, .01));
      final option = find.byKey(
        const ValueKey('composer-suggestion-channel-design'),
      );
      expect(
        t.getTopRight(meta).dx,
        greaterThan(t.getTopRight(option).dx - 20),
      );
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pump();
      expect(
        t.widget<EditableText>(find.byType(EditableText)).controller.text,
        '#design ',
      );
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'channel Tab inserts text; Escape and IME keep draft intact; edited code does not send bound mention',
    (tester) async {
      String? sent;
      List<Map<String, dynamic>>? payload;
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Scaffold(
            body: Column(
              children: [
                const Spacer(),
                RaftComposer(
                  suggestions: choices,
                  onSend: (_) async => false,
                  onSendWithMentions: (text, mentions) async {
                    sent = text;
                    payload = mentions;
                    return false;
                  },
                ),
              ],
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), '#des');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final field = tester.widget<EditableText>(find.byType(EditableText));
      expect(field.controller.text, '#design ');
      await tester.enterText(find.byType(TextField), '@sa');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(field.controller.text, '@sa');
      expect(find.byType(ListTile), findsNothing);
      field.controller.value = const TextEditingValue(
        text: '@sa日本',
        selection: TextSelection.collapsed(offset: 5),
        composing: TextRange(start: 3, end: 5),
      );
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(sent, isNull);
      expect(field.controller.text, '@sa日本');
      await tester.enterText(find.byType(TextField), '@sa');
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('composer-suggestion-user-human-id')),
      );
      await tester.pump();
      await tester.enterText(find.byType(TextField), '`@same`');
      await tester.tap(find.byTooltip('Send message (Ctrl+Enter)'));
      await tester.pump();
      expect(sent, '`@same`');
      expect(payload, isEmpty);
    },
  );
}
