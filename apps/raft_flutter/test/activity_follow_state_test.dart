import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/activity_follow_state.dart';

Map<String, dynamic> row({
  bool following = true,
  int unread = 3,
  String message = 'm',
  String seq = '9',
}) => {
  'kind': 'thread',
  'threadChannelId': 't',
  'latestActivityMessageId': message,
  'latestActivitySeq': seq,
  'isFollowing': following,
  'unreadCount': unread,
  'firstUnreadMessageId': unread > 0 ? message : null,
  'hasMention': unread > 0,
};

void main() {
  test('ACK projection subtracts only known cleared rows and preserves independent fields', () {
    final state = ActivityFollowState()..acknowledge(row(), following: false);
    final input = {
      'items': [
        row(),
        {...row(), 'threadChannelId': 'other'},
      ],
      'totalUnreadCount': 7,
      'activeUnreadCount': 6,
      'totalCount': 20,
      'hasMore': true,
    };
    final output = state.window(input);
    expect(output['totalUnreadCount'], 4);
    expect(output['activeUnreadCount'], 3);
    expect(output['totalCount'], 20);
    expect(output['hasMore'], true);
    expect(((output['items'] as List)[1] as Map)['isFollowing'], true);
    expect(
      ((input['items'] as List)[0] as Map)['unreadCount'],
      3,
      reason: 'Accepted response is not mutated.',
    );
  });
  test(
    'new message frontier stays unread while stale follow state is projected',
    () {
      final state = ActivityFollowState()..acknowledge(row(), following: false);
      final output = state.window({
        'items': [row(message: 'new', seq: '10', unread: 1)],
        'totalUnreadCount': 1,
      });
      final actual = (output['items'] as List).single as Map;
      expect(actual['isFollowing'], false);
      expect(actual['unreadCount'], 1);
      expect(actual['firstUnreadMessageId'], 'new');
      expect(actual['hasMention'], true);
      expect(output['totalUnreadCount'], 1);
    },
  );
  test('same sequence with different real message identity does not suppress unread', () {
    final state = ActivityFollowState()..acknowledge(row(), following: false);
    expect(state.project(row(message: 'different'))['unreadCount'], 3);
  });
  test('server convergence retires local follow projection; later real state is accepted', () {
    final state = ActivityFollowState()..acknowledge(row(), following: false);
    state.window({
      'items': [row(following: false, unread: 0)],
    });
    expect(state.project(row())['isFollowing'], true);
    expect(state.project(row())['unreadCount'], 3);
  });
  test('latest action and scope retirement fence operation tickets', () {
    final state = ActivityFollowState();
    final first = state.begin('t'), second = state.begin('t');
    expect(state.accepts('t', first), false);
    state.finish('t', first);
    expect(state.accepts('t', second), true);
    state.acknowledge(row(), following: false);
    state.clear();
    expect(state.accepts('t', second), false);
    expect(state.busy, false);
    expect(state.project(row())['isFollowing'], true);
  });
}
