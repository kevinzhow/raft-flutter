import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/message_history_memory.dart';
import 'package:raft_flutter/data/message_history_pages.dart';
import 'package:raft_flutter/data/reading_positions.dart';
import 'package:raft_flutter/platform/workspace_cache.dart';

import 'history_memory_test.dart' show HistoryClient, receiver, row;

void main() {
  for (final thread in [false, true]) {
    for (final anchor in ['missing', 'stale-tail', 'current']) {
      test(
        '${thread ? 'thread' : 'main'} restored context survives memory trimming with a $anchor view anchor and retained tail bodies',
        () async {
          final db = DriftWorkspaceCache(
            NativeDatabase.memory(),
            automaticHistoryMaintenance: false,
          );
          final firstClient = HistoryClient();
          final first = receiver(firstClient, db);
          db.messageHistory.memory.unregister(first);
          final id = thread ? 'thread' : 'chat';
          try {
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
            first.messageDomain.saveReadingAnchor(
              id,
              ReadingAnchor('$id-43', -13),
            );
            await first.flushCache();
          } finally {
            first.dispose();
            await firstClient.arrivals.close();
          }
          final client = HistoryClient()..offline = true;
          final w = receiver(client, db);
          db.messageHistory.memory.unregister(w);
          try {
            // Startup/server return can already retain the latest 500 bodies
            // when the durable reading context replaces visible membership.
            w.messageDomain.ledger.ingest([
              for (var n = 501; n <= 1000; n++) row(id, n),
            ], expectedGeneration: w.messageDomain.ledger.generation);
            await w.selectChannel(w.channels.single, autoRead: false);
            if (thread) {
              await w.openThreadIdentity(
                parentChannelId: 'chat',
                parentMessageId: 'chat-1000',
                initialThreadChannelId: 'thread',
                navigate: false,
              );
            }
            final shown = (thread ? w.replies : w.messageDomain.messages)
                .map((m) => m.id)
                .toSet();
            expect(shown, contains('$id-43'));
            expect(shown.length, lessThan(100));
            expect(
              w.messageDomain.ledger.messages(id).length,
              greaterThan(500),
            );
            expect(w.foreground, isTrue);
            expect(
              thread
                  ? w.messageDomain.threadWindow!.hasNewer
                  : w.messageDomain.state.hasNewer,
              isTrue,
            );
            if (anchor == 'missing') {
              w.messageWindows.clearReadingAnchor(id);
            } else if (anchor == 'stale-tail') {
              w.messageWindows.saveReadingAnchor(
                id,
                ReadingAnchor('$id-999', 0),
              );
            }
            MessageHistoryMemory.attach(w, db.messageHistory);
            await db.messageHistory.memory.maintain();
            final kept = thread ? w.replies : w.messageDomain.messages;
            expect(
              kept.map((m) => m.id),
              containsAll(shown),
              reason:
                  'Trimming a retained tail must not empty the active context',
            );
            expect(
              w.messageDomain.ledger.messages(id).length,
              lessThanOrEqualTo(500),
            );
            final scope = MessageHistoryPages.scope(
              w,
              id,
              parent: thread ? 'chat' : id,
              parentMessage: thread ? 'chat-1000' : null,
            )!;
            expect(
              (await db.messageHistory.readContext(
                scope,
                '$id-1',
                radius: 0,
              ))!['messages'],
              hasLength(1),
            );
            expect(client.oldReads, 0);
          } finally {
            await w.flushCache();
            w.dispose();
            await client.arrivals.close();
            await db.close();
          }
        },
      );
    }
  }
}
