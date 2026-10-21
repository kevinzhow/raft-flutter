import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_context_transition_test.dart' show row;
import 'message_presentation_test.dart' show fixture;

/// Thread panel "Back to bottom" on a thread window that needs no reload: the
/// jump must leave the thread open as it was. The thread's parent identity
/// (channel label and menu in the header, the composer's draft scope and
/// enabled state) lives on the visit that opened it; the jump replaces the
/// window epoch, which must not retire that visit.
void main() {
  testWidgets(
    'Back to bottom in a thread keeps its identity, header label and composer',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(900, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final (w, api) = (await tester.runAsync(() => fixture('member')))!;
      addTearDown(w.dispose);
      w.messageDomain.ledger.switchServer('s1');
      final replies = [
        for (var i = 0; i < 80; i++)
          {
            ...row('reply-$i', 'thread-1', i + 1),
            'content': List.filled(i % 4 + 1, 'Reply $i').join('\n'),
          },
      ];
      api.routes['GET /messages/context/parent'] = (_) => {
        'messages': [row('parent', 'c1', 1)],
      };
      api.routes['GET /messages/channel/thread-1'] = (_) => {
        'messages': replies,
      };
      api.routes['POST /channels/thread-1/read'] = (_) => {};
      await tester.runAsync(() async {
        await w.openThreadIdentity(
          parentChannelId: 'c1',
          parentMessageId: 'parent',
          initialThreadChannelId: 'thread-1',
          navigate: false,
        );
        for (var i = 0; i < 40 && w.messageDomain.state.threadLoading; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      });
      final source = w.messageDomain.threadSourceChannel;
      expect(source, isNotNull);
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant, dark: false),
          home: Scaffold(body: RaftChatView(controller: w, thread: true)),
        ),
      );
      await tester.pumpAndSettle();
      final dynamic state = tester.state(find.byType(RaftChatView));
      final ScrollController viewport = state.viewport;
      viewport.jumpTo(viewport.offset - 2400);
      await tester.pumpAndSettle();
      expect(find.text('Back to bottom'), findsOneWidget);

      await tester.tap(find.text('Back to bottom'));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();

      expect(find.byType(RaftTimelineBottomButton), findsNothing);
      // Header: the parent label is built from these.
      expect(w.messageDomain.threadIdentity, isNotNull);
      expect(w.messageDomain.threadParentChannelId, 'c1');
      expect(w.messageDomain.threadParentMessageId, 'parent');
      expect(w.messageDomain.threadSourceChannel, source);
      // Composer: still the thread's, and takes input.
      final field = find.descendant(
        of: find.byType(RaftComposer),
        matching: find.byType(EditableText),
      );
      expect(tester.widget<EditableText>(field).readOnly, isFalse);
      await tester.enterText(field, 'still typing');
      await tester.pump();
      expect(find.text('still typing'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}
