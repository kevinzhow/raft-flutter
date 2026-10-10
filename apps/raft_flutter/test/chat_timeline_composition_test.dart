import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart' show Chat;
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show fixture;

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    for (final thread in [false, true]) {
      testWidgets(
        'actual sparse timeline geometry and resize $family/$dark/thread=$thread',
        (t) async {
          final (w, _) = (await t.runAsync(() => fixture('owner')))!;
          addTearDown(w.dispose);
          await t.binding.setSurfaceSize(const Size(390, 720));
          addTearDown(() => t.binding.setSurfaceSize(null));
          w.ledger.switchServer('s1');
          final channelId = thread ? 'thread-c1' : 'c1';
          if (thread) {
            w.threadParent = RaftMessage({
              'id': 'parent',
              'channelId': 'c1',
              'seq': 1,
              'senderType': 'user',
              'senderId': 'alice',
              'content': 'Public parent',
            });
            w.threadChannelId = channelId;
          }
          w.ledger.ingest([
            for (var i = 1; i <= 2; i++)
              {
                'id': 'row-$i',
                'channelId': channelId,
                'seq': i,
                'senderType': 'user',
                'senderId': 'alice',
                'content': 'Public row $i',
                'createdAt': '2026-06-22T02:30:00Z',
              },
          ], expectedGeneration: w.ledger.generation);
          w.visibleIds[channelId] = {'row-1', 'row-2'};
          await t.pumpWidget(
            MaterialApp(
              theme: raftTheme(family, dark: dark),
              home: Scaffold(
                body: RaftDensityScope(
                  density: RaftDensity.desktop,
                  child: RaftChatView(controller: w, thread: thread),
                ),
              ),
            ),
          );
          await t.pumpAndSettle();
          // The two-sided timeline needs no measured tail spacer: a short
          // thread rests at its top, a short channel at its latest end with
          // the history state filling the space above.
          expect(find.byType(RaftSparseTimelineSliver), findsNothing);
          if (!thread) {
            final chat = t.getRect(find.byType(Chat));
            final beginning = t.getRect(find.text('Beginning of messages'));
            expect(beginning.top - chat.top, lessThan(48));
          }
          expect(
            find.byType(RaftConversationDateHeader),
            thread ? findsNothing : findsOneWidget,
          );
          expect(
            find.text(
              thread ? 'Beginning of replies' : 'Beginning of messages',
            ),
            findsOneWidget,
          );
          final chatRect = t.getRect(find.byType(Chat));
          final footerRect = t.getRect(find.byType(RaftTimelineFooter));
          if (thread) {
            expect(footerRect.bottom, lessThan(chatRect.bottom));
            expect(
              find.byKey(const ValueKey('message-parent')),
              findsOneWidget,
            );
          } else {
            expect(footerRect.bottom, closeTo(chatRect.bottom, .01));
            expect(footerRect.height, 24);
          }
          final first = t.getRect(find.byKey(const ValueKey('message-row-1')));
          expect(first.left, 12);
          expect(first.right, 378);
          final mountedRow = t.widget<RaftMessageTile>(
            find.byKey(const ValueKey('message-row-1')),
          );
          expect(
            mountedRow.rowContext,
            thread ? RaftMessageRowContext.thread : RaftMessageRowContext.main,
          );
          if (thread) {
            expect(
              find.byKey(const ValueKey('message-wrapper-parent')),
              findsNothing,
            );
            expect(
              t
                  .widget<RaftMessageTile>(
                    find.byKey(const ValueKey('message-parent')),
                  )
                  .rowContext,
              RaftMessageRowContext.thread,
            );
          } else {
            expect(
              t.getRect(find.byType(RaftConversationDateHeader)).width,
              390,
            );
          }
          final composer = find.byType(RaftComposer);
          final composerState = t.state(composer);
          expect(
            t.widget<RaftComposer>(composer).hint,
            thread ? 'Message thread' : startsWith('Message #'),
          );
          expect(
            t
                .widgetList<RaftMessageBody>(find.byType(RaftMessageBody))
                .every((body) => body.mountedMessage),
            isTrue,
          );
          final editor = find.descendant(
            of: composer,
            matching: find.byType(TextField),
          );
          expect(t.widget<RaftComposer>(composer).autofocus, thread);
          expect(t.widget<TextField>(editor).focusNode!.hasFocus, thread);
          await t.enterText(editor, 'Public retained 中文');
          await t.pump();
          await t.binding.setSurfaceSize(const Size(390, 800));
          await t.pumpAndSettle();
          expect(t.state(composer), same(composerState));
          expect(
            t.widget<TextField>(editor).controller!.text,
            'Public retained 中文',
          );
          final resized = t.getRect(
            find.byKey(const ValueKey('message-row-1')),
          );
          expect(resized.top - first.top, closeTo(thread ? 0 : 80, .01));
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox());
          await t.pump(const Duration(seconds: 1));
        },
      );
    }
  }
}
