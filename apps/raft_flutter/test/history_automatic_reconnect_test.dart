import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/message_history_pages.dart';

import 'support/history_automatic_fixture.dart';

void main() {
  for (final scenario in [
    'edit',
    'delete',
    'reaction',
    'thread reply count',
    'second device edit',
    'replay window expired',
    'message moved',
  ]) {
    test(
      '$scenario during disconnection converges without a user action',
      () async {
        // Initial: a freshly verified 100-message cache, including old visible rows.
        // Event: another session changes server data; reconnect has no new sequence.
        // Expected: both current display and persisted bodies match the server.
        final c = HistoryAuditCase();
        addTearDown(c.close);
        await c.seed();
        c.client.incoming.add(const RaftEvent('disconnected', null));
        switch (scenario) {
          case 'delete' || 'message moved':
            c.client.deleted.add(25);
          case 'reaction':
            c.client.patches[25] = {
              'reactions': [
                {'emoji': '👍', 'count': 3},
              ],
            };
          case 'thread reply count':
            c.client.summaries = {
              'm25': {'replyCount': 4, 'threadChannelId': 'thread'},
            };
          default:
            c.client.edits[25] = 'Changed by another session';
        }
        if (scenario == 'replay window expired') {
          c.now = c.now.add(const Duration(days: 30));
          c.client.incoming.add(
            const RaftEvent('sync:resume:response', {
              'currentSeq': '100',
              'messages': [],
            }),
          );
        }
        await c.reconnect();
        final scope = MessageHistoryPages.scope(c.w, 'chat')!;
        final saved = await c.cache.messageHistory.readContext(
          scope,
          'm25',
          radius: 0,
        );
        switch (scenario) {
          case 'delete' || 'message moved':
            expect(c.w.messageDomain.ledger.message('chat', 'm25'), isNull);
            expect(saved, isNull);
          case 'reaction':
            expect(
              c.w.messageDomain.ledger.message('chat', 'm25')?['reactions'],
              c.client.patches[25]!['reactions'],
            );
            expect(
              (saved?['messages'] as List?)?.single['reactions'],
              c.client.patches[25]!['reactions'],
            );
          case 'thread reply count':
            expect(
              c.w.messageDomain.threadSummariesFor(
                'chat',
              )['m25']?['replyCount'],
              4,
            );
          default:
            expect(
              c.w.messageDomain.ledger.message('chat', 'm25')?['content'],
              'Changed by another session',
            );
            expect(
              (saved?['messages'] as List?)?.single['content'],
              'Changed by another session',
            );
        }
        expect(c.w.error, isNull);
      },
    );
  }

  test('removed member clears visible and durable history despite automatic protection', () async {
    // Initial: open cached private channel. Event: membership is removed.
    // Expected: neither automatic protection nor a late response restores it.
    final c = HistoryAuditCase();
    addTearDown(c.close);
    await c.seed();
    final scope = MessageHistoryPages.scope(c.w, 'chat')!;
    c.client.incoming.add(
      const RaftEvent('channel:removed', {'channelId': 'chat'}),
    );
    await c.w.flushCache();
    expect(c.w.messageDomain.messages, isEmpty);
    expect(
      await c.cache.messageHistory.readContext(scope, 'm25', radius: 0),
      isNull,
    );
  });
  test(
    'archive keeps authorized read-only history and updates channel status',
    () async {
      // Initial: an authorized member has cached rows. Event: channel is archived.
      // Expected: history remains readable; archive does not itself revoke read access.
      final c = HistoryAuditCase();
      addTearDown(c.close);
      await c.seed();
      c.client.channelRecord = {
        ...c.w.channels.single.json,
        'archivedAt': '2026-10-16T00:00:00Z',
      };
      await c.w.refreshChannel('chat');
      await c.w.flushCache();
      expect(c.w.channels.single.archived, isTrue);
      final scope = MessageHistoryPages.scope(c.w, 'chat')!;
      expect(
        await c.cache.messageHistory.readContext(scope, 'm25', radius: 0),
        isNotNull,
      );
    },
  );

  test('transient verification failure retries automatically while the socket stays connected', () async {
    // Initial: saved old row; reconnect HTTP temporarily fails although the
    // socket is online. Event: server recovers without another user action.
    // Expected: bounded background retry converges on the same connection.
    final c = HistoryAuditCase();
    addTearDown(c.close);
    await c.seed();
    c.w.connected = true;
    c.client.edits[25] = 'Recovered automatically';
    c.client.failure = const RaftApiException(
      'Temporary server error',
      status: 503,
    );
    await c.reconnect();
    expect(
      c.w.messageDomain.ledger.message('chat', 'm25')?['content'],
      'Body 25',
    );
    c.client.failure = null;
    c.client.started = Completer<void>();
    await c.client.started!.future.timeout(const Duration(seconds: 6));
    await c.cache.messageHistory.reads.settled;
    expect(
      c.w.messageDomain.ledger.message('chat', 'm25')?['content'],
      'Recovered automatically',
    );
    expect(c.w.error, isNull);
  });

  test('backdated server message inserted between cached pages appears on reconnect', () async {
    // Initial: pages cover 1–100, but the server held back row 25.
    // Event: row 25 arrives with its old sequence, so tail-only sync cannot see it.
    // Expected: range verification inserts it, preserving all other rows.
    final c = HistoryAuditCase();
    addTearDown(c.close);
    c.client.deleted.add(25);
    await c.w.selectChannel(c.w.channels.single, autoRead: false);
    await c.w.messageDomain.older();
    await c.cache.messageHistory.reads.settled;
    c.client.deleted.remove(25);
    await c.reconnect();
    expect(
      c.w.messageDomain.ledger.message('chat', 'm25')?['content'],
      'Body 25',
    );
    expect(c.w.messageDomain.messages.length, 100);
  });
}
