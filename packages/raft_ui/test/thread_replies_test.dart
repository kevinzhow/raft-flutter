import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  RaftThreadReplyPreview reply(String id, {String type = 'user'}) =>
      RaftThreadReplyPreview(
        id: id,
        author: '林・日本語 $id',
        preview: '中文设计 $id',
        senderType: type,
        timestamp: '12:34',
      );
  testWidgets(
    'system events consume no slot and do not change authoritative count',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Scaffold(
            body: RaftThreadReplies(
              replyCount: 12,
              replies: [
                reply('system', type: 'system'),
                reply('one'),
                reply('two', type: 'agent'),
                reply('three', type: 'external_projection'),
                reply('four'),
              ],
              onOpen: () {},
              onOpenReply: (_) {},
            ),
          ),
        ),
      );
      expect(find.text('12 replies'), findsOneWidget);
      for (final id in ['one', 'two', 'three']) {
        expect(find.byKey(ValueKey('thread-preview-$id')), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('thread-preview-system')), findsNothing);
      expect(find.byKey(const ValueKey('thread-preview-four')), findsNothing);
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Scaffold(
            body: RaftThreadReplies(
              replyCount: 1,
              replies: [reply('system', type: 'system')],
              onOpen: () {},
              onOpenReply: (_) {},
            ),
          ),
        ),
      );
      expect(find.byType(TextButton), findsNothing);
    },
  );
  for (final theme in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      'CJK reply pointer, keyboard and semantics at phone width ${theme.$1}/${theme.$2}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final semantics = tester.ensureSemantics();
        try {
          String? selected;
          var opens = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: raftTheme(theme.$1, dark: theme.$2),
              home: Scaffold(
                body: RaftThreadReplies(
                  replyCount: 5,
                  unreadCount: 2,
                  hasDraft: true,
                  replies: [
                    reply('human'),
                    reply('agent', type: 'agent'),
                  ],
                  onOpen: () => opens++,
                  onOpenReply: (id) => selected = id,
                ),
              ),
            ),
          );
          final row = find.byKey(const ValueKey('thread-preview-human'));
          expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
          expect(
            find.bySemanticsLabel('Open reply by 林・日本語 human: 中文设计 human'),
            findsOneWidget,
          );
          await tester.tap(row);
          expect(selected, 'human');
          selected = null;
          bool focusesRow() {
            final focused = FocusManager.instance.primaryFocus?.context;
            if (focused is! Element) return false;
            var found = false;
            focused.visitAncestorElements((element) {
              if (element == tester.element(row)) {
                found = true;
                return false;
              }
              return true;
            });
            return found;
          }

          for (var i = 0; i < 6 && !focusesRow(); i++) {
            await tester.sendKeyEvent(LogicalKeyboardKey.tab);
            await tester.pump();
          }
          expect(
            focusesRow(),
            isTrue,
            reason: 'Tab must focus the reply button',
          );
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pump();
          expect(selected, 'human');
          await tester.tap(find.text('5 replies · 2 new · Draft'));
          expect(opens, 1);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );
  }
}
