import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/message_history.dart';
import 'package:raft_flutter/data/message_history_pages.dart';
import 'package:raft_flutter/data/reading_positions.dart';
import 'package:raft_flutter/platform/workspace_cache.dart';

import 'history_capacity_test.dart' as fixture;
import 'history_memory_test.dart' show HistoryClient, receiver;

void main() {
  for (final thread in [false, true]) {
    test(
      'saved ${thread ? 'thread' : 'channel'} position survives a real-file offline restart and latest clears it',
      () async {
        final dir = await Directory.systemTemp.createTemp(
          'raft-reading-position-',
        );
        final file = File('${dir.path}/workspace.sqlite');
        addTearDown(() => dir.delete(recursive: true));
        final first = DriftWorkspaceCache(NativeDatabase(file)),
            client = HistoryClient();
        final w = receiver(client, first);
        final id = thread ? 'thread' : 'chat';
        try {
          await w.selectChannel(w.channels.single, autoRead: false);
          if (thread) {
            await w.openThreadIdentity(
              parentChannelId: 'chat',
              parentMessageId: 'chat-1000',
              initialThreadChannelId: 'thread',
              navigate: false,
            );
          }
          for (var n = 0; n < 19; n++) {
            await w.messageDomain.older(thread: thread);
          }
          w.messageDomain.saveReadingAnchor(
            id,
            ReadingAnchor('$id-200', -12.25),
          );
          await w.flushCache();
          final scope = MessageHistoryPages.scope(
            w,
            id,
            parent: thread ? 'chat' : id,
            parentMessage: thread ? 'chat-1000' : null,
          )!;
          expect(
            (await first.messageHistory.readPosition(scope))!.messageId,
            '$id-200',
          );
        } finally {
          await w.flushCache();
          w.dispose();
          await client.arrivals.close();
          await first.close();
        }
        final second = DriftWorkspaceCache(NativeDatabase(file)),
            offline = HistoryClient()..offline = true;
        final restored = receiver(offline, second);
        try {
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
          final rows = thread
              ? restored.replies
              : restored.messageDomain.messages;
          expect(rows.map((row) => row.id), contains('$id-200'));
          expect(
            thread
                ? restored.messageDomain.threadWindow!.hasNewer
                : restored.messageDomain.state.hasNewer,
            isTrue,
          );
          expect(restored.messageWindows.readingAnchor(id)!.top, -12.25);
          expect(offline.oldReads, 0);
          await restored.messageDomain.returnToLatest(
            thread: thread,
            navigate: false,
          );
          expect(
            (thread ? restored.replies : restored.messageDomain.messages)
                .last
                .seq,
            BigInt.from(1000),
          );
          expect(
            thread
                ? restored.messageDomain.threadWindow!.hasNewer
                : restored.messageDomain.state.hasNewer,
            isFalse,
          );
          final scope = MessageHistoryPages.scope(
            restored,
            id,
            parent: thread ? 'chat' : id,
            parentMessage: thread ? 'chat-1000' : null,
          )!;
          expect(await second.messageHistory.readPosition(scope), isNull);
          expect(offline.oldReads, 0);
        } finally {
          await restored.flushCache();
          restored.dispose();
          await offline.arrivals.close();
          await second.close();
        }
      },
    );
  }

  test('saved anchors are account scoped, protected from capacity eviction, and purged on revoke', () async {
    final cache = DriftWorkspaceCache(
      NativeDatabase.memory(),
      historyBudget: 128 << 10,
      historyHardLimitEnabled: false,
      automaticHistoryMaintenance: false,
    );
    addTearDown(cache.close);
    final history = cache.messageHistory, scope = fixture.scope('chat');
    await history.acceptEvents(
      scope,
      fixture.rows('chat', 1, 100, bytes: 8192),
    );
    await history.savePosition(
      scope,
      SavedReadingPosition('chat-1', BigInt.one, -4),
    );
    await history.capacity.maintain(fixture.account);
    expect(await history.readContext(scope, 'chat-1', radius: 0), isNotNull);
    final other = MessageHistoryScope(
      origin: scope.origin,
      principal: 'other',
      server: scope.server,
      channel: scope.channel,
      parentChannel: scope.parentChannel,
      authority: scope.authority,
    );
    expect(await history.readPosition(other), isNull);
    await cache.revokeChannel(
      scope.origin,
      scope.principal,
      scope.server,
      scope.channel,
    );
    expect(await history.readPosition(scope), isNull);
    expect(
      (await cache
              .customSelect(
                "SELECT count(*) AS n FROM workspace_cache WHERE kind='history-anchor'",
              )
              .getSingle())
          .read<int>('n'),
      0,
    );
  });
}
