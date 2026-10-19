import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/history_capacity.dart';
import 'package:raft_flutter/data/message_history_pages.dart';
import 'package:raft_flutter/platform/workspace_cache.dart';

import 'history_capacity_test.dart' as f;
import 'support/history_automatic_fixture.dart';

void main() {
  test('1.5 target hard limit preserves protected bodies and drafts but rejects growth', () async {
    // Initial: protected cache below target. Event: grows past target then hard ceiling.
    // Expected: reject the last batch atomically, preserving prior cache and draft.
    final cache = DriftWorkspaceCache(
      NativeDatabase.memory(),
      historyBudget: 128 << 10,
      automaticHistoryMaintenance: false,
      historyAvailableSpace: (_) async => 2 << 30,
    );
    addTearDown(cache.close);
    final cap = cache.messageHistory.capacity;
    cap.protect(
      Object(),
      () => [
        HistoryProtectedRows(f.account, 'one', 'chat', [], wholeChannel: true),
      ],
    );
    await f.store(cache, f.scope('chat'), f.rows('chat', 1, 6));
    await cache.write(f.account.origin, 'alice', 'one', 'draft', 'chat', {
      'text': 'Unsent',
      'channelId': 'chat',
    });
    await cache.messageHistory.acceptEvents(
      f.scope('chat'),
      f.rows('chat', 7, 12),
    );
    await cap.maintain(f.account);
    final before = await cap.usage(f.account);
    expect(before.retainedCharge, greaterThan(before.budget));
    await expectLater(
      cache.messageHistory.acceptEvents(
        f.scope('chat'),
        f.rows('chat', 13, 18),
      ),
      throwsA(isA<HistoryCapacityExceeded>()),
    );
    expect((await cap.usage(f.account)).rows, 12);
    expect((await cap.usage(f.account)).hardFull, isTrue);
    expect(
      await cache.messageHistory.readContext(
        f.scope('chat'),
        'chat-1',
        radius: 0,
      ),
      isNotNull,
    );
    expect(
      (await cache.read(
        f.account.origin,
        'alice',
        'one',
        'draft',
        'chat',
      ))['text'],
      'Unsent',
    );
  });

  test('less than 1 GiB free rejects cache growth, then space release restores admission', () async {
    var free = 2 << 30;
    final cache = DriftWorkspaceCache(
      NativeDatabase.memory(),
      automaticHistoryMaintenance: false,
      historyAvailableSpace: (_) async => free,
    );
    addTearDown(cache.close);
    await f.store(cache, f.scope('chat'), f.rows('chat', 1, 1));
    free = 512 << 20;
    await expectLater(
      cache.messageHistory.acceptEvents(f.scope('chat'), f.rows('chat', 2, 2)),
      throwsA(isA<HistoryCapacityExceeded>()),
    );
    expect(
      await cache.messageHistory.readContext(
        f.scope('chat'),
        'chat-1',
        radius: 0,
      ),
      isNotNull,
    );
    free = 2 << 30;
    await cache.messageHistory.acceptEvents(
      f.scope('chat'),
      f.rows('chat', 2, 2),
    );
    expect(
      await cache.messageHistory.readContext(
        f.scope('chat'),
        'chat-2',
        radius: 0,
      ),
      isNotNull,
    );
  });

  test('online live content remains visible without notices; reconnect saves it after space recovers', () async {
    var free = 2 << 30;
    final c = HistoryAuditCase(space: (_) async => free, hardLimit: true);
    addTearDown(c.close);
    await c.seed();
    free = 512 << 20;
    final scope = MessageHistoryPages.scope(c.w, 'chat')!;
    c.client.total = 101;
    c.client.incoming.add(
      const RaftEvent('message:new', {
        'id': 'm101',
        'channelId': 'chat',
        'seq': '101',
        'content': 'Body 101',
        'senderId': 'alice',
        'senderType': 'user',
      }),
    );
    await c.cache.messageHistory.receiver.settled;
    await c.w.flushCache();
    expect(
      c.w.messageDomain.ledger.message('chat', 'm101')?['content'],
      'Body 101',
    );
    expect(
      await c.cache.messageHistory.readContext(scope, 'm101', radius: 0),
      isNull,
    );
    expect(c.w.error, isNull);
    free = 2 << 30;
    await c.reconnect();
    expect(
      await c.cache.messageHistory.readContext(scope, 'm101', radius: 0),
      isNotNull,
    );
    expect(c.w.error, isNull);
  });
}
