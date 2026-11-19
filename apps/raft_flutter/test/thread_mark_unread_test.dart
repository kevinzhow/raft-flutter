import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/user_activity.dart';

import 'message_context_transition_test.dart' show row;
import 'message_presentation_test.dart' show fixture;

void main() {
  test(
    'marking an open thread unread holds receipts until it is closed',
    () async {
      final (w, api) = await fixture('member');
      addTearDown(w.dispose);
      w.setForeground(true);
      RaftUserActivity.mark();
      w.messageDomain.ledger.switchServer('s1');
      api.routes['GET /messages/context/parent'] = (_) => {
        'messages': [row('parent', 'c1', 1)],
      };
      api.routes['GET /messages/channel/replies'] = (_) => {
        'messages': [row('reply', 'replies', 2)],
        'hasMore': false,
      };
      api.routes['POST /channels/replies/read'] = (_) => {
        'maxReadSeq': 2,
        'readStateVersion': 3,
      };
      api.routes['POST /channels/replies/unread'] = (_) => {
        'maxReadSeq': 1,
        'unreadCount': 1,
        'readStateVersion': 4,
      };
      api.routes['GET /channels/unread'] = (_) => {'channels': {}};
      int reads() => api.calls
          .where((call) => call.path == '/channels/replies/read')
          .length;
      Future<void> open() => w.openThreadIdentity(
        parentChannelId: 'c1',
        parentMessageId: 'parent',
        initialThreadChannelId: 'replies',
        navigate: false,
      );
      w.navigation.navigate(w.location.withQuery({'thread': 'c1:parent'}));
      await open();

      await w.conversationReads.markOpenThreadUnread('replies');
      final initial = reads();
      await w.markRead('replies');
      expect(reads(), initial);
      expect(w.threadChannelId, 'replies');
      expect(
        api.calls.where((call) => call.path == '/channels/replies/unread'),
        hasLength(1),
      );

      w.closeThread(navigate: false);
      await open();
      await w.markRead('replies');
      expect(reads(), greaterThan(initial));
    },
  );
}
