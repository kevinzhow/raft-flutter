import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/history_capacity.dart';
import 'package:raft_flutter/data/history_read_policy.dart';
import 'package:raft_flutter/data/message_history.dart';
import 'package:raft_flutter/data/message_history_pages.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/data/workspace_message_windows.dart';
import 'package:raft_flutter/platform/workspace_cache.dart';

const account = HistoryAccount('https://history.invalid', 'alice');
MessageHistoryScope scope(
  String channel, {
  String user = 'alice',
  String server = 'one',
}) => MessageHistoryScope(
  origin: account.origin,
  principal: user,
  server: server,
  channel: channel,
  parentChannel: channel,
  authority: 'member',
);
List<Map<String, dynamic>> rows(
  String channel,
  int first,
  int last, {
  int bytes = 8192,
}) => [
  for (var i = first; i <= last; i++)
    {
      'id': '$channel-$i',
      'seq': '$i',
      'channelId': channel,
      'content': 'x' * bytes,
    },
];
Future<void> store(
  DriftWorkspaceCache cache,
  MessageHistoryScope s,
  List<Map<String, dynamic>> values,
) async {
  final db = cache.messageHistory;
  await db.acceptPage(
    MessageHistoryPage(
      {'messages': values},
      scope: s,
      revision: await db.revision(s),
      before: null,
      after: null,
      local: false,
      limit: 500,
    ),
  );
}

Future<int> count(DriftWorkspaceCache db, String sql) async =>
    (await db.customSelect(sql).getSingle()).data.values.single as int;

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  for (final platform in [
    TargetPlatform.android,
    TargetPlatform.iOS,
    TargetPlatform.linux,
  ]) {
    test('default budget follows device class: $platform', () async {
      debugDefaultTargetPlatformOverride = platform;
      final cache = DriftWorkspaceCache(
        NativeDatabase.memory(),
        automaticHistoryMaintenance: false,
      );
      addTearDown(cache.close);
      final usage = await cache.messageHistory.capacity.usage(account);
      expect(
        usage.budget,
        platform == TargetPlatform.linux ? 2 << 30 : 1 << 30,
      );
      expect(usage.rows, 0);
    });
  }

  test(
    'budget and explicit retention cover all servers for exactly one account',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      final cache = DriftWorkspaceCache(
        NativeDatabase.memory(),
        automaticHistoryMaintenance: false,
      );
      addTearDown(cache.close);
      final cap = cache.messageHistory.capacity;
      for (final tier in historyBudgetTiers) {
        await cap.setBudget(account, tier);
        expect((await cap.usage(account)).budget, tier);
      }
      await expectLater(cap.setBudget(account, 123), throwsArgumentError);
      await cap.keep(account, 'one', 'chat', true);
      expect(await cap.isKept(account, 'one', 'chat'), isTrue);
      expect(await cap.isKept(account, 'two', 'chat'), isFalse);
      expect(
        await cap.isKept(
          const HistoryAccount('https://history.invalid', 'bob'),
          'one',
          'chat',
        ),
        isFalse,
      );
      await cache.clearAccount(account.origin, account.principal);
      expect(await cap.isKept(account, 'one', 'chat'), isFalse);
      expect((await cap.usage(account)).budget, 2 << 30);
    },
  );

  test('real-file eviction protects active, kept, other-account and draft data; shadows cannot restore bodies', () async {
    final dir = await Directory.systemTemp.createTemp('raft-history-capacity-');
    final file = File('${dir.path}/workspace.sqlite');
    final cache = DriftWorkspaceCache(
      NativeDatabase.createInBackground(file),
      historyBudget: 512 << 10,
      historyHardLimitEnabled: false,
      automaticHistoryMaintenance: false,
    );
    addTearDown(() async {
      await cache.close();
      await dir.delete(recursive: true);
    });
    final db = cache.messageHistory, cap = db.capacity;
    final owner = Object();
    cap.protect(
      owner,
      () => [
        HistoryProtectedRows(account, 'one', 'active', [
          for (var i = 1; i <= 20; i++) 'active-$i',
        ]),
      ],
    );
    await cap.keep(account, 'two', 'kept', true);
    await cache.write(account.origin, 'alice', 'one', 'draft', 'draft', {
      'text': 'do not delete',
    });
    await store(cache, scope('cold'), rows('cold', 1, 300));
    await cache.write(account.origin, 'alice', 'one', 'window', 'cold', {
      'version': 1,
      'windowKind': 'tail',
      'authority': 'member',
      'channelId': 'cold',
      'parentChannelId': 'cold',
      'messages': rows('cold', 1, 300),
      'hasMore': false,
      'historyLimited': false,
    });
    await store(cache, scope('active'), rows('active', 1, 20));
    await store(cache, scope('kept', server: 'two'), rows('kept', 1, 10));
    await store(cache, scope('other', user: 'bob'), rows('other', 1, 30));
    final lateRevision = await db.revision(scope('cold'));
    final before = await cap.usage(account);
    expect(before.overBudget, isTrue);
    expect(before.databaseBytes, await file.length());
    final result = await cap.maintain(account, compact: true);
    expect(
      result.protectedFull,
      isFalse,
      reason:
          'rows=${result.rows}, charge=${result.budgetCharge}, retained=${result.retainedCharge}, physical=${result.databaseBytes}',
    );
    expect(result.rows, 30);
    expect(result.budgetCharge, lessThanOrEqualTo(512 << 10));
    expect(await db.readContext(scope('cold'), 'cold-1', radius: 0), isNull);
    expect(await db.wasEvicted(scope('cold'), target: 'cold-1'), isTrue);
    await MessageHistoryPages.load(
      cache: cache,
      scope: scope('cold'),
      current: () => true,
      held: () => [],
      before: BigInt.from(301),
      remote: () async => {'messages': rows('cold', 251, 300)},
    );
    expect(db.reads.counts[HistoryReadReason.evicted], 1);
    expect(
      await db.wasEvicted(scope('cold'), before: BigInt.from(301)),
      isTrue,
    );
    expect((await db.readPage(scope('active')))!.rows, hasLength(20));
    expect(
      (await db.readPage(scope('kept', server: 'two')))!.rows,
      hasLength(10),
    );
    expect(
      (await db.readPage(scope('other', user: 'bob')))!.rows,
      hasLength(30),
    );
    expect(await cache.read(account.origin, 'alice', 'one', 'draft', 'draft'), {
      'text': 'do not delete',
    });
    final shadow = await cache
        .customSelect(
          "SELECT payload FROM workspace_cache WHERE kind='window' AND id='cold'",
        )
        .getSingle();
    expect(jsonDecode(shadow.read<String>('payload'))['messages'], isEmpty);
    expect(await db.readPage(scope('cold'), before: BigInt.from(301)), isNull);
    await db.acceptPage(
      MessageHistoryPage(
        {'messages': rows('cold', 1, 1)},
        scope: scope('cold'),
        revision: lateRevision,
        before: BigInt.from(2),
        after: null,
        local: false,
      ),
    );
    expect(
      await db.readContext(scope('cold'), 'cold-1', radius: 0),
      isNull,
      reason:
          'An HTTP response started before eviction must not restore the body.',
    );
    expect(await count(cache, 'SELECT count(*) FROM history_protected'), 0);
    expect(
      await count(cache, 'SELECT count(*) FROM history_protected_scopes'),
      0,
    );
    expect(await count(cache, 'PRAGMA auto_vacuum'), 2);
    expect(result.walBytes, 0);
  });

  test('a protected conversation can grow above the target while unprotected growth waits', () async {
    final cache = DriftWorkspaceCache(
      NativeDatabase.memory(),
      historyBudget: 128 << 10,
      historyHardLimitEnabled: false,
      automaticHistoryMaintenance: false,
    );
    addTearDown(cache.close);
    final db = cache.messageHistory, cap = db.capacity, owner = Object();
    cap.protect(
      owner,
      () => [
        HistoryProtectedRows(
          account,
          'one',
          'chat',
          const [],
          wholeChannel: true,
        ),
      ],
    );
    await store(cache, scope('chat'), rows('chat', 1, 200));
    final full = await cap.maintain(account);
    expect(full.protectedFull, isTrue);
    expect(full.rows, 200);
    await db.acceptEvents(scope('chat'), rows('chat', 201, 201));
    expect(await db.readContext(scope('chat'), 'chat-201', radius: 0), isNotNull);
    await expectLater(
      db.acceptEvents(scope('other'), rows('other', 1, 1)),
      throwsA(isA<HistoryCapacityExceeded>()),
    );
    expect((await db.readPage(scope('chat')))!.rows, hasLength(50));
    cap.release(owner);
    final recovered = await cap.maintain(account, compact: true);
    expect(recovered.protectedFull, isFalse);
    await db.acceptEvents(scope('chat'), rows('chat', 201, 201));
    expect(
      await db.readContext(scope('chat'), 'chat-201', radius: 0),
      isNotNull,
    );
  });

  test(
    'local reads touch LRU while history gaps remain network misses',
    () async {
      var now = DateTime.utc(2026, 10, 16);
      final cache = DriftWorkspaceCache(
        NativeDatabase.memory(),
        historyBudget: 1 << 20,
        historyHardLimitEnabled: false,
        historyClock: () => now,
        automaticHistoryMaintenance: false,
      );
      addTearDown(cache.close);
      final db = cache.messageHistory;
      await store(cache, scope('chat'), rows('chat', 1, 500, bytes: 3000));
      now = now.add(const Duration(minutes: 5));
      expect(
        (await db.readPage(scope('chat'), before: BigInt.from(51)))!.rows,
        hasLength(50),
      );
      await db.capacity.maintain(account, compact: true);
      expect(
        await db.readContext(scope('chat'), 'chat-1', radius: 0),
        isNotNull,
      );
      expect(
        await db.readContext(scope('chat'), 'chat-100', radius: 0),
        isNull,
      );
      expect(
        await db.readPage(scope('chat'), before: BigInt.from(101)),
        isNull,
      );
    },
  );

  test('logout purges usage metadata and pending maintenance cannot restore the account', () async {
    final cache = DriftWorkspaceCache(
      NativeDatabase.memory(),
      automaticHistoryMaintenance: false,
    );
    addTearDown(cache.close);
    await store(cache, scope('chat'), rows('chat', 1, 20));
    await cache.messageHistory.capacity.usage(account);
    await cache.clearAccount(account.origin, account.principal);
    expect(await count(cache, 'SELECT count(*) FROM raft_history_rows'), 0);
    expect(await count(cache, 'SELECT count(*) FROM raft_history_sizes'), 0);
    expect((await cache.messageHistory.capacity.usage(account)).rows, 0);
  });

  test(
    'persisting receiver rows and saved draft references cannot be reclaimed',
    () async {
      final cache = DriftWorkspaceCache(
        NativeDatabase.memory(),
        historyBudget: 128 << 10,
        historyHardLimitEnabled: false,
        automaticHistoryMaintenance: false,
      );
      addTearDown(cache.close);
      final db = cache.messageHistory;
      await store(cache, scope('chat'), rows('chat', 1, 100));
      final receipt = db.receiver.beginRow(scope('chat'), 'chat', 'chat-43');
      await cache.write(
        account.origin,
        account.principal,
        'one',
        'draft',
        'draft',
        {'text': 'Quote chat-42 in this pending reply.'},
      );
      await db.capacity.maintain(account, compact: true);
      expect(
        await db.readContext(scope('chat'), 'chat-42', radius: 0),
        isNotNull,
      );
      expect(
        await db.readContext(scope('chat'), 'chat-43', radius: 0),
        isNotNull,
      );
      expect(await db.readContext(scope('chat'), 'chat-44', radius: 0), isNull);
      receipt.finish();
    },
  );

  test('the installed workspace protects its visible rows and releases them on dispose', () async {
    final cache = DriftWorkspaceCache(
      NativeDatabase.memory(),
      historyBudget: 128 << 10,
      historyHardLimitEnabled: false,
      automaticHistoryMaintenance: false,
    );
    addTearDown(cache.close);
    final client =
        RaftClient(origin: account.origin, sessionStore: MemorySessionStore())
          ..user = RaftRecord({'id': account.principal})
          ..selectServer('one');
    final w = WorkspaceController(client, cache: cache);
    w.server = RaftRecord({'id': 'one', 'role': 'member'});
    w.channel = RaftChannel({
      'id': 'chat',
      'name': 'General',
      'type': 'channel',
    });
    w.messageDomain.ledger.switchServer('one');
    w.messageWindows.acceptRows(liveWindowWrite, 'chat', rows('chat', 1, 100));
    final db = cache.messageHistory;
    await store(cache, scope('chat'), rows('chat', 1, 100));
    expect((await db.capacity.maintain(account)).protectedFull, isTrue);
    expect((await db.capacity.usage(account)).rows, 100);
    w.dispose();
    final released = await db.capacity.maintain(account, compact: true);
    expect(released.protectedFull, isFalse);
    expect(released.rows, allOf(greaterThan(0), lessThan(100)));
    expect(released.budgetCharge, lessThanOrEqualTo(128 << 10));
    expect(await db.readContext(scope('chat'), 'chat-1', radius: 0), isNull);
  });

  test('automatic maintenance leaves subsequent message writes usable', () async {
    final cache = DriftWorkspaceCache(NativeDatabase.memory());
    addTearDown(cache.close);
    await store(cache, scope('chat'), rows('chat', 1, 20));
    // Exercise the timer started by the committed write, not a manual cleanup.
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    await cache.messageHistory.capacity.usage(account);
    await cache.messageHistory.acceptEvents(
      scope('chat'),
      rows('chat', 21, 21),
    );
    expect(
      (await cache.messageHistory.readPage(scope('chat')))!.rows,
      hasLength(21),
    );
  });

  test('counter backfill yields to drafts and replacement snapshots do not accumulate size', () async {
    final cache = DriftWorkspaceCache(
      NativeDatabase.memory(),
      automaticHistoryMaintenance: false,
    );
    addTearDown(cache.close);
    await cache.messageHistory.acceptEvents(
      scope('chat'),
      rows('chat', 1, 1205, bytes: 512),
    );
    var done = false;
    final measured = cache.messageHistory.capacity.usage(account).then((v) {
      done = true;
      return v;
    });
    await cache.write(
      account.origin,
      account.principal,
      'one',
      'draft',
      'draft',
      {'text': 'Preserved while accounting catches up'},
    );
    expect(
      done,
      isFalse,
      reason:
          'The accounting backfill must not hold the queue across its chunks.',
    );
    expect((await measured).rows, 1205);
    expect(
      await count(cache, 'SELECT sum(rows) FROM raft_history_sizes'),
      1205,
    );
    final window = {
      'version': 1,
      'windowKind': 'tail',
      'authority': 'member',
      'parentChannelId': 'chat',
      'messages': rows('chat', 1156, 1205, bytes: 512),
      'hasMore': true,
      'historyLimited': false,
    };
    await cache.write(
      account.origin,
      account.principal,
      'one',
      'window',
      'chat',
      window,
    );
    final first = (await cache.messageHistory.capacity.usage(account))
        .accountBytes;
    for (var n = 0; n < 5; n++) {
      await cache.write(
        account.origin,
        account.principal,
        'one',
        'window',
        'chat',
        window,
      );
    }
    expect(
      (await cache.messageHistory.capacity.usage(account)).accountBytes,
      first,
    );
    // Previous-version REPLACE bypasses its connection's DELETE triggers.
    final shadow =
        (await cache
                .customSelect(
                  "SELECT payload FROM workspace_cache WHERE kind='window' AND id='chat'",
                )
                .getSingle())
            .read<String>('payload');
    await cache.customStatement(
      "INSERT OR REPLACE INTO workspace_cache VALUES(?,?,?,'window','chat',?)",
      [account.origin, account.principal, 'one', shadow],
    );
    expect(
      (await cache.messageHistory.capacity.usage(account)).accountBytes,
      first,
    );
    await cache.clearAccount(account.origin, account.principal);
    expect(await count(cache, 'SELECT count(*) FROM raft_history_sizes'), 0);
    expect(
      await count(cache, 'SELECT count(*) FROM raft_history_cache_sizes'),
      0,
    );
  });

  test(
    'reclaimed middle rows leave an explicit cold-tail pagination miss',
    () async {
      final cache = DriftWorkspaceCache(
        NativeDatabase.memory(),
        historyBudget: 128 << 10,
        historyHardLimitEnabled: false,
        automaticHistoryMaintenance: false,
      );
      addTearDown(cache.close);
      final db = cache.messageHistory;
      await store(cache, scope('chat'), rows('chat', 1, 100));
      final owner = Object();
      db.capacity.protect(
        owner,
        () => [
          HistoryProtectedRows(account, 'one', 'chat', [
            'chat-1',
            'chat-2',
            'chat-99',
            'chat-100',
          ]),
        ],
      );
      await db.capacity.maintain(account);
      final tail = await db.readPage(scope('chat'));
      final kept = tail!.rows.map((m) => m['id']).toSet();
      expect(kept, containsAll(['chat-1', 'chat-2', 'chat-99', 'chat-100']));
      expect(kept.length, lessThan(100));
      expect(tail.hasMore, isTrue);
      final points = tail.rows.map((m) => BigInt.parse('${m['seq']}')).toList();
      BigInt? boundary;
      for (var i = 1; i < points.length; i++) {
        if (points[i] - points[i - 1] > BigInt.one) {
          boundary = points[i];
          break;
        }
      }
      expect(boundary, isNotNull);
      expect(await db.readPage(scope('chat'), before: boundary), isNull);
      expect(await db.wasEvicted(scope('chat'), before: boundary), isTrue);
    },
  );

  for (final available in <int?>[0, null]) {
    test(
      'legacy full compaction requires consent and sufficient known space: $available',
      () async {
        final dir = await Directory.systemTemp.createTemp(
          'raft-history-compaction-',
        );
        final file = File('${dir.path}/workspace.sqlite');
        int? free = available;
        final cache = DriftWorkspaceCache(
          NativeDatabase(file),
          automaticHistoryMaintenance: false,
          historyAvailableSpace: (_) async => free,
          historyHardLimitEnabled: false,
        );
        addTearDown(() async {
          await cache.close();
          await dir.delete(recursive: true);
        });
        final db = cache.messageHistory;
        await store(cache, scope('chat'), rows('chat', 1, 20));
        await cache.customStatement('PRAGMA auto_vacuum=NONE');
        await cache.customStatement('VACUUM');
        final plan = await db.capacity.compactionPlan(account);
        expect(plan.fullVacuum, isTrue);
        expect(plan.enoughSpace, isFalse);
        expect(plan.requiredBytes, greaterThan(2 * file.lengthSync()));
        await expectLater(
          db.capacity.maintain(account, compact: true),
          throwsA(isA<HistoryCompactionNeedsConfirmation>()),
        );
        await expectLater(
          db.capacity.maintain(account, compact: true, allowFullVacuum: true),
          throwsA(isA<HistoryCompactionSpaceRequired>()),
        );
        expect(await count(cache, 'PRAGMA auto_vacuum'), 0);
        await db.acceptEvents(scope('chat'), rows('chat', 21, 21));
        expect((await db.readPage(scope('chat')))!.rows, hasLength(21));
        free = 1 << 40;
        await db.capacity.maintain(
          account,
          compact: true,
          allowFullVacuum: true,
        );
        expect(await count(cache, 'PRAGMA auto_vacuum'), 2);
        expect((await db.readPage(scope('chat')))!.rows, hasLength(21));
      },
    );
  }

  test(
    'logout retires queued maintenance before a new account session writes',
    () async {
      final cache = DriftWorkspaceCache(
        NativeDatabase.memory(),
        historyBudget: 128 << 10,
        historyHardLimitEnabled: false,
        automaticHistoryMaintenance: false,
      );
      addTearDown(cache.close);
      final db = cache.messageHistory;
      await store(cache, scope('chat'), rows('chat', 1, 100));
      final maintenance = db.capacity.maintain(account);
      maintenance.ignore();
      await cache.clearAccount(account.origin, account.principal);
      await expectLater(maintenance, throwsStateError);
      expect((await db.capacity.usage(account)).rows, 0);
      await db.acceptEvents(scope('chat'), rows('chat', 101, 101));
      expect(
        await db.readContext(scope('chat'), 'chat-101', radius: 0),
        isNotNull,
      );
    },
  );
}
