import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/resource_row_reconcile.dart';

import 'activity_incremental_refresh_test.dart' show channelRow;

Map<String, dynamic> threadRow(String id, {String seq = '10'}) => {
  'kind': 'thread',
  'threadChannelId': id,
  'parentChannelId': 'parent',
  'latestActivityMessageId': 'r$seq',
  'latestActivitySeq': seq,
  'replyCount': 1,
  'unreadCount': 0,
};

void main() {
  test('item keys follow Source getInboxItemKey', () {
    expect(activityItemKey(channelRow(1)), 'channel:ch1');
    expect(activityItemKey(threadRow('t1')), 'thread:t1');
    expect(
      activityItemKey({'kind': 'mention_action', 'id': 'a1', 'channelId': 'c'}),
      'mention_action:a1',
    );
  });

  test('reconcile keeps unchanged row objects and the loaded tail', () {
    final current = [for (var i = 0; i < 40; i++) channelRow(i)];
    final incoming = [
      {...channelRow(0), 'lastMessagePreview': 'changed'},
      for (var i = 1; i < 30; i++) channelRow(i),
    ];
    final result = reconcileActivityWindow(
      incoming: incoming,
      current: current,
      hasMore: true,
      preserveTail: true,
      localFrontiers: {},
    );
    expect(result.rows, hasLength(40));
    expect(result.rows.first['lastMessagePreview'], 'changed');
    expect(identical(result.rows.first, current.first), isFalse);
    for (var i = 1; i < 40; i++) {
      expect(identical(result.rows[i], current[i]), isTrue, reason: '$i');
    }
  });

  test('reconcile without tail preservation accepts the served window', () {
    final current = [for (var i = 0; i < 40; i++) channelRow(i)];
    final result = reconcileActivityWindow(
      incoming: [for (var i = 0; i < 30; i++) channelRow(i)],
      current: current,
      hasMore: true,
      preserveTail: false,
      localFrontiers: {},
    );
    expect(result.rows, hasLength(30));
  });

  test('reconcile de-duplicates a row moved into the served window', () {
    final current = [for (var i = 0; i < 40; i++) channelRow(i)];
    final result = reconcileActivityWindow(
      incoming: [
        channelRow(35, seq: 5000),
        for (var i = 0; i < 29; i++) channelRow(i),
      ],
      current: current,
      hasMore: true,
      preserveTail: true,
      localFrontiers: {},
    );
    expect(
      result.rows.where((r) => r['channelId'] == 'ch35'),
      hasLength(1),
    );
    expect(result.rows.first['channelId'], 'ch35');
    expect(result.rows, hasLength(40));
  });

  test('newer local activity survives a stale response; newer served wins', () {
    final local = {
      ...threadRow('t1', seq: '20'),
      'unreadCount': 1,
    };
    final current = [threadRow('t0'), local];
    final frontiers = {'thread:t1': BigInt.from(20)};
    final stale = reconcileActivityWindow(
      incoming: [threadRow('t0'), threadRow('t1', seq: '10')],
      current: current,
      hasMore: false,
      preserveTail: false,
      localFrontiers: frontiers,
    );
    expect(identical(stale.rows.first, local), isTrue);
    expect(stale.unreadDelta, 1);
    expect(frontiers, contains('thread:t1'));
    final fresh = reconcileActivityWindow(
      incoming: [threadRow('t1', seq: '21'), threadRow('t0')],
      current: stale.rows,
      hasMore: false,
      preserveTail: false,
      localFrontiers: frontiers,
    );
    expect(fresh.rows.first['latestActivitySeq'], '21');
    expect(frontiers, isEmpty);
  });

  test('live message advances only on a strictly newer seq', () {
    final row = threadRow('t1', seq: '10');
    expect(
      advanceActivityRow(row, {'id': 'old', 'channelId': 't1', 'seq': 9}),
      isNull,
    );
    expect(
      advanceActivityRow(row, {'id': 'x', 'channelId': 't1', 'seq': null}),
      isNull,
    );
    expect(
      advanceActivityRow(row, {'id': 'x', 'channelId': 'other', 'seq': 11}),
      isNull,
    );
    final next = advanceActivityRow(row, {
      'id': 'new',
      'channelId': 't1',
      'seq': 11,
      'content': 'Reply',
      'createdAt': 'now',
    })!;
    expect(next['latestActivityMessageId'], 'new');
    expect(next['latestActivitySeq'], '11');
    expect(next['replyCount'], 2);
    expect(next['lastReplyAt'], 'now');
  });

  test('read projection clears only fully read rows', () {
    final row = {...channelRow(1), 'unreadCount': 3};
    expect(identical(projectFullyRead(row, BigInt.from(998)), row), isTrue);
    expect(projectFullyRead(row, BigInt.from(999))['unreadCount'], 0);
    expect(identical(projectFullyRead(row, null), row), isTrue);
  });
}
