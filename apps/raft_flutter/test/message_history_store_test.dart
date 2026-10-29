import 'dart:io';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/message_history.dart';
import 'package:raft_flutter/platform/workspace_cache.dart';

const _scope = MessageHistoryScope(
  origin: 'https://history.invalid',
  principal: 'alice',
  server: 'one',
  channel: 'chat',
  parentChannel: 'chat',
  authority: 'member-chat',
);
MessageHistoryScope scope({
  String channel = 'chat',
  String? parent,
  String server = 'one',
  String principal = 'alice',
  String authority = 'member-chat',
  String? parentMessage,
}) => MessageHistoryScope(
  origin: _scope.origin,
  principal: principal,
  server: server,
  channel: channel,
  parentChannel: parent ?? channel,
  authority: authority,
  parentMessage: parentMessage,
);
Map<String, dynamic> row(
  Object seq, {
  String channel = 'chat',
  String? content,
}) => {
  'id': '$channel-$seq',
  'channelId': channel,
  'seq': '$seq',
  'content': content ?? 'Accepted $seq 中文',
};
List<Map<String, dynamic>> rows(
  int first,
  int last, {
  String channel = 'chat',
}) => [for (var i = first; i <= last; i++) row(i, channel: channel)];

Future<MessageHistoryPage> page(
  MessageHistoryStorage db,
  MessageHistoryScope scope,
  List<Map<String, dynamic>> rows, {
  BigInt? before,
  int? revision,
  bool limited = false,
}) async => MessageHistoryPage(
  {'messages': rows, 'historyLimited': limited},
  scope: scope,
  revision: revision ?? await db.revision(scope),
  before: before,
  after: null,
  local: false,
);

Map<String, dynamic> legacy(String id) => {
  'version': 1,
  'windowKind': 'tail',
  'authority': _scope.authority,
  'parentChannelId': id,
  'channelId': id,
  'messages': [row(1, channel: id)],
  'hasMore': false,
  'historyLimited': false,
};

void main() {
  late DriftWorkspaceCache cache;
  late MessageHistoryStorage db;
  setUp(() {
    cache = DriftWorkspaceCache(NativeDatabase.memory());
    db = cache.messageHistory;
  });
  tearDown(() async {
    await cache.close();
  });

  test('sparse uint64 values keep exact numeric order on disk', () async {
    final seqs = [
      '1',
      '9007199254740993',
      '9223372036854775809',
      '18446744073709551615',
    ];
    await db.acceptPage(
      await page(db, _scope, [for (final seq in seqs) row(seq)]),
    );
    final stored = await db.readPage(_scope);
    expect(stored!.rows.map((m) => m['seq']), seqs);
    expect(stored.hasMore, isFalse);
    final older = await db.readPage(_scope, before: BigInt.parse(seqs.last));
    expect(older!.rows.map((m) => m['seq']), seqs.take(3));
    expect(historySequenceKey(seqs.last), seqs.last);
    for (final invalid in [
      '-1',
      '01',
      '18446744073709551616',
      1.5,
      9007199254740993,
    ]) {
      expect(() => historySequenceKey(invalid), throwsFormatException);
    }
  });

  test('unproven gaps do not become a local end-of-history', () async {
    await db.acceptPage(await page(db, _scope, rows(901, 950)));
    await db.importWindow(_scope.origin, 'alice', 'one', 'window', 'chat', {
      'version': 1,
      'windowKind': 'tail',
      'authority': _scope.authority,
      'parentChannelId': 'chat',
      'messages': rows(1, 100),
      'hasMore': true,
    });
    expect(await db.readPage(_scope, before: BigInt.from(901)), isNull);
    final known = await db.readPage(_scope, before: BigInt.from(951));
    expect(known!.rows.first['seq'], '901');
    expect(known.hasMore, isTrue);
    await db.acceptPage(
      await page(db, _scope, rows(851, 900), before: BigInt.from(901)),
    );
    expect(
      (await db.readPage(_scope, before: BigInt.from(901)))!.rows.length,
      50,
    );
  });

  test(
    'stored message metadata strips credentials and signed download URLs',
    () async {
      await db.acceptPage(
        await page(db, _scope, [
          {
            ...row(1),
            'authorization': 'synthetic-secret',
            'attachments': [
              {
                'id': 'attachment',
                'filename': 'kept.txt',
                'url': 'https://history.invalid/file?token=synthetic-secret',
                'signedUrl': 'https://history.invalid/signed',
                'size': 10,
              },
            ],
          },
        ]),
      );
      final raw = await cache
          .customSelect('SELECT payload FROM raft_history_rows')
          .getSingle();
      expect(raw.read<String>('payload'), isNot(contains('synthetic-secret')));
      final local = (await db.readPage(_scope))!.rows.single;
      expect(local['content'], row(1)['content']);
      expect((local['attachments'] as List).single['filename'], 'kept.txt');
    },
  );

  test('authoritative deletion retains only a body-free tombstone', () async {
    await db.acceptPage(
      await page(db, _scope, [row(1, content: 'removed private body')]),
    );
    await db.acceptPage(await page(db, _scope, []));
    final raw = await cache
        .customSelect(
          'SELECT payload,tombstone,byte_size FROM raft_history_rows',
        )
        .getSingle();
    expect(raw.read<String>('payload'), '{}');
    expect(raw.read<int>('tombstone'), 1);
    expect(raw.read<int>('byte_size'), 0);
  });

  test(
    'legacy window-count eviction does not remove new per-message rows',
    () async {
      // A deliberately smaller legacy limit exercises the same 120-window LRU.
      await cache.close();
      cache = DriftWorkspaceCache(NativeDatabase.memory(), windowRetention: 2);
      db = cache.messageHistory;
      for (final id in ['one', 'two', 'three']) {
        await cache.write(
          _scope.origin,
          'alice',
          'one',
          'window',
          id,
          legacy(id),
        );
        await db.acceptPage(
          await page(db, scope(channel: id), [row(1, channel: id)]),
        );
      }
      final shadows = await cache
          .customSelect(
            "SELECT count(*) AS n FROM workspace_cache WHERE kind='window'",
          )
          .getSingle();
      expect(shadows.read<int>('n'), 2);
      final stored = await db.readPage(scope(channel: 'one'));
      expect(stored!.rows.single['id'], 'one-1');
      final guards = await cache
          .customSelect('SELECT count(*) AS n FROM raft_history_compat_write')
          .getSingle();
      expect(guards.read<int>('n'), 0);
    },
  );

  test(
    'an old-version thread-window denial purges the new thread rows',
    () async {
      final thread = scope(
        channel: 'thread',
        parent: 'chat',
        parentMessage: 'parent',
      );
      await cache.write(
        _scope.origin,
        'alice',
        'one',
        'thread-window',
        'parent',
        {
          ...legacy('chat'),
          'threadChannelId': 'thread',
          'parentMessageId': 'parent',
          'messages': [row(1, channel: 'thread')],
        },
      );
      await db.acceptPage(await page(db, thread, [row(1, channel: 'thread')]));
      await cache.customStatement(
        "DELETE FROM workspace_cache WHERE origin=? AND principal=? AND server=? AND kind='thread-window' AND id='parent'",
        [_scope.origin, 'alice', 'one'],
      );
      expect(await db.readPage(thread), isNull);
    },
  );

  test(
    'queued pre-revocation events stay fenced after a fresh grant',
    () async {
      await db.acceptPage(await page(db, _scope, rows(1, 3)));
      final old = await db.receiverRevision(_scope);
      await cache.revokeChannel(_scope.origin, 'alice', 'one', 'chat');
      await db.acceptPage(await page(db, _scope, [row(4)]));
      expect(
        await db.acceptEvents(_scope, [row(2)], requestedRevision: old),
        isFalse,
      );
      expect((await db.readPage(_scope))!.rows.map((m) => m['id']), ['chat-4']);
    },
  );

  test('legacy migration advances in small resumable transactions', () async {
    for (final id in ['one', 'two', 'three']) {
      await cache.customStatement(
        'INSERT INTO workspace_cache(origin,principal,server,kind,id,payload) VALUES(?,?,?,?,?,?)',
        [_scope.origin, 'alice', 'one', 'window', id, jsonEncode(legacy(id))],
      );
    }
    expect(await db.migrateLegacy(_scope, limit: 1), 1);
    expect(await db.knownScope(_scope.origin, 'alice', 'one', 'two'), isNull);
    expect(await db.migrateLegacy(_scope, limit: 1), 1);
    expect(await db.migrateLegacy(_scope, limit: 1), 1);
    expect(await db.migrateLegacy(_scope, limit: 1), 0);
    for (final id in ['one', 'two', 'three']) {
      expect(await db.knownScope(_scope.origin, 'alice', 'one', id), isNotNull);
    }
    // Migration preserves the rollback copies and does not invent coverage.
    expect(
      await db.readPage(scope(channel: 'one'), before: BigInt.two),
      isNull,
    );
    final retained = await db.readPage(scope(channel: 'one'));
    expect(retained!.rows.single['id'], 'one-1');
    expect(retained.hasMore, isTrue);
    expect(
      await cache.read(_scope.origin, 'alice', 'one', 'window', 'one'),
      isNotNull,
    );
  });

  test('late HTTP cannot replace a newer accepted live projection', () async {
    await db.acceptPage(await page(db, _scope, rows(51, 100)));
    final base = await db.revision(_scope);
    await db.acceptEvents(_scope, [
      row(75, content: 'new live text'),
    ], updateOnly: true);
    final stale = await page(db, _scope, rows(51, 100), revision: base);
    await db.acceptPage(stale);
    final actual = (await db.readPage(_scope))!.rows
        .singleWhere((m) => m['id'] == 'chat-75');
    expect(actual['content'], 'new live text');
    final reconciled = await db.reconcilePage(
      _scope,
      stale,
      requestedRevision: base,
    );
    expect(
      (reconciled['messages'] as List).singleWhere(
        (m) => m['id'] == 'chat-75',
      )['content'],
      'new live text',
    );
  });

  test(
    'late tail HTTP includes committed live arrivals outside its old tail',
    () async {
      await db.acceptPage(await page(db, _scope, rows(1, 50)));
      final base = await db.revision(_scope);
      await db.acceptEvents(_scope, [
        row(51, content: 'received while fetching'),
      ]);
      final reconciled = await db.reconcilePage(_scope, {
        'messages': rows(1, 50),
      }, requestedRevision: base);
      expect((reconciled['messages'] as List).last['id'], 'chat-51');
      final older = await db.reconcilePage(
        _scope,
        {'messages': rows(1, 25)},
        requestedRevision: base,
        before: BigInt.from(26),
      );
      expect((older['messages'] as List).length, 25);
    },
  );

  test(
    'forward local pages preserve sparse order and an unproven newer gap',
    () async {
      await db.acceptPage(await page(db, _scope, rows(1, 50)));
      final next = await db.readPage(_scope, after: BigInt.from(25), limit: 10);
      expect(next!.rows.map((m) => m['seq']), [
        for (var i = 26; i <= 35; i++) '$i',
      ]);
      expect(next.hasMore, isTrue);
      await db.acceptEvents(_scope, [row(100)]);
      expect(await db.readPage(_scope, after: BigInt.from(50)), isNull);
    },
  );

  test(
    'a focused context is pageable but never becomes the latest saved window',
    () async {
      await db.acceptPage(await page(db, _scope, rows(951, 1000)));
      final focused = MessageHistoryPage(
        {
          'messages': rows(201, 251),
          'hasOlder': true,
          'hasNewer': true,
          'historyLimited': false,
        },
        scope: _scope,
        revision: await db.revision(_scope),
        before: null,
        after: null,
        local: false,
        focused: true,
      );
      await db.acceptPage(focused);
      final local = await db.readContext(_scope, 'chat-226', radius: 25);
      expect((local!['messages'] as List).first['id'], 'chat-201');
      expect((local['messages'] as List).last['id'], 'chat-251');
      expect(local['hasOlder'], isTrue);
      expect(local['hasNewer'], isTrue);
      final tail = await db.readPage(_scope);
      expect(tail!.rows.first['id'], 'chat-951');
      expect(tail.rows.last['id'], 'chat-1000');
    },
  );

  test(
    'authority changes cannot accept an old response after an ABA role cycle',
    () async {
      await db.acceptPage(await page(db, _scope, rows(1, 3)));
      final stale = await page(db, _scope, rows(1, 3));
      final changed = scope(authority: 'restricted-chat');
      await db.revision(changed);
      await db.revision(_scope);
      await db.acceptPage(stale);
      expect(await db.readPage(_scope), isNull);
      await db.acceptPage(await page(db, _scope, [row(4)]));
      expect((await db.readPage(_scope))!.rows.single['id'], 'chat-4');
    },
  );

  test(
    'an omitted authoritative row stays deleted against an older response',
    () async {
      await db.acceptPage(await page(db, _scope, rows(51, 100)));
      final old = await page(db, _scope, rows(51, 100));
      await db.acceptPage(
        await page(db, _scope, [
          for (final m in rows(50, 100))
            if (m['id'] != 'chat-75') m,
        ]),
      );
      await db.acceptPage(old);
      expect(
        (await db.readPage(_scope))!.rows.any((m) => m['id'] == 'chat-75'),
        isFalse,
      );
    },
  );

  test(
    'a partial event edits stored history without inventing an unknown row',
    () async {
      await db.acceptPage(await page(db, _scope, rows(1, 3)));
      await db.acceptEvents(_scope, [
        {'id': 'chat-2', 'channelId': 'chat', 'content': 'edited offline row'},
        {'id': 'unknown', 'channelId': 'chat', 'content': 'no base'},
      ], updateOnly: true);
      final actual = (await db.readPage(_scope))!.rows;
      expect(actual.length, 3);
      expect(
        actual.singleWhere((m) => m['id'] == 'chat-2')['content'],
        'edited offline row',
      );
    },
  );

  test(
    'limits purge disallowed stored ranges without granting an older end',
    () async {
      await db.acceptPage(await page(db, _scope, rows(1, 50)));
      await db.acceptPage(await page(db, _scope, rows(51, 100)));
      await db.acceptPage(await page(db, _scope, rows(91, 100), limited: true));
      final local = (await db.readPage(_scope))!;
      expect(local.rows.map((m) => m['seq']), [
        for (var i = 91; i <= 100; i++) '$i',
      ]);
      expect(local.historyLimited, isTrue);
      expect(local.hasMore, isFalse);
      expect(await db.readPage(_scope, before: BigInt.from(91)), isNull);
    },
  );

  test(
    'account, server, channel and authority isolate cached projections',
    () async {
      await db.acceptPage(await page(db, _scope, rows(1, 3)));
      for (final other in [
        scope(principal: 'bob'),
        scope(server: 'two'),
        scope(channel: 'else'),
      ]) {
        expect(await db.readPage(other), isNull);
      }
      final changed = scope(authority: 'restricted-chat');
      expect(await db.readPage(changed), isNull);
      expect(await db.readPage(_scope), isNull);
    },
  );

  test(
    'revocation fences queued legacy writes and pre-revocation HTTP',
    () async {
      await db.acceptPage(await page(db, _scope, rows(51, 100)));
      final stale = await page(db, _scope, rows(51, 100));
      await cache.revokeChannel(_scope.origin, 'alice', 'one', 'chat');
      await cache.write(_scope.origin, 'alice', 'one', 'window', 'chat', {
        'version': 1,
        'windowKind': 'tail',
        'authority': _scope.authority,
        'parentChannelId': 'chat',
        'messages': rows(51, 100),
      });
      await db.acceptPage(stale);
      expect(
        await cache.read(_scope.origin, 'alice', 'one', 'window', 'chat'),
        isNull,
      );
      expect(await db.readPage(_scope), isNull);
      // A newly issued, successful authorized response can restore the scope.
      await db.acceptPage(await page(db, _scope, rows(101, 150)));
      expect((await db.readPage(_scope))!.rows.last['seq'], '150');
      await db.acceptPage(stale);
      expect((await db.readPage(_scope))!.rows.first['seq'], '101');
    },
  );

  test(
    'parent revocation purges persisted threads absent from memory',
    () async {
      final thread = scope(
        channel: 'thread',
        parent: 'chat',
        parentMessage: 'chat-1',
      );
      await db.acceptPage(
        await page(db, thread, rows(1, 3, channel: 'thread')),
      );
      await cache.revokeChannel(_scope.origin, 'alice', 'one', 'chat');
      expect(await db.readPage(thread), isNull);
      expect(
        await cache.read(
          _scope.origin,
          'alice',
          'one',
          'thread-window',
          'chat-1',
        ),
        isNull,
      );
    },
  );

  test(
    'previous-version purge SQL removes additive rows and metadata',
    () async {
      await db.acceptPage(await page(db, _scope, rows(1, 3)));
      final schema = await cache
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(schema.read<int>('user_version'), 2);
      // These are the unmodified previous version's account-clear statements.
      await cache.customStatement(
        'DELETE FROM workspace_cache WHERE origin=? AND principal=?',
        [_scope.origin, 'alice'],
      );
      await cache.customStatement(
        'DELETE FROM message_translations WHERE origin=? AND principal=?',
        [_scope.origin, 'alice'],
      );
      for (final table in [
        'raft_history_rows',
        'raft_history_ranges',
        'raft_history_clock',
      ]) {
        final count = await cache
            .customSelect('SELECT count(*) AS n FROM $table')
            .getSingle();
        expect(count.read<int>('n'), 0, reason: table);
      }
    },
  );

  test('valid stored projections survive file close and reopen', () async {
    await cache.close();
    final directory = await Directory.systemTemp.createTemp(
      'raft-message-store-',
    );
    final file = File('${directory.path}/history.sqlite');
    var actual = DriftWorkspaceCache(NativeDatabase(file));
    await actual.messageHistory.acceptPage(
      await page(actual.messageHistory, _scope, rows(1, 3)),
    );
    await actual.close();
    actual = DriftWorkspaceCache(NativeDatabase(file));
    expect((await actual.messageHistory.readPage(_scope))!.rows.length, 3);
    await actual.close();
    await directory.delete(recursive: true);
  });
}
