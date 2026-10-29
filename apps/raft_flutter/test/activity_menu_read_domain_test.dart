import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';

import 'activity_incremental_refresh_test.dart'
    show ActivityClient, ActivityWorkspace;

class MenuWorkspace extends ActivityWorkspace {
  MenuWorkspace(super.client);
  int unreadRefreshes = 0;
  @override
  Future<void> refreshUnread() async => unreadRefreshes++;
}

void main() {
  late ActivityClient client;
  late MenuWorkspace w;
  setUp(() {
    client = ActivityClient()..user = RaftRecord({'id': 'alice'});
    client.selectServer('s1');
    w = MenuWorkspace(client)
      ..server = RaftRecord({'id': 's1', 'role': 'owner'})
      ..conversationReads.unread = {'ch1': 3};
  });
  tearDown(() async {
    w.dispose();
    await client.dispose();
  });

  test('explicit menu read-all folds the acknowledged cursor without a visible window', () async {
    client.responses['POST /channels/ch1/read-all'] = {
      'maxReadSeq': 9,
      'readStateVersion': 1,
    };
    await w.conversationReads.markAllRead('ch1');
    expect(client.posts, ['POST /channels/ch1/read-all']);
    expect(
      client.bodies.single,
      isNull,
      reason: 'read-all never guesses a sequence from the Activity row',
    );
    expect(w.readState.state('s1', 'alice', 'ch1')?['maxReadSeq'], 9);
    expect(w.conversationReads.unread['ch1'], 0);
  });

  test('late read-all acknowledgement cannot update another server', () async {
    final response = Completer<dynamic>();
    client.responses['POST /channels/ch1/read-all'] = response.future;
    final pending = w.conversationReads.markAllRead('ch1');
    client.selectServer('s2');
    response.complete({'maxReadSeq': 9, 'readStateVersion': 1});
    await pending;
    expect(w.readState.state('s1', 'alice', 'ch1'), isNull);
    expect(w.conversationReads.unread['ch1'], 3);
  });

  test('mark unread preserves the injected receiver refresh on success and failure', () async {
    await w.conversationReads.markUnread('ch1');
    expect(w.unreadRefreshes, 1);
    final response = Completer<dynamic>();
    client.responses['POST /channels/ch1/unread'] = response.future;
    final pending = w.conversationReads.markUnread('ch1');
    final failed = expectLater(pending, throwsStateError);
    response.completeError(StateError('synthetic offline'));
    await failed;
    expect(w.unreadRefreshes, 2);
    expect(client.posts, [
      'POST /channels/ch1/unread',
      'POST /channels/ch1/unread',
    ]);
  });

  test(
    'mark unread does not refresh a replacement receiver after a late response',
    () async {
      final response = Completer<dynamic>();
      client.responses['POST /channels/ch1/unread'] = response.future;
      final pending = w.conversationReads.markUnread('ch1');
      client.selectServer('s2');
      response.complete({});
      await pending;
      expect(w.unreadRefreshes, 0);
    },
  );

  test('revoked conversations cannot send menu read commands', () async {
    client.emit('channel:removed', {'channelId': 'ch1'});
    await w.conversationReads.markAllRead('ch1');
    await w.conversationReads.markUnread('ch1');
    expect(client.posts, isEmpty);
    expect(w.unreadRefreshes, 0);
  });

  test(
    'disposed and signed-out receivers cannot send menu read commands',
    () async {
      client.user = null;
      await w.conversationReads.markAllRead('ch1');
      await w.conversationReads.markUnread('ch1');
      client.user = RaftRecord({'id': 'alice'});
      w.dispose();
      await w.conversationReads.markAllRead('ch1');
      await w.conversationReads.markUnread('ch1');
      expect(client.posts, isEmpty);
      expect(w.unreadRefreshes, 0);
    },
  );
}
