import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/agent_message_collapse.dart';
import 'package:raft_sync/raft_sync.dart';

void main() {
  AgentMessageCollapseSession visit(String scope) =>
      AgentMessageCollapseSession()..bind(scope);

  bool open(
    AgentMessageCollapseSession session,
    String id, {
    bool agent = true,
    int seq = 8,
    int? maxRead = 5,
  }) => session.startsOpen(
    messageId: id,
    agent: agent,
    seq: BigInt.from(seq),
    maxReadSeq: maxRead == null ? null : BigInt.from(maxRead),
  );

  test('an unread agent message starts open and stays open once read', () {
    final session = visit('channel');
    expect(open(session, 'a', seq: 8, maxRead: 5), isTrue);
    expect(open(session, 'a', seq: 8, maxRead: 8), isTrue);
    expect(open(session, 'a', seq: 8, maxRead: 20), isTrue);
  });

  test(
    'a read agent message starts closed, including seq equal to the cursor',
    () {
      final session = visit('channel');
      expect(open(session, 'read', seq: 4, maxRead: 5), isFalse);
      expect(open(session, 'edge', seq: 5, maxRead: 5), isFalse);
      expect(open(session, 'edge', seq: 5, maxRead: null), isFalse);
    },
  );

  test('a missing cursor is unread, the same as the unread count', () {
    final session = visit('channel');
    expect(open(session, 'a', maxRead: null), isTrue);
    expect(open(session, 'a', seq: 1, maxRead: 100), isTrue);
  });

  test('a manual collapse or expand wins over the cursor', () {
    final session = visit('channel');
    expect(open(session, 'unread', seq: 9, maxRead: 1), isTrue);
    session.choose('unread', false);
    expect(open(session, 'unread', seq: 9, maxRead: 1), isFalse);

    expect(open(session, 'read', seq: 1, maxRead: 9), isFalse);
    session.choose('read', true);
    expect(open(session, 'read', seq: 1, maxRead: 9), isTrue);
  });

  test('the next visit follows the cursor again', () {
    final session = visit('channel');
    session.choose('read', true);
    expect(open(session, 'read', seq: 1, maxRead: 9), isTrue);
    session.bind('channel');
    expect(open(session, 'read', seq: 1, maxRead: 9), isTrue);

    session.bind('other');
    session.bind(null);
    session.bind('channel');
    expect(open(session, 'read', seq: 1, maxRead: 9), isFalse);
  });

  test('a non-agent message stays closed and is not locked', () {
    final session = visit('channel');
    expect(open(session, 'user', agent: false, seq: 9, maxRead: 1), isFalse);
    expect(open(session, 'user', agent: true, seq: 9, maxRead: 1), isTrue);
    session.choose('user', false);
    expect(open(session, 'user', agent: true, seq: 9, maxRead: 1), isFalse);
  });

  test('each mounted chat keeps its own visit', () {
    final firstOwner = Object();
    final secondOwner = Object();
    final first = agentCollapseOf(firstOwner)..bind('channel');
    first.choose('read', true);
    expect(identical(agentCollapseOf(firstOwner), first), isTrue);
    final second = agentCollapseOf(secondOwner)..bind('channel');
    expect(open(second, 'read', seq: 1, maxRead: 9), isFalse);

    releaseAgentCollapse(firstOwner);
    final restarted = agentCollapseOf(firstOwner)..bind('channel');
    expect(identical(restarted, first), isFalse);
    expect(open(restarted, 'read', seq: 1, maxRead: 9), isFalse);
  });

  test(
    'entry cursor preserves unread rows delivered after a read-all receipt',
    () {
      final session = AgentMessageCollapseSession()
        ..bind('channel', readAtOpen: (maxReadSeq: BigInt.from(5)));
      expect(open(session, 'late-first-page', seq: 8, maxRead: 8), isTrue);
      expect(open(session, 'late-second-page', seq: 6, maxRead: 20), isTrue);
      expect(open(session, 'old', seq: 5, maxRead: 20), isFalse);
      session.choose('late-first-page', false);
      expect(open(session, 'late-first-page', seq: 8, maxRead: 20), isFalse);
    },
  );

  test('a missing entry cursor remains unread after its receipt arrives', () {
    final session = AgentMessageCollapseSession()
      ..bind('channel', readAtOpen: (maxReadSeq: null));
    expect(open(session, 'first-history', seq: 8, maxRead: 20), isTrue);
  });

  test('returning to a conversation follows its new entry cursor', () {
    final session = AgentMessageCollapseSession()
      ..bind('channel', readAtOpen: (maxReadSeq: BigInt.from(5)));
    expect(open(session, 'reply', seq: 8, maxRead: 8), isTrue);
    session.bind('channel', readAtOpen: (maxReadSeq: BigInt.from(8)));
    expect(open(session, 'reply', seq: 8, maxRead: 8), isTrue);
    session.bind('other');
    session.bind('channel', readAtOpen: (maxReadSeq: BigInt.from(8)));
    expect(open(session, 'reply', seq: 8, maxRead: 8), isFalse);
  });

  test('an explicit new visit clears manual choices for the same scope', () {
    final session = AgentMessageCollapseSession()
      ..bind('channel', readAtOpen: (maxReadSeq: BigInt.from(5)));
    session.choose('reply', true);
    session.bind(
      'channel',
      readAtOpen: (maxReadSeq: BigInt.from(8)),
      newVisit: true,
    );
    expect(open(session, 'reply', seq: 8, maxRead: 8), isFalse);
  });

  test('long messages collapse unless the channel turns that off or the row is an action card or a forwarded bundle', () {
    const agent = {'senderType': 'agent', 'content': 'hello'};
    expect(longMessagesCollapse(agent, null), isTrue);
    expect(longMessagesCollapse(agent, const {}), isTrue);
    expect(
      longMessagesCollapse(agent, const {'collapseLongMessages': false}),
      isFalse,
    );
    expect(
      longMessagesCollapse(const {
        'actionMetadata': {'kind': 'action-card'},
      }, null),
      isFalse,
    );
    // Web `disabled={isActionCardMessage || forwardedBundle || ...}`: a
    // forwarded bundle has its own "View all" and never collapses.
    expect(
      longMessagesCollapse(const {
        'actionMetadata': {'kind': 'forwarded-bundle'},
      }, null),
      isFalse,
    );
  });

  test('the cursor is the accepted read fact behind the unread count', () {
    final ledger = ReadStateLedger();
    BigInt? cursor(String? scope) => scopeReadCursor(
      state: ledger.state,
      serverId: 'server',
      principalId: 'alice',
      scopeId: scope,
    );
    expect(cursor('channel'), isNull);
    expect(
      scopeReadCursor(
        state: ledger.state,
        serverId: null,
        principalId: 'alice',
        scopeId: 'channel',
      ),
      isNull,
    );
    expect(
      ledger.consumeUpdate(
        {
          'serverId': 'server',
          'scopeId': 'channel',
          'maxReadSeq': 5,
          'readStateVersion': 1,
        },
        serverId: 'server',
        principalId: 'alice',
      ),
      'accepted',
    );
    expect(cursor('channel'), BigInt.from(5));
    expect(cursor('thread'), isNull);

    final session = visit('channel');
    expect(open(session, 'past', seq: 5, maxRead: 5), isFalse);
    expect(
      session.startsOpen(
        messageId: 'new',
        agent: true,
        seq: BigInt.from(6),
        maxReadSeq: cursor('channel'),
      ),
      isTrue,
    );
  });
}
