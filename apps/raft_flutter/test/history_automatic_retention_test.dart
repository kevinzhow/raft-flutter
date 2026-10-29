import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/history_capacity.dart';
import 'package:raft_flutter/data/workspace_uploads.dart';
import 'package:raft_flutter/data/message_history_pages.dart';
import 'package:raft_flutter/platform/workspace_cache.dart';

import 'history_capacity_test.dart' as f;
import 'support/history_automatic_fixture.dart';

void main() {
  for (final fact in [
    'open window',
    'inflight page',
    'unread',
    'mention',
    'pinned channel',
    'draft',
    'upload',
  ]) {
    test(
      'capacity protects the whole $fact conversation, including offscreen rows',
      () async {
        // Initial: an old, over-budget conversation with 100 saved bodies.
        // Event: the named fact needs that conversation, even while another is selected.
        // Expected: automatic cleanup keeps all 100, not just the visible IDs.
        final c = HistoryAuditCase(budget: 128 << 10);
        addTearDown(c.close);
        final channel = c.w.channels.single;
        final scope = MessageHistoryPages.scope(c.w, 'chat')!;
        await f.store(c.cache, scope, f.rows('chat', 1, 100));
        c.now = c.now.add(const Duration(days: 30));
        switch (fact) {
          case 'inflight page':
            c.w.channel = channel;
            c.w.messageDomain.state.loadingOlder = true;
          case 'open window':
            c.w.channel = channel;
            c.w.messageDomain.visibleIds['chat'] = {'chat-100'};
          case 'unread':
            c.w.conversationReads.unread = {'chat': 1};
          case 'mention':
            c.w.conversationReads.mentions = {'chat'};
          case 'pinned channel':
            c.w.sidebarOrder = {
              'pinned': [
                {'kind': 'channel', 'id': 'chat'},
              ],
            };
          case 'draft':
            c.w.composer.drafts['chat'] = 'Unsent';
          case 'upload':
            c.w.composer.uploads.byScope['chat'] = [
              UploadDraft('large.png', Uint8List.fromList([1]), key: 7),
            ];
        }
        await c.cache.messageHistory.capacity.maintain(
          HistoryAccount(c.client.origin, 'alice'),
        );
        expect(
          (await c.cache.messageHistory.readContext(
            scope,
            'chat-1',
            radius: 0,
          ))?['messages'],
          hasLength(1),
        );
        expect(
          (await c.cache.messageHistory.capacity.usage(
            HistoryAccount(c.client.origin, 'alice'),
          )).rows,
          100,
        );
      },
    );
  }

  for (final kind in ['draft', 'unread', 'sidebar-order']) {
    test(
      'persisted $kind protects a closed conversation before any window restores',
      () async {
        // Initial: account data and history remain on disk; no controller owns it.
        // Event: startup cleanup runs before restoration.
        // Expected: drafts/unread/pins cannot be evicted during that interval.
        final cache = DriftWorkspaceCache(
          NativeDatabase.memory(),
          historyBudget: 128 << 10,
          historyHardLimitEnabled: false,
          automaticHistoryMaintenance: false,
        );
        addTearDown(cache.close);
        await f.store(cache, f.scope('chat'), f.rows('chat', 1, 100));
        await cache.write(
          f.account.origin,
          'alice',
          'one',
          kind,
          kind == 'draft' ? 'chat' : '',
          switch (kind) {
            'draft' => {'channelId': 'chat', 'text': 'Unsent', 'files': []},
            'unread' => {'chat': 1},
            _ => {
              'pinned': [
                {'kind': 'channel', 'id': 'chat'},
              ],
            },
          },
        );
        await cache.messageHistory.capacity.maintain(f.account);
        expect(
          (await cache.messageHistory.capacity.usage(f.account)).rows,
          100,
        );
      },
    );
  }

  test('opened six days ago remains available offline after automatic cleanup', () async {
    // Initial: 100 messages were opened; the window then closes.
    // Event: six days pass and capacity maintenance runs, followed by offline access.
    // Expected: the opened messages are still readable with no network request.
    final c = HistoryAuditCase(budget: 128 << 10);
    addTearDown(c.close);
    c.client.bodyBytes = 8192;
    await c.seed();
    c.w.channel = null;
    c.now = c.now.add(const Duration(days: 6));
    final scope = MessageHistoryPages.scope(c.w, 'chat')!;
    await c.cache.messageHistory.capacity.maintain(
      HistoryAccount(c.client.origin, 'alice'),
    );
    c.client.failure = const RaftApiException('Offline', status: 503);
    final local = await c.cache.messageHistory.readContext(
      scope,
      'm1',
      radius: 0,
    );
    expect(
      ((local?['messages'] as List?)?.single['content'] as String?)?.length,
      8192,
    );
    expect(c.client.calls, isEmpty);
  });

  test(
    'evicted context refills on open without a manual refresh action',
    () async {
      // Initial: an old context was evicted under quota pressure.
      // Event: user opens that message with connectivity.
      // Expected: the normal loader fetches and commits the context silently.
      final c = HistoryAuditCase(budget: 128 << 10);
      addTearDown(c.close);
      final scope = MessageHistoryPages.scope(c.w, 'chat')!;
      await f.store(c.cache, scope, [
        for (var i = 1; i <= 100; i++)
          {
            'id': 'm$i',
            'channelId': 'chat',
            'seq': '$i',
            'content': 'x' * 8192,
          },
      ]);
      await c.cache.messageHistory.capacity.maintain(
        HistoryAccount(c.client.origin, 'alice'),
      );
      expect(
        await c.cache.messageHistory.readContext(scope, 'm1', radius: 0),
        isNull,
      );
      await c.w.jumpToMessage('chat', 'm1');
      await c.cache.messageHistory.reads.settled;
      expect(
        c.w.messageDomain.ledger.message('chat', 'm1')?['content'],
        'Body 1',
      );
      expect(c.w.error, isNull);
    },
  );
}
