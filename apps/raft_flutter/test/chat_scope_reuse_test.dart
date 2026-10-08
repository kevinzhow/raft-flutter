import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/message_selection.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_presentation_test.dart' show fixture;

void main() {
  for (final adaptive in [false, true]) {
    testWidgets(
      adaptive
          ? '360px workspace closes and reopens its focused inline thread without extra notifications'
          : 'same chat State rebinds thread rows and selection on main-thread transitions',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(360, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final (w, a) = (await tester.runAsync(() => fixture('member')))!;
        addTearDown(w.dispose);
        final handle = ChatSelectionHandle();
        addTearDown(handle.dispose);
        w.ledger.switchServer('s1');
        final parent = {
          'id': 'parent',
          'channelId': 'c1',
          'threadId': 'thread',
          'seq': '1',
          'senderId': 'alice',
          'senderType': 'user',
          'senderName': '林',
          'content': 'Parent 中文 日本語',
        };
        final reply = {
          'id': 'reply',
          'channelId': 'thread',
          'seq': '1',
          'senderId': 'alice',
          'senderType': 'user',
          'senderName': '林',
          'content': 'Reply 中文 日本語',
        };
        w.ledger.ingest([
          parent,
          reply,
        ], expectedGeneration: w.ledger.generation);
        w.visibleIds['c1'] = {'parent'};
        w.visibleIds['thread'] = {'reply'};
        w.threadSummaries['parent'] = {
          'replyCount': 1,
          'unreadCount': 1,
          'firstUnreadMessageId': 'reply',
          'latestReplies': [
            {
              'messageId': 'reply',
              'senderType': 'user',
              'senderName': '林',
              'preview': 'Reply 中文 日本語',
            },
          ],
        };
        a.routes['GET /servers/s1/setup-projection'] = (_) => {
          'phase': 'complete',
          'surface': 'complete',
          'blocksChat': false,
        };
        a.routes['GET /channels/threads/followed'] = (_) => {'threads': []};
        a.routes['GET /channels/c1/threads/parent'] = (_) => {
          'threadChannelId': 'thread',
        };
        a.routes['GET /messages/context/reply'] = (_) => {
          'messages': [reply],
        };
        a.routes['POST /channels/thread/read'] = (_) => {};
        await tester.runAsync(
          () => w.openThread(RaftMessage(parent), focusedMessageId: 'reply'),
        );
        Widget application(bool thread) => MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: adaptive
              ? WorkspaceView(
                  controller: w,
                  appearance: const RaftAppearance(),
                  onAppearance: (_) async {},
                  onLogout: () async {},
                )
              : Scaffold(
                  body: RaftChatView(
                    controller: w,
                    thread: thread,
                    selectionHandle: handle,
                  ),
                ),
        );
        await tester.pumpWidget(application(true));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('message-reply')), findsOneWidget);
        Finder chat(bool thread, {bool includeHidden = false}) =>
            find.byWidgetPredicate(
              (widget) => widget is RaftChatView && widget.thread == thread,
              skipOffstage: !includeHidden,
            );
        final original = tester.state(
          chat(adaptive ? false : true, includeHidden: adaptive),
        );
        w.closeThread();
        if (!adaptive) {
          // Let the old thread widget process the close before the next widget
          // configuration arrives, matching the controller-before-layout race.
          await tester.pump();
          await tester.pumpWidget(application(false));
        }
        await tester.pumpAndSettle();
        expect(identical(tester.state(chat(false)), original), isTrue);
        expect(
          find.byKey(const ValueKey('inline-thread-parent')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('message-parent')), findsOneWidget);
        expect(find.byKey(const ValueKey('message-reply')), findsNothing);
        if (!adaptive) {
          tester
              .widget<RaftMessageTile>(
                find.byKey(const ValueKey('message-parent')),
              )
              .onActions!();
          await tester.pumpAndSettle();
          await tester.tap(find.text('Select Message'));
          await tester.pumpAndSettle();
          final toolbar = tester.widget<RaftSelectionToolbar>(
            find.byType(RaftSelectionToolbar),
          );
          expect(toolbar.selected, 2);
          expect(toolbar.total, 2);
          expect(handle.active, isTrue);
          handle.dismiss();
          await tester.pumpAndSettle();
        }
        final open = tester
            .widget<RaftInlineThreadSurface>(
              find.byKey(const ValueKey('inline-thread-parent')),
            )
            .onOpen!;
        await tester.runAsync(() async {
          open();
          for (var i = 0; i < 50 && w.threadLoading; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
        });
        if (!adaptive) await tester.pumpWidget(application(true));
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pumpAndSettle();
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(
          identical(
            tester.state(
              chat(adaptive ? false : true, includeHidden: adaptive),
            ),
            original,
          ),
          isTrue,
        );
        expect(w.highlightedMessageId, 'reply');
        final dynamic state = tester.state(chat(true));
        expect(
          find.byKey(const ValueKey('message-reply')),
          findsOneWidget,
          reason:
              'workspace=${w.replies.map((m) => m.id)} adapter=${state.adapter.messages.map((m) => m.id)} scope=${state.scope} thread=${tester.widget<RaftChatView>(chat(true)).thread} pixels=${state.viewport.hasClients ? state.viewport.position.pixels : null}',
        );
        expect(
          find.byKey(const ValueKey('inline-thread-parent')),
          findsNothing,
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
