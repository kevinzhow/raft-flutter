import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/activity_done_state.dart';

import 'activity_done_lifecycle_test.dart' show doneThread;

void main() {
  final now = DateTime.utc(2026, 10, 10);
  test('Done marker uses authority evidence exclusively and preserves exact uint64 text', () {
    final row = doneThread(authoritySeq: '18446744073709551615');
    expect(ActivityDoneState.marker(row), '18446744073709551615');
    expect(ActivityDoneState.marker({...row, 'readState': null}), isNull);
    expect(
      ActivityDoneState.marker({
        ...row,
        'readState': {'kind': 'absent'},
      }),
      isNull,
    );
    expect(
      ActivityDoneState.marker({
        ...row,
        'readState': {'kind': 'corrupt'},
      }),
      isNull,
    );
    for (final latest in [
      null,
      {'seq': '12'},
      {'messageId': 'm', 'seq': '01'},
      {'messageId': '', 'seq': '12'},
    ]) {
      expect(
        ActivityDoneState.marker({
          ...row,
          'readState': {...row['readState'] as Map, 'latestActivity': latest},
        }),
        isNull,
      );
    }
    expect(
      ActivityDoneState.marker({
        ...row,
        'readState': {
          ...row['readState'] as Map,
          'maxReadSeq': '9007199254740992',
        },
      }),
      isNull,
    );
  });
  test(
    'pending exact marker removes row and adjusts only known counters/groups',
    () {
      final row = doneThread();
      final state = ActivityDoneState()..begin(row, now);
      final input = {
        'items': [
          row,
          {...row, 'threadChannelId': 'other'},
        ],
        'totalCount': 2,
        'allCount': 5,
        'totalUnreadCount': 7,
        'activeUnreadCount': 6,
        'groups': [
          {'channelId': 'channel', 'count': 1},
          {'channelId': 'other', 'count': 4},
        ],
        'hasMore': true,
      };
      final result = state.window(input, now, selectedChannelId: 'channel');
      expect(result['items'], hasLength(1));
      expect(result['totalCount'], 1);
      expect(result['allCount'], 4);
      expect(result['totalUnreadCount'], 4);
      expect(result['activeUnreadCount'], 3);
      expect(result['groups'], [
        {'channelId': 'channel', 'count': 0},
        {'channelId': 'other', 'count': 4},
      ]);
      expect(result['hasMore'], true);
      expect(input['items'], hasLength(2));
    },
  );
  test('newer marker retires only its suppression and is not hidden by display equality', () {
    final row = doneThread();
    final state = ActivityDoneState()..begin(row, now);
    expect(
      state.window({
        'items': [doneThread(authoritySeq: '13')],
      }, now)['items'],
      hasLength(1),
    );
    expect(
      state.window({
        'items': [row],
      }, now)['items'],
      hasLength(1),
    );
  });
  test('missing authority marker never uses storage or display sequences for suppression', () {
    final row = {
      ...doneThread(),
      'readState': {'kind': 'absent'},
    };
    final state = ActivityDoneState()..begin(row, now);
    expect(
      state.window({
        'items': [row],
      }, now)['items'],
      hasLength(1),
    );
  });
  test('Source thirty-second bridge expiry is bounded and inclusive at the deadline', () {
    final row = doneThread();
    final state = ActivityDoneState()..begin(row, now);
    expect(
      state.window({
        'items': [row],
      }, now.add(const Duration(seconds: 30)))['items'],
      isEmpty,
    );
    expect(
      state.window({
        'items': [row],
      }, now.add(const Duration(seconds: 30, microseconds: 1)))['items'],
      hasLength(1),
    );
  });
  test('old generation cannot finish a newer Done marker; scope clear retires both', () {
    final row = doneThread(), newer = doneThread(authoritySeq: '13');
    final state = ActivityDoneState();
    final first = state.begin(row, now), second = state.begin(newer, now);
    final key = ActivityDoneState.key(row)!;
    state.finish(key, first);
    expect(state.accepts(key, first), false);
    expect(state.accepts(key, second), true);
    expect(
      state.window({
        'items': [newer],
      }, now)['items'],
      isEmpty,
    );
    state.clear();
    expect(state.accepts(key, second), false);
    expect(
      state.window({
        'items': [newer],
      }, now)['items'],
      hasLength(1),
    );
  });
}
