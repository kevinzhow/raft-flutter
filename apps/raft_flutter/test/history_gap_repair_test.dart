import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/message_history.dart';
import 'package:raft_flutter/data/message_history_pages.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/data/workspace_message_windows.dart';
import 'package:raft_flutter/platform/workspace_cache.dart';

import 'history_memory_test.dart' show HistoryClient, receiver, row;
import 'message_history_store_test.dart' as fixture;

/// Sequence numbers are server-wide: consecutive channel messages are sparse.
class RepairGapClient extends HistoryClient {
  RepairGapClient({this.empty = false});
  final bool empty;
  final beforeReads = <BigInt>[];
  final beforeArrived = Completer<void>();
  final release = Completer<void>();

  @override
  Future<Map<String, dynamic>> messagePage(
    String id, {
    int limit = 50,
    BigInt? before,
    BigInt? after,
  }) async {
    if (offline) throw StateError('Synthetic offline');
    if (before != null) {
      beforeReads.add(before);
      if (!beforeArrived.isCompleted) beforeArrived.complete();
      await release.future;
    }
    return {
      'messages': [
        if (before == null || !empty)
          for (var n = 1; n <= 50; n++) row(id, n * 10),
      ],
      'historyLimited': false,
    };
  }
}

Future<void> seedImportedGap(
  DriftWorkspaceCache cache,
  WorkspaceController w,
) async {
  await w.selectChannel(w.channels.single, autoRead: false);
  final scope = MessageHistoryPages.scope(w, 'chat')!;
  await cache.messageHistory.importWindow(
    scope.origin,
    scope.principal,
    scope.server,
    'window',
    'chat',
    {
      ...fixture.legacy('chat'),
      'authority': scope.authority,
      'hasMore': true,
      'tailSequence': null,
      'messages': [
        for (var n = 1; n <= 50; n++) row('chat', n * 10),
        row('chat', 900),
      ],
    },
  );
  // Model a retained legacy endpoint beyond the checked remote page. Hydration
  // admits it to the accepted window, without granting it HTTP provenance.
  w.messageWindows.acceptRows(liveWindowWrite, 'chat', [row('chat', 900)]);
  w.notifyListeners();
  await w.flushCache();
}

void main() {
  for (final empty in [false, true]) {
    test(
      'a ${empty ? 'empty' : 'duplicate-only'} remote gap proof survives a database reopen',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'raft-gap-repair-',
        );
        final file = File('${directory.path}/history.sqlite');
        var cache = DriftWorkspaceCache(NativeDatabase(file));
        final client = RepairGapClient(empty: empty),
            w = receiver(client, cache);
        final scope = MessageHistoryPages.scope(w, 'chat')!;
        var disposed = false;
        try {
          await seedImportedGap(cache, w);
          expect(
            (await cache.messageHistory.gaps.read(scope, [
              ('chat-500', BigInt.from(500)),
              ('chat-900', BigInt.from(900)),
            ])).single.before,
            BigInt.from(900),
          );
          final loading = w.messageDomain.loadHistoryGap(BigInt.from(900));
          await client.beforeArrived.future;
          if (empty) {
            // A newer socket update must survive an empty older HTTP response.
            client.arrivals.add(
              RaftEvent('message:updated', {
                ...row('chat', 500),
                'content': 'Current socket version',
              }),
            );
            await cache.messageHistory.receiver.settled;
          }
          client.release.complete();
          await loading;
          await w.flushCache();
          expect(client.beforeReads, [BigInt.from(900)]);
          expect(
            w.messageDomain.messages.map((m) => m.id),
            containsAll(['chat-500', 'chat-900']),
          );
          if (empty) {
            expect(w.messageDomain.messages.map((m) => m.id), [
              'chat-500',
              'chat-900',
            ]);
          }
          final repaired = await cache.messageHistory.gaps.read(scope, [
            for (final m in w.messageDomain.messages) (m.id, m.seq),
          ]);
          // Close and reopen before asserting, so the durable result is observed
          // even on the old implementation that still reports the repaired gap.
          w.dispose();
          disposed = true;
          await client.arrivals.close();
          await cache.close();
          cache = DriftWorkspaceCache(NativeDatabase(file));
          final reopened = await cache.messageHistory.readPage(
            scope,
            limit: 100,
          );
          final persisted = await cache.messageHistory.gaps.read(scope, [
            for (final m in reopened!.rows)
              (m['id'] as String, BigInt.parse('${m['seq']}')),
          ]);
          expect(
            persisted,
            isEmpty,
            reason: 'The server proved the interval before 900, not the imported endpoint itself.',
          );
          expect(repaired, isEmpty);
        } finally {
          if (!client.release.isCompleted) client.release.complete();
          if (!disposed) w.dispose();
          if (!client.arrivals.isClosed) await client.arrivals.close();
          await cache.close();
          await directory.delete(recursive: true);
        }
      },
    );
  }

  test('an explicit gap request verifies even a full cached page', () async {
    final cache = DriftWorkspaceCache(NativeDatabase.memory());
    final client = RepairGapClient(), w = receiver(client, cache);
    try {
      await seedImportedGap(cache, w);
      client.release.complete();
      await w.messageDomain.loadHistoryGap(BigInt.from(900));
      await w.messageDomain.loadHistoryGap(BigInt.from(900));
      expect(client.beforeReads, [BigInt.from(900), BigInt.from(900)]);
    } finally {
      if (!client.release.isCompleted) client.release.complete();
      await w.flushCache();
      w.dispose();
      await client.arrivals.close();
      await cache.close();
    }
  });

  test('legacy sparse window is unverified, not a gap between every saved pair', () async {
    final directory = await Directory.systemTemp.createTemp('raft-gap-legacy-');
    final file = File('${directory.path}/history.sqlite');
    var cache = DriftWorkspaceCache(NativeDatabase(file));
    final scope = fixture.scope();
    try {
      // The old client saved a continuous server page, without range metadata.
      // Migration must not invent that metadata to silence the notice.
      await cache.customStatement(
        'INSERT INTO workspace_cache(origin,principal,server,kind,id,payload) VALUES(?,?,?,?,?,?)',
        [
          ...scope.key.take(3),
          'window',
          scope.channel,
          jsonEncode({
            ...fixture.legacy(scope.channel),
            'hasMore': true,
            'messages': [for (var n = 1; n <= 50; n++) fixture.row(n * 10)],
          }),
        ],
      );
      expect(await cache.messageHistory.migrateLegacy(scope), 1);
      await cache.close();
      cache = DriftWorkspaceCache(NativeDatabase(file));
      final saved = await cache.messageHistory.readPage(scope);
      expect(saved!.rows, hasLength(50));
      expect(
        await cache.messageHistory.readPage(scope, before: BigInt.from(501)),
        isNull,
      );
      expect(
        await cache.messageHistory.gaps.read(scope, [
          for (final m in saved.rows)
            (m['id'] as String, BigInt.parse('${m['seq']}')),
        ]),
        isEmpty,
      );
      // A newly fetched, separate island still exposes the boundary to the
      // unverified old window. Internal old pairs must stay quiet.
      await cache.messageHistory.acceptPage(
        MessageHistoryPage(
          {
            'messages': [for (var n = 90; n < 140; n++) fixture.row(n * 10)],
          },
          scope: scope,
          revision: await cache.messageHistory.revision(scope),
          before: null,
          after: null,
          local: false,
        ),
      );
      final gaps = await cache.messageHistory.gaps.read(scope, [
        for (final n in [10, 20, 500, 900, 910]) ('chat-$n', BigInt.from(n)),
      ]);
      expect(gaps.map((g) => g.before), [BigInt.from(900)]);
    } finally {
      await cache.close();
      await directory.delete(recursive: true);
    }
  });

  test(
    'adjacent uint64 rows have no possible missing sequence at either limit',
    () async {
      final cache = DriftWorkspaceCache(NativeDatabase.memory());
      addTearDown(cache.close);
      final scope = fixture.scope(), store = cache.messageHistory;
      for (final lower in [BigInt.zero, historyMaxSequence - BigInt.one]) {
        final upper = lower + BigInt.one;
        await store.acceptEvents(scope, [
          fixture.row(lower),
          fixture.row(upper),
        ]);
        expect(
          await store.gaps.read(scope, [
            ('chat-$lower', lower),
            ('chat-$upper', upper),
          ]),
          isEmpty,
        );
      }
    },
  );
}
