import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/activity_mark_all_read.dart';

import 'activity_incremental_refresh_test.dart'
    show ActivityClient, ActivityWorkspace;

void main() {
  late ActivityClient client;
  late ActivityWorkspace w;
  setUp(() {
    client = ActivityClient()..user = RaftRecord({'id': 'alice'});
    client.selectServer('s1');
    w = ActivityWorkspace(client)
      ..server = RaftRecord({'id': 's1', 'role': 'owner'});
  });
  tearDown(() async {
    w.dispose();
    await client.dispose();
  });

  test('Mark all read waits for a queued Mark as Unread write', () async {
    final unread = Completer<dynamic>();
    client.responses['POST /channels/c1/unread'] = unread.future;
    final toggle = w.conversationReads.markUnreadWithProjection('c1');
    await Future<void>.delayed(Duration.zero);
    var sent = false;
    final all = activityMarkAllRead(w, () async {
      sent = true;
      client.posts.add('POST /channels/inbox/read-all');
    });
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(sent, isFalse, reason: 'the unread write is still in flight');
    unread.complete({'unreadCount': 1, 'readStateVersion': 3, 'maxReadSeq': 4});
    await toggle;
    await all;
    expect(sent, isTrue);
    expect(
      client.posts.indexOf('POST /channels/c1/unread'),
      lessThan(client.posts.indexOf('POST /channels/inbox/read-all')),
    );
  });

  test('a failed toggle does not block Mark all read', () async {
    final unread = Completer<dynamic>();
    client.responses['POST /channels/c1/unread'] = unread.future;
    final toggle = w.conversationReads
        .markUnreadWithProjection('c1')
        .catchError((_) => false);
    var sent = false;
    final all = activityMarkAllRead(w, () async => sent = true);
    unread.completeError(const RaftApiException('no', status: 500));
    await toggle;
    await all;
    expect(sent, isTrue);
  });

  test('with nothing queued it sends at once', () async {
    var sent = false;
    await activityMarkAllRead(w, () async => sent = true);
    expect(sent, isTrue);
  });
}
