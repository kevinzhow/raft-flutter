import 'dart:async';
import 'dart:math';

import 'package:raft_sync/raft_sync.dart';
import 'package:test/test.dart';

class _Transient implements Exception {}

class _Fatal implements Exception {}

class _Harness {
  _Harness(this.answers);
  final List<Object> answers;
  final asked = <String?>[];
  final loads = <String>[];
  final reasons = <String, String?>{};
  final channelRows = <String>[];
  final rosters = <String>[];
  final scopes = <String>[];
  final messages = <Map<String, dynamic>>[];
  final timers = <Duration>[];
  final timerCallbacks = <void Function()>[];
  var dropped = 0;
  bool Function(String, SyncConversationState)? patch;

  late final session = SyncChangesSession(
    serverId: 's1',
    fetch: (since) async {
      asked.add(since);
      final answer = answers.removeAt(0);
      if (answer is Exception) throw answer;
      return answer;
    },
    loaders: {
      for (final name in SyncListSnapshot.values)
        name: SyncSnapshotLoader(
          load: (reason) {
            loads.add(name.wire);
            reasons[name.wire] = reason;
          },
        ),
    },
    refreshChannel: channelRows.add,
    notifyChannelMembers: rosters.add,
    isTransient: (error) => error is _Transient,
    applyConversation: (id, state) => patch?.call(id, state) ?? false,
    applyMessage: messages.add,
    onCursorDropped: () => dropped++,
    channelScopeChanged: (id, op) => scopes.add('$id:$op'),
    timer: (delay, callback) {
      timers.add(delay);
      timerCallbacks.add(callback);
      return Timer(const Duration(days: 1), () {});
    },
    random: Random(1),
  );
}

Map<String, dynamic> page(
  String cursor, {
  List changes = const [],
  bool hasMore = false,
  Map? reset,
}) => {
  'cursor': cursor,
  'hasMore': hasMore,
  'changes': changes,
  'reset': reset,
};

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('start takes the cursor without reading any list', () async {
    final h = _Harness([page('c0')]);
    expect(await h.session.start(), isTrue);
    expect(h.asked, [null]);
    expect(h.session.hasCursor, isTrue);
    expect(h.loads, isEmpty);
  });

  test('a pull follows hasMore pages and stores the last cursor', () async {
    final h = _Harness([
      page('c0'),
      page(
        'c1',
        hasMore: true,
        changes: [
          {'seq': 1, 'entity': 'agent', 'id': 'a', 'op': 'upsert', 'row': {}},
        ],
      ),
      page(
        'c2',
        changes: [
          {
            'seq': 2,
            'entity': 'channel',
            'id': 'ch',
            'op': 'upsert',
            'row': {},
          },
          {'seq': 3, 'entity': 'nope', 'id': 'x', 'op': 'upsert'},
        ],
      ),
      page('c3'),
    ]);
    await h.session.start();
    expect(await h.session.pull(), SyncPullResult.applied);
    await settle();
    expect(h.asked, [null, 'c0', 'c1']);
    expect(h.loads, ['agents']);
    expect(h.channelRows, ['ch']);
    await h.session.pull();
    expect(h.asked.last, 'c2');
  });

  test('one transient failure keeps the cursor and pulls once 30-60 s later; '
      'the second drops it', () async {
    final h = _Harness([page('c0'), _Transient(), _Transient()]);
    await h.session.start();
    expect(await h.session.pull(), SyncPullResult.kept);
    expect(h.session.hasCursor, isTrue);
    expect(h.timers, hasLength(1));
    expect(h.timers.single, greaterThanOrEqualTo(syncPullRetryMin));
    expect(h.timers.single, lessThan(syncPullRetryMin + syncPullRetrySpread));
    expect(h.dropped, 0);
    h.timerCallbacks.single();
    await settle();
    await settle();
    expect(h.session.hasCursor, isFalse);
    expect(h.dropped, 1);
    expect(h.timers, hasLength(1), reason: 'never loops');
  });

  test(
    'a non-transient failure (400 invalid_cursor) drops the cursor at once',
    () async {
      final h = _Harness([page('c0'), _Fatal()]);
      await h.session.start();
      expect(await h.session.pull(), SyncPullResult.dropped);
      expect(h.dropped, 1);
      expect(h.timers, isEmpty);
    },
  );

  test('a failure on a later page pulls again from the first cursor', () async {
    final h = _Harness([
      page('c0'),
      page('c1', hasMore: true),
      _Transient(),
      page('c9'),
    ]);
    await h.session.start();
    expect(await h.session.pull(), SyncPullResult.kept);
    await h.session.pull();
    expect(h.asked, [null, 'c0', 'c1', 'c0']);
  });

  test('a malformed answer (no cursor) drops the cursor', () async {
    final h = _Harness([
      page('c0'),
      {'changes': []},
    ]);
    await h.session.start();
    expect(await h.session.pull(), SyncPullResult.dropped);
  });

  test('reset takes its snapshots with the sync_reset reason', () async {
    final h = _Harness([
      page('c0'),
      page(
        'c5',
        reset: {
          'reason': 'too_old',
          'snapshots': ['channels', 'agents'],
        },
      ),
    ]);
    await h.session.start();
    await h.session.pull();
    await settle();
    expect(h.loads, unorderedEquals(['channels', 'agents']));
    expect(h.reasons['channels'], SyncFetchReason.syncReset);
  });

  test('an unknown snapshot name means every snapshot', () {
    final plan = planSyncChanges([
      {
        'seq': 1,
        'entity': 'scope',
        'id': 'c',
        'op': 'added',
        'scopeKind': 'channel',
        'snapshots': ['something_new'],
      },
    ]);
    expect(plan.snapshots, SyncListSnapshot.values.toSet());
    expect(plan.channelScopes, {'c': 'added'});
  });

  test('known entity with an unknown op resnapshots that entity', () {
    final plan = planSyncChanges([
      {'seq': 1, 'entity': 'machine', 'id': 'm', 'op': 'rename'},
    ]);
    expect(plan.snapshots, {SyncListSnapshot.machines});
  });

  test('channel_member changes re-read the roster and the channel row', () {
    final plan = planSyncChanges([
      {'seq': 1, 'entity': 'channel_member', 'id': 'ch:user:u', 'op': 'delete'},
    ]);
    expect(plan.memberChannelIds, {'ch'});
    expect(plan.channelIds, {'ch'});
  });

  test('more than 20 channel upserts read the channel lists instead', () {
    final plan = planSyncChanges([
      for (var i = 0; i < 21; i++)
        {'seq': i, 'entity': 'channel', 'id': 'c$i', 'op': 'upsert', 'row': {}},
    ]);
    expect(plan.snapshots, {SyncListSnapshot.channels});
    expect(plan.channelIds, isEmpty);
  });

  test('a removed channel scope re-reads channels, inbox and unread', () {
    final plan = planSyncChanges([
      {
        'seq': 1,
        'entity': 'scope',
        'id': 'c',
        'op': 'removed',
        'scopeKind': 'channel',
        'snapshots': [],
      },
    ]);
    expect(plan.snapshots, {
      SyncListSnapshot.channels,
      SyncListSnapshot.inbox,
      SyncListSnapshot.unread,
    });
  });

  test(
    'message upserts replace held rows by id; mismatched rows are dropped',
    () {
      final plan = planSyncChanges([
        {
          'seq': 1,
          'entity': 'message',
          'id': 'm1',
          'op': 'upsert',
          'row': {'id': 'm1', 'channelId': 'c', 'content': 'old'},
        },
        {
          'seq': 2,
          'entity': 'message',
          'id': 'm1',
          'op': 'upsert',
          'row': {'id': 'm1', 'channelId': 'c', 'content': 'new'},
        },
        {
          'seq': 3,
          'entity': 'message',
          'id': 'm2',
          'op': 'upsert',
          'row': {'id': 'other', 'channelId': 'c'},
        },
      ]);
      expect(plan.messages.keys, ['m1']);
      expect(plan.messages['m1']!['content'], 'new');
    },
  );

  test(
    'conversation state merges per kind; malformed parts reload the lists',
    () {
      final plan = planSyncChanges([
        {
          'seq': 1,
          'entity': 'conversation',
          'id': 'c',
          'op': 'stale',
          'refSeq': 4,
          'read': {'readSeq': 4, 'readStateVersion': 2},
        },
        {
          'seq': 2,
          'entity': 'conversation',
          'id': 'c',
          'op': 'stale',
          'refSeq': null,
          'done': {'done': true, 'doneFrontierSeq': '9'},
        },
        {
          'seq': 3,
          'entity': 'conversation',
          'id': 'd',
          'op': 'stale',
          'refSeq': null,
          'done': {'done': true, 'doneFrontierSeq': 'x9'},
        },
      ]);
      final state = plan.conversations['c']!;
      expect(state.read!.readSeq, 4);
      expect(state.done!.doneFrontierSeq, '9');
      expect(plan.conversations.containsKey('d'), isFalse);
      expect(plan.snapshots, conversationSnapshots.toSet());
      expect(
        plan.reasons[SyncListSnapshot.inbox],
        SyncFetchReason.legacyNoFields,
      );
    },
  );

  test(
    'an unpatchable conversation reloads inbox, unread and followed threads',
    () async {
      final h = _Harness([
        page('c0'),
        page(
          'c1',
          changes: [
            {
              'seq': 1,
              'entity': 'conversation',
              'id': 'c',
              'op': 'stale',
              'refSeq': 2,
              'read': {'readSeq': 2, 'readStateVersion': 1},
            },
          ],
        ),
      ]);
      await h.session.start();
      await h.session.pull();
      await settle();
      expect(h.loads, unorderedEquals(['inbox', 'unread', 'followed_threads']));
      expect(h.reasons['inbox'], SyncFetchReason.unpatchable);
    },
  );

  test('a patched conversation reads nothing', () async {
    final h = _Harness([
      page('c0'),
      page(
        'c1',
        changes: [
          {
            'seq': 1,
            'entity': 'conversation',
            'id': 'c',
            'op': 'stale',
            'refSeq': 2,
            'read': {'readSeq': 2, 'readStateVersion': 1},
          },
          {
            'seq': 2,
            'entity': 'scope',
            'id': 'gone',
            'op': 'removed',
            'scopeKind': 'channel',
            'snapshots': [],
          },
        ],
      ),
    ]);
    h.patch = (id, state) => id == 'c';
    await h.session.start();
    await h.session.pull();
    await settle();
    expect(h.loads, unorderedEquals(['channels', 'inbox', 'unread']));
    expect(h.scopes, ['gone:removed']);
  });

  test(
    'a pull asked for while one runs joins it and pulls once more after',
    () async {
      final gate = Completer<void>();
      final asked = <String?>[];
      final session = SyncChangesSession(
        serverId: 's',
        fetch: (since) async {
          asked.add(since);
          if (since == 'c0') await gate.future;
          return page(since == null ? 'c0' : 'c${asked.length}');
        },
        loaders: const {},
        refreshChannel: (_) {},
        notifyChannelMembers: (_) {},
        isTransient: (_) => true,
      );
      await session.start();
      final first = session.pull();
      final second = session.pull();
      expect(identical(first, second), isTrue);
      gate.complete();
      await first;
      expect(asked, [null, 'c0', 'c2']);
    },
  );

  test('a list read while one runs reads again after it', () async {
    final gate = Completer<void>();
    var reads = 0;
    final session = SyncChangesSession(
      serverId: 's',
      fetch: (_) async => page('c'),
      loaders: {
        SyncListSnapshot.agents: SyncSnapshotLoader(
          load: (_) async {
            reads++;
            if (reads == 1) await gate.future;
          },
        ),
      },
      refreshChannel: (_) {},
      notifyChannelMembers: (_) {},
      isTransient: (_) => true,
    );
    session.resnapshotAll(SyncFetchReason.reconnect);
    session.resnapshotAll(SyncFetchReason.reconnect);
    session.resnapshotAll(SyncFetchReason.reconnect);
    gate.complete();
    await settle();
    await settle();
    expect(reads, 2);
  });

  test('a disposed session pulls nothing and reports no drop', () async {
    final h = _Harness([page('c0')]);
    await h.session.start();
    h.session.dispose();
    expect(await h.session.pull(), SyncPullResult.dropped);
    expect(h.dropped, 0);
  });
}
