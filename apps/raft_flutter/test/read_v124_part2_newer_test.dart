// Source: packages/web/src/store/messageStore.ts (loadNewerMessages) at
// v1.24.0-source.1
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/user_activity.dart';

import 'message_context_transition_test.dart' show row;
import 'message_presentation_test.dart' show fixture;

void main() {
  test('[BP-READ-025] paging forward from a permalink window to its end reads the newest seq', () async {
    final (w, api) = await fixture('member');
    addTearDown(w.dispose);
    w.setForeground(true);
    RaftUserActivity.mark();
    w.messageDomain.ledger.switchServer('s1');
    api.routes['GET /messages/context/m10'] = (_) => {
      'messages': [row('m10', 'c1', 10), row('m11', 'c1', 11)],
      'hasNewer': true,
      'hasOlder': true,
    };
    api.routes['GET /messages/channel/c1'] = (_) => {
      'messages': [row('m12', 'c1', 12), row('m13', 'c1', 13)],
      'hasMore': false,
    };
    api.routes['POST /channels/c1/read'] = (_) => {
      'maxReadSeq': 13,
      'readStateVersion': 1,
    };
    api.routes['GET /channels/unread'] = (_) => {'channels': {}};
    await w.jumpToMessage('c1', 'm10', navigate: false);
    expect(w.messageDomain.state.hasNewer, isTrue);
    w.conversationReads.unread = {'c1': 3};
    // The chat view calls markRead when the timeline reaches the latest end.
    await w.markRead('c1');
    expect(
      api.calls.where((c) => c.path == '/channels/c1/read'),
      isEmpty,
      reason: 'a window with newer pages is not read',
    );
    await w.messageDomain.navigation.newer();
    expect(w.messageDomain.state.hasNewer, isFalse);
    await w.markRead('c1');
    final reads = api.calls.where((c) => c.path == '/channels/c1/read');
    expect(reads, hasLength(1));
    expect(reads.single.data['seq'].toString(), '13');
    expect(w.conversationReads.unread['c1'] ?? 0, 0);
  });
}
