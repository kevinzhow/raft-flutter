import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/message_history_pages.dart';
import 'package:raft_flutter/data/reading_positions.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/platform/workspace_cache.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'history_memory_test.dart' show HistoryClient, receiver;
import 'history_memory_viewport_test.dart' show drainIo;

void main() {
  for (final thread in [false, true]) {
    testWidgets(
      '${thread ? 'thread' : 'channel'} local context end preserves the durable old reading position through resize and unmount',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(1200, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final (db, client, w) = (await tester.runAsync(() async {
          final db = DriftWorkspaceCache(
            NativeDatabase.memory(),
            automaticHistoryMaintenance: false,
          );
          final client = HistoryClient();
          final first = receiver(client, db);
          db.messageHistory.memory.unregister(first);
          await first.selectChannel(first.channels.single, autoRead: false);
          if (thread) {
            await first.openThreadIdentity(
              parentChannelId: 'chat',
              parentMessageId: 'chat-1000',
              initialThreadChannelId: 'thread',
              navigate: false,
            );
          }
          for (var n = 0; n < 19; n++) {
            await first.messageDomain.older(thread: thread);
          }
          final id = thread ? 'thread' : 'chat';
          first.messageDomain.saveReadingAnchor(
            id,
            ReadingAnchor('$id-43', -13),
          );
          await first.flushCache();
          first.dispose();
          await client.arrivals.close();
          final offline = HistoryClient()..offline = true;
          final restored = receiver(offline, db);
          db.messageHistory.memory.unregister(restored);
          await restored.selectChannel(
            restored.channels.single,
            autoRead: false,
          );
          if (thread) {
            await restored.openThreadIdentity(
              parentChannelId: 'chat',
              parentMessageId: 'chat-1000',
              initialThreadChannelId: 'thread',
              navigate: false,
            );
          }
          await restored.flushCache();
          return (db, offline, restored);
        }))!;
        final id = thread ? 'thread' : 'chat';
        try {
          final scope = MessageHistoryPages.scope(
            w,
            id,
            parent: thread ? 'chat' : id,
            parentMessage: thread ? 'chat-1000' : null,
          )!;
          expect(
            thread
                ? w.messageDomain.threadWindow!.hasNewer
                : w.messageDomain.state.hasNewer,
            isTrue,
          );
          expect(
            (await tester.runAsync(
              () => db.messageHistory.readPosition(scope),
            ))!.messageId,
            '$id-43',
          );
          await tester.pumpWidget(
            MaterialApp(
              theme: raftTheme(RaftFamily.elegant),
              home: Scaffold(
                body: RaftChatView(controller: w, thread: thread),
              ),
            ),
          );
          await tester.pumpAndSettle();
          // The loaded context fits this viewport. Its local end is visible,
          // while the accepted history still has newer messages after it.
          tester.view.physicalSize = const Size(1180, 1600);
          await tester.pumpAndSettle();
          await drainIo(tester, w.flushCache());
          final afterResize = await tester.runAsync(
            () => db.messageHistory.readPosition(scope),
          );
          expect(
            afterResize,
            isNotNull,
            reason: 'A local context end is not the conversation latest end',
          );
          expect(afterResize!.sequence, lessThan(BigInt.from(1000)));
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
          await drainIo(tester, w.flushCache());
          expect(
            await tester.runAsync(() => db.messageHistory.readPosition(scope)),
            isNotNull,
            reason: 'Unmount must preserve the old position for a new process',
          );
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
          await drainIo(tester, w.flushCache());
          w.dispose();
          await drainIo(tester, client.arrivals.close());
          await drainIo(tester, db.close());
        }
      },
    );
  }
}
