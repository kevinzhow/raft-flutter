import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/channel_activity_timeline.dart';

Map<String, dynamic> row(
  String id,
  Object seq,
  String at, {
  String? activity,
}) => {
  'id': id,
  'seq': seq,
  'channelId': 'c1',
  'content': id,
  'createdAt': at,
  'activityAt': ?activity,
};

void main() {
  test(
    'stale releases cannot close a newly retained window after reset',
    () async {
      final store = ChannelActivityStore((_, _) async => {'messages': []});
      addTearDown(store.dispose);
      final oldA = store.retain('c1');
      final oldB = store.retain('c1');
      store.reset();
      final nextA = store.retain('c1');
      oldB();
      final nextB = store.retain('c1');
      oldA();
      nextA();
      expect(store.windows, contains('c1'));
      nextB();
      nextB();
      await Future<void>.delayed(Duration.zero);
      expect(store.windows, isEmpty);
    },
  );
  test(
    'activity merges seq content, reply bumps and precise seq tie breaks',
    () {
      final window = ChannelActivityWindow();
      addTearDown(window.refresh.cancel);
      window.messages['old'] = RaftMessage(
        row(
          'old',
          '9007199254740992',
          '2026-11-01T00:00:00Z',
          activity: '2026-11-03T00:00:00Z',
        ),
      );
      window.bumps['reply'] = '2026-11-04T00:00:00Z';
      final current = RaftMessage({
        ...row('old', '9007199254740992', '2026-11-01T00:00:00Z'),
        'content': 'Edited seq content',
      });
      final rows = buildChannelActivityTimeline(
        'c1',
        [
          current,
          RaftMessage(row('tie', '9007199254740993', '2026-11-03T00:00:00Z')),
          RaftMessage(row('reply', 2, '2026-11-01T00:00:00Z')),
          RaftMessage({
            ...row('elsewhere', 3, '2026-11-05T00:00:00Z'),
            'channelId': 'c2',
          }),
        ],
        window,
        {
          'reply': {'lastReplyAt': '2026-11-02T00:00:00Z'},
        },
      );
      expect(rows.map((m) => m.id), ['old', 'tie', 'reply']);
      expect(rows.first, same(current));
      expect(rows.first.content, 'Edited seq content');
    },
  );

  test(
    'partial pages hide seq rows older than the loaded activity boundary',
    () {
      final window = ChannelActivityWindow()..hasMore = true;
      addTearDown(window.refresh.cancel);
      window.messages['paged'] = RaftMessage(
        row('paged', 3, '2026-11-03T00:00:00Z'),
      );
      final seq = [
        RaftMessage(row('unloaded', 1, '2026-11-01T00:00:00Z')),
        RaftMessage(row('live', 5, '2026-11-05T00:00:00Z')),
      ];
      expect(
        buildChannelActivityTimeline('c1', seq, window, {}).map((m) => m.id),
        ['paged', 'live'],
      );
      window.hasMore = false;
      expect(
        buildChannelActivityTimeline('c1', seq, window, {}).map((m) => m.id),
        ['unloaded', 'paged', 'live'],
      );
    },
  );

  test(
    'pages use opaque cursor and refresh preserves loaded older pages',
    () async {
      final calls = <String?>[];
      final store = ChannelActivityStore((id, before) async {
        calls.add(before);
        return before == null
            ? {
                'messages': [row('latest', 5, '2026-11-05T00:00:00Z')],
                'nextCursor': '2026-11-05T00:00:00.123456Z~5',
                'hasMore': true,
              }
            : {
                'messages': [row('older', 2, '2026-11-02T00:00:00Z')],
                'nextCursor': '2026-11-02T00:00:00.654321Z~2',
                'hasMore': true,
                'historyLimited': true,
              };
      });
      addTearDown(store.dispose);
      final release = store.retain('c1');
      await Future<void>.delayed(Duration.zero);
      await store.loadOlder('c1');
      await store.loadLatest('c1');
      final window = store.windows['c1']!;
      expect(calls, [null, '2026-11-05T00:00:00.123456Z~5', null]);
      expect(window.messages.keys, ['latest', 'older']);
      expect(window.nextCursor, '2026-11-02T00:00:00.654321Z~2');
      expect(window.historyLimited, isTrue);
      release();
      expect(store.windows, isEmpty);
    },
  );

  test('refresh drops stale older response and final release drops late first page', () async {
    final older = Completer<dynamic>();
    final store = ChannelActivityStore(
      (id, before) async => before == null
          ? {
              'messages': [row('latest', 5, '2026-11-05T00:00:00Z')],
              'nextCursor': 'cursor',
              'hasMore': true,
            }
          : older.future,
    );
    addTearDown(store.dispose);
    final release = store.retain('c1');
    await Future<void>.delayed(Duration.zero);
    final loading = store.loadOlder('c1');
    await store.loadLatest('c1');
    older.complete({
      'messages': [row('stale', 1, '2026-11-01T00:00:00Z')],
      'hasMore': false,
    });
    await loading;
    expect(store.windows['c1']!.messages.keys, ['latest']);
    expect(store.windows['c1']!.loadingOlder, isFalse);
    release();
    final late = Completer<dynamic>();
    final other = ChannelActivityStore((_, _) => late.future);
    addTearDown(other.dispose);
    final close = other.retain('c1');
    close();
    late.complete({
      'messages': [row('late', 1, '2026-11-01T00:00:00Z')],
    });
    await Future<void>.delayed(Duration.zero);
    expect(other.windows, isEmpty);
  });

  testWidgets(
    'reply moves loaded rows without reads and debounces absent parents',
    (t) async {
      var reads = 0;
      final store = ChannelActivityStore((id, before) async {
        reads++;
        return {
          'messages': [row('loaded', 1, '2026-11-01T00:00:00Z')],
        };
      });
      addTearDown(store.dispose);
      final release = store.retain('c1');
      await t.pump();
      bool inSeq(String id, String parent) => parent == 'seq';
      store.noteReply('loaded', '2026-11-03T00:00:00Z', 'c1', inSeq: inSeq);
      store.noteReply('seq', '2026-11-03T00:00:00Z', 'c1', inSeq: inSeq);
      store.noteReply('elsewhere', '2026-11-03T00:00:00Z', 'c2', inSeq: inSeq);
      await t.pump(const Duration(seconds: 1));
      expect(reads, 1);
      expect(store.windows['c1']!.bumps['loaded'], '2026-11-03T00:00:00Z');
      store.noteReply('absent', '2026-11-03T00:00:00Z', 'c1', inSeq: inSeq);
      store.noteReply('other', '2026-11-04T00:00:00Z', 'c1', inSeq: inSeq);
      await t.pump(const Duration(milliseconds: 500));
      expect(reads, 2);
      release();
      await t.pump(const Duration(seconds: 1));
      expect(store.windows, isEmpty);
    },
  );

  test(
    'edits patch activity-only content without changing its activity key',
    () async {
      final store = ChannelActivityStore(
        (id, before) async => {
          'messages': [
            row(
              'loaded',
              1,
              '2026-11-01T00:00:00Z',
              activity: '2026-11-02T00:00:00Z',
            ),
          ],
        },
      );
      addTearDown(store.dispose);
      store.retain('c1');
      await Future<void>.delayed(Duration.zero);
      store.patch({
        'id': 'loaded',
        'channelId': 'c1',
        'content': 'Retracted',
        'deletedAt': '2026-11-05T00:00:00Z',
      });
      final message = store.windows['c1']!.messages['loaded']!;
      expect(message.content, 'Retracted');
      expect(message.retracted, isTrue);
      expect(
        channelActivityKey(message, null, null),
        DateTime.utc(2026, 11, 2).millisecondsSinceEpoch,
      );
    },
  );
}
