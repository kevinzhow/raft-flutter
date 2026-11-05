import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/history_damaged_body.dart';
import 'package:raft_flutter/data/message_history.dart';
import 'package:raft_flutter/data/message_history_pages.dart';
import 'package:raft_flutter/platform/workspace_cache.dart';

import 'history_memory_test.dart' show HistoryClient, receiver, row;

/// What an older client wrote: the codec had nulled the text of a message that
/// merely mentioned a signed query.
Map<String, dynamic> blanked(String channel, int seq) => {
  ...row(channel, seq),
  'content': null,
};

Future<void> seed(
  DriftWorkspaceCache cache,
  MessageHistoryScope scope,
  List<Map<String, dynamic>> rows, {
  BigInt? before,
}) async {
  final store = cache.messageHistory;
  await store.acceptPage(
    MessageHistoryPage(
      {'messages': rows},
      scope: scope,
      revision: await store.revision(scope),
      before: before,
      after: null,
      limit: 50,
      local: false,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('damaged body rule', () {
    test('only non-system, non-deleted rows without text are damaged', () {
      expect(historyBodyDamaged({'id': 'a', 'content': null}), isTrue);
      expect(historyBodyDamaged({'id': 'a'}), isTrue);
      expect(historyBodyDamaged({'id': 'a', 'content': ''}), isFalse);
      expect(historyBodyDamaged({'id': 'a', 'content': 'hi'}), isFalse);
      expect(
        historyBodyDamaged({'content': null, 'messageType': 'system'}),
        isFalse,
      );
      expect(historyBodyDamaged({'content': null, 'deleted': true}), isFalse);
      expect(
        historyBodyDamaged({'content': null, 'deletedAt': '2026-01-01'}),
        isFalse,
      );
      expect(historyAnyBodyDamaged(null), isFalse);
    });

    test(
      'system rows without text stay durable; blanked chat rows are a miss',
      () async {
        final cache = DriftWorkspaceCache(NativeDatabase.memory());
        final scope = MessageHistoryPages.scope(
          receiver(HistoryClient(), cache),
          'chat',
        )!;
        try {
          await seed(cache, scope, [
            row('chat', 1),
            {...row('chat', 2), 'content': null, 'messageType': 'system'},
          ]);
          expect(
            (await cache.messageHistory.readPage(scope))!.rows,
            hasLength(2),
          );
          await seed(cache, scope, [row('chat', 1), blanked('chat', 2)]);
          expect(await cache.messageHistory.readPage(scope), isNull);
          expect(
            await cache.messageHistory.readContext(scope, 'chat-2', radius: 0),
            isNull,
          );
          expect(
            (await cache.messageHistory.projections(scope, [
              'chat-1',
              'chat-2',
            ])).keys,
            ['chat-1'],
          );
        } finally {
          await cache.close();
        }
      },
    );
  });

  group('old disk data, real refresh', () {
    late Directory dir;
    late File file;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('raft-damaged-body-');
      file = File('${dir.path}/history.sqlite');
    });
    tearDown(() => dir.delete(recursive: true));

    Future<void> oldClientDisk({bool older = false}) async {
      final cache = DriftWorkspaceCache(NativeDatabase(file));
      final scope = MessageHistoryPages.scope(
        receiver(HistoryClient(), cache),
        'chat',
      )!;
      await seed(cache, scope, [
        for (var n = 951; n <= 1000; n++)
          n == 990 ? blanked('chat', n) : row('chat', n),
      ]);
      if (older) {
        await seed(cache, scope, [
          for (var n = 901; n <= 950; n++)
            n == 920 ? blanked('chat', n) : row('chat', n),
        ], before: BigInt.from(951));
      }
      await cache.close();
    }

    Future<void> expectIntactAfterRestart(List<int> seqs) async {
      final cache = DriftWorkspaceCache(NativeDatabase(file));
      try {
        final scope = MessageHistoryPages.scope(
          receiver(HistoryClient(), cache),
          'chat',
        )!;
        for (final n in seqs) {
          final saved = await cache.messageHistory.readContext(
            scope,
            'chat-$n',
            radius: 0,
          );
          expect(
            (saved!['messages'] as List).single['content'],
            'Saved message $n 中文',
          );
        }
      } finally {
        await cache.close();
      }
    }

    test(
      'opening the channel re-obtains a blanked tail body and it survives restart',
      () async {
        await oldClientDisk();
        final cache = DriftWorkspaceCache(NativeDatabase(file));
        final w = receiver(HistoryClient(), cache);
        try {
          await w.selectChannel(w.channels.single, autoRead: false);
          await cache.messageHistory.reads.settled;
          await w.flushCache();
          await cache.messageHistory.reads.settled;
          final shown = w.messageDomain.messages.firstWhere(
            (m) => m.id == 'chat-990',
          );
          expect(shown.content, 'Saved message 990 中文');
        } finally {
          w.dispose();
          await cache.close();
        }
        await expectIntactAfterRestart([990]);
      },
    );

    test('scrolling into a durable-only range heals a blanked body', () async {
      await oldClientDisk(older: true);
      final cache = DriftWorkspaceCache(NativeDatabase(file));
      final w = receiver(HistoryClient(), cache);
      try {
        await w.selectChannel(w.channels.single, autoRead: false);
        await w.messageDomain.older();
        await cache.messageHistory.reads.settled;
        await w.flushCache();
        await cache.messageHistory.reads.settled;
        for (final n in [990, 920]) {
          expect(
            w.messageDomain.messages
                .firstWhere((m) => m.id == 'chat-$n')
                .content,
            'Saved message $n 中文',
          );
        }
      } finally {
        w.dispose();
        await cache.close();
      }
      await expectIntactAfterRestart([990, 920]);
    });
  });
}
