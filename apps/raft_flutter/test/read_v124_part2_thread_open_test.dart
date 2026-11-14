// Source: packages/web/src/store/threadStore.ts (openThread: reopenedUnread,
// 404 = no replies yet) at v1.24.0-source.1
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/user_activity.dart';

import 'message_context_transition_test.dart' show row;
import 'message_presentation_test.dart' show fixture;

void main() {
  test('[BP-READ-067] picking the thread that is already open and unread again reads it', () async {
    final (w, api) = await fixture('member');
    addTearDown(w.dispose);
    w.setForeground(true);
    RaftUserActivity.mark();
    w.messageDomain.ledger.switchServer('s1');
    api.routes['GET /channels/c1/threads/parent'] = (_) => {
      'threadChannelId': 'thread-1',
    };
    api.routes['GET /messages/context/parent'] = (_) => {
      'messages': [row('parent', 'c1', 1)],
    };
    api.routes['GET /messages/channel/thread-1'] = (_) => {
      'messages': [row('r1', 'thread-1', 1), row('r2', 'thread-1', 2)],
      'hasMore': false,
    };
    api.routes['POST /channels/thread-1/read'] = (_) => {
      'maxReadSeq': 2,
      'readStateVersion': 1,
    };
    api.routes['GET /channels/unread'] = (_) => {'channels': {}};
    int reads() =>
        api.calls.where((c) => c.path == '/channels/thread-1/read').length;
    Future<void> open() => w.openThreadIdentity(
      parentChannelId: 'c1',
      parentMessageId: 'parent',
      initialThreadChannelId: 'thread-1',
      navigate: false,
    );
    w.navigation.navigate(w.location.withQuery({'thread': 'c1:parent'}));
    w.conversationReads.unread = {'thread-1': 2};
    await open();
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(reads(), 1, reason: 'opening reads the thread after its page');
    // New replies arrive while the panel stays open (unread again), then the
    // same thread is picked again.
    w.conversationReads.unread = {'thread-1': 1};
    await open();
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(reads(), 2, reason: 're-picking the open unread thread reads it');
    expect(w.conversationReads.unread['thread-1'] ?? 0, 0);
  });
}
