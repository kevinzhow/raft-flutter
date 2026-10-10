import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_context_transition_test.dart' show row;
import 'message_presentation_test.dart' show fixture;

/// Source threadStore keeps a thread's messages after it closes: reopening an
/// accepted thread shows its replies and parent at once and revalidates them
/// in the background, without a loading state.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final focused in [false, true]) {
    testWidgets(
      'reopening an accepted thread${focused ? ' at a reply' : ''} shows it at once',
      (tester) async {
        tester.view.physicalSize = const Size(900, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final (w, api) = (await tester.runAsync(() => fixture('member')))!;
        addTearDown(w.dispose);
        w.ledger.switchServer('s1');
        final replies = [
          for (var i = 0; i < 3; i++) row('reply-$i', 'thread-1', i + 1),
        ];
        api.routes['GET /messages/context/parent'] = (_) => {
          'messages': [row('parent', 'c1', 1)],
        };
        api.routes['GET /messages/channel/thread-1'] = (_) => {
          'messages': replies,
        };
        api.routes['GET /messages/context/reply-1'] = (_) => {
          'messages': replies,
          'hasOlder': false,
          'hasNewer': false,
        };
        api.routes['GET /messages/context/other'] = (_) => {
          'messages': [row('other', 'c1', 2)],
        };
        api.routes['GET /messages/channel/thread-2'] = (_) => {
          'messages': [row('other-reply', 'thread-2', 1)],
        };
        Future<void> open(String parent, String thread) => w.openThreadIdentity(
          parentChannelId: 'c1',
          parentMessageId: parent,
          initialThreadChannelId: thread,
          focusedMessageId: focused && parent == 'parent' ? 'reply-1' : null,
          navigate: false,
        );
        await tester.runAsync(() async {
          await open('parent', 'thread-1');
          for (var i = 0; i < 40 && w.threadParentLoading; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 5));
          }
          await open('other', 'thread-2');
        });
        expect(w.threadChannelId, 'thread-2');

        // The revalidation never answers; the cached window must carry.
        final pending = Completer<Map<String, dynamic>>();
        api.routes['GET /messages/context/parent'] = (_) => pending.future;
        api.routes['GET /messages/channel/thread-1'] = (_) => pending.future;
        api.routes['GET /messages/context/reply-1'] = (_) => pending.future;
        await tester.runAsync(() async {
          unawaited(open('parent', 'thread-1'));
          expect(w.threadLoading, false);
          expect(w.threadParentLoading, false);
          expect(w.presentedThreadParent?.id, 'parent');
          expect(w.replies.map((m) => m.id), ['reply-0', 'reply-1', 'reply-2']);
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(RaftFamily.elegant),
            home: Scaffold(body: RaftChatView(controller: w, thread: true)),
          ),
        );
        await tester.pump();
        expect(find.text('Loading...'), findsNothing);
        expect(find.text('Message reply-2'), findsOneWidget);
        await tester.runAsync(() async {
          pending.complete({
            'messages': [
              ...replies,
              if (!focused) row('reply-3', 'thread-1', 4),
            ],
          });
          await Future<void>.delayed(const Duration(milliseconds: 20));
        });
        await tester.pump();
        // The revalidated window replaces the cached one in place.
        expect(find.text('Loading...'), findsNothing);
        expect(w.threadLoading, false);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 5));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
