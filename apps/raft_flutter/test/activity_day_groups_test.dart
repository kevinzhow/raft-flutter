import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/source_time_formatter.dart';
import 'package:raft_flutter/features/activity_day_groups.dart';

Map<String, dynamic> thread(String id, String at) => {
  'kind': 'thread',
  'threadChannelId': id,
  'lastActivityAt': at,
};

void main() {
  final now = DateTime.utc(2026, 11, 17, 12);
  final formatter = SourceTimeFormatter(
    preferredTimezone: 'UTC',
    todayLabel: 'Today',
    yesterdayLabel: 'Yesterday',
  );

  test('time of a row follows its kind', () {
    expect(activityRowTime(thread('a', '2026-11-17T01:00:00Z')),
        DateTime.utc(2026, 11, 17, 1));
    expect(
      activityRowTime({'kind': 'mention_action', 'createdAt': '2026-11-16T01:00:00Z'}),
      DateTime.utc(2026, 11, 16, 1),
    );
    expect(
      activityRowTime({'kind': 'channel', 'lastMessageAt': '2026-11-15T01:00:00Z'}),
      DateTime.utc(2026, 11, 15, 1),
    );
    expect(
      activityRowTime({'kind': 'object', 'lastActivityAt': '2026-11-14T01:00:00Z'}),
      DateTime.utc(2026, 11, 14, 1),
    );
    expect(activityRowTime({'kind': 'channel'}), isNull);
  });

  test('groups by calendar day with Today / Yesterday / date headings', () {
    final groups = groupActivityRowsByDay(
      [
        thread('b', '2026-11-16T23:00:00Z'),
        thread('a', '2026-11-17T09:00:00Z'),
        thread('c', '2026-11-16T01:00:00Z'),
        thread('d', '2026-11-10T01:00:00Z'),
        thread('e', '2025-01-02T01:00:00Z'),
      ],
      formatter: formatter,
      now: now,
    );
    expect(groups.map((g) => g.day), [
      '2026-11-17',
      '2026-11-16',
      '2026-11-10',
      '2025-01-02',
    ]);
    expect(groups.map((g) => g.label).take(2), ['Today', 'Yesterday']);
    expect(groups[2].label, contains('Tuesday'));
    expect(groups[3].label, contains('2025'));
    expect(groups[1].rows.map((r) => r['threadChannelId']), ['b', 'c']);
  });

  test('the key is the day, not the label, so it survives midnight', () {
    List<String> keys(DateTime at) => groupActivityRowsByDay(
      [thread('a', '2026-11-17T09:00:00Z')],
      formatter: formatter,
      now: at,
    ).map((g) => g.key).toList();
    final before = keys(now);
    final after = keys(DateTime.utc(2026, 11, 18, 1));
    expect(before, after);
    expect(before.single, 'activity-day-2026-11-17');
  });

  test('a time ahead of the clock counts as today', () {
    final groups = groupActivityRowsByDay(
      [thread('a', '2026-11-17T20:00:00Z'), thread('b', '2026-11-19T01:00:00Z')],
      formatter: formatter,
      now: now,
    );
    expect(groups, hasLength(1));
    expect(groups.single.label, 'Today');
    expect(groups.single.rows.map((r) => r['threadChannelId']), ['b', 'a']);
  });

  test('rows with no readable time form one group with no heading, last', () {
    final rows = [
      {'kind': 'channel', 'channelId': 'x'},
      thread('a', '2026-11-17T09:00:00Z'),
    ];
    for (final direction in ['desc', 'asc']) {
      final groups = groupActivityRowsByDay(
        rows,
        formatter: formatter,
        now: now,
        direction: direction,
      );
      expect(groups.map((g) => g.label), ['Today', '']);
      expect(groups.last.day, '');
      expect(groups.last.key, 'activity-day-none');
    }
  });

  test('sorting is stable and honours the direction', () {
    final rows = [
      thread('a', '2026-11-17T09:00:00Z'),
      thread('b', '2026-11-17T09:00:00Z'),
      thread('c', '2026-11-17T10:00:00Z'),
    ];
    expect(sortActivityRowsByTime(rows).map((r) => r['threadChannelId']),
        ['c', 'a', 'b']);
    expect(
      sortActivityRowsByTime(rows, direction: 'asc').map((r) => r['threadChannelId']),
      ['a', 'b', 'c'],
    );
  });
}
