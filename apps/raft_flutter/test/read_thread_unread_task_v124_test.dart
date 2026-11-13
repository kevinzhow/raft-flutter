import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/thread_unread_by_parent.dart';

/// Web v1.24 utils/threadUnreadByParent.ts: a task conversation (task v2)
/// shows its unread in Activity only, never on the parent channel's badge or
/// in its jump order.
void main() {
  final threads = [
    {'parentChannelId': 'c', 'unreadCount': 2, 'threadChannelId': 't1'},
    {
      'parentChannelId': 'c',
      'unreadCount': 3,
      'hasMention': true,
      'threadChannelId': 't2',
      'conversationKind': 'task',
    },
  ];

  test('[BP-READ-012] a task conversation does not light the parent channel badge or its @', () {
    final grouped = groupThreadUnreadByParent(threads);
    expect(grouped['c'], const ParentThreadUnread(1, false));
  });

  test('a task conversation is not in the parent channel jump order', () {
    expect(
      orderParentUnreadThreadsForJump(
        threads,
        'c',
      ).map((t) => t['threadChannelId']),
      ['t1'],
    );
  });
}
