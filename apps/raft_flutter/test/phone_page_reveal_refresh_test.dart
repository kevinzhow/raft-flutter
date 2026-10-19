import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/mobile_tabbar_preferences.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/channel_form_fields.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'activity_open_clears_new_test.dart' show activityRow;
import 'message_presentation_test.dart' show MessageAdapter;
import 'support/app_services_fixture.dart';
import 'thread_agent_followers_test.dart' show follower;
import 'workspace_source_location_contract_test.dart' show pageFixture;

/// A phone page that is covered keeps its last build (`retainWhileCovered`).
/// It must show what changed under it the moment it is current again.
class _Client extends RaftClient {
  _Client(MessageAdapter api)
    : super(
        origin: 'https://example.invalid',
        sessionStore: MemorySessionStore(),
        transport: Dio()..httpClientAdapter = api,
      );
  final ingress = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => ingress.stream;
  @override
  Future<void> dispose() async {
    await ingress.close();
    await super.dispose();
  }
}

Map<String, dynamic> _reply(int seq, String text) => {
  'id': 'm$seq',
  'channelId': 'thread-1',
  'seq': '$seq',
  'senderType': 'user',
  'senderId': 'bob',
  'senderName': 'Bob',
  'content': text,
};

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<(WorkspaceController, _Client, List<Map<String, dynamic>>)> _mount(
  WidgetTester tester,
) async {
  SharedPreferences.setMockInitialValues({
    MobileTabbarStore.preferenceKey: jsonEncode({
      'order': ['chat', 'tasks', 'activity', 'computers', 'members'],
      'enabled': ['chat', 'tasks', 'activity', 'computers'],
    }),
  });
  addTearDown(DevicePreferences.reset);
  await tester.runAsync(DevicePreferences.load);
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final api = MessageAdapter();
  api.routes['POST /auth/login'] = (_) => {
    'accessToken': 'fixture-only',
    'refreshToken': 'fixture-only',
    'user': {'id': 'alice'},
  };
  final (client, w) = (await tester.runAsync(() async {
    final client = _Client(api);
    await client.login('fixture', 'fixture');
    client.selectServer('s1');
    return (client, WorkspaceController(client));
  }))!;
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    w.dispose();
    await client.dispose();
  });
  w.server = RaftRecord({'id': 's1', 'role': 'owner'});
  w.channels = [
    RaftChannel({'id': 'c1', 'name': 'test', 'joined': true}),
  ];
  w.loading = false;
  w.connected = true;
  w.messageDomain.ledger.switchServer('s1');
  w.section = 'activity';
  final replies = [_reply(5, 'The first reply')];
  final followers = <Map<String, dynamic>>[follower('a1', 'Cindy')];
  final row = activityRow('thread', unread: 0, seq: '5');
  api.routes['GET /channels/inbox'] = (_) => {
    'items': [row],
    'totalCount': 1,
    'totalUnreadCount': 0,
    'hasMore': false,
  };
  api.routes['GET /agents'] = (_) => [];
  api.routes['GET /servers/s1/members'] = (_) => [];
  api.routes['GET /channels/unread'] = (_) => {'channels': {}};
  api.routes['GET /channels/c1'] = (_) => w.channels.first.json;
  api.routes['GET /channels/threads/followed'] = (_) => {'threads': []};
  api.routes['GET /channels/threads/followers'] = (_) => {
    'threads': [
      {'threadChannelId': 'thread-1', 'canManage': true, 'agents': followers},
    ],
  };
  api.routes['GET /channels/c1/threads/parent'] = (_) => {
    'threadChannelId': 'thread-1',
  };
  api.routes['GET /messages/context/parent'] = (_) => {
    'messages': [
      {
        ..._reply(1, 'The parent message of the thread'),
        'id': 'parent',
        'channelId': 'c1',
      },
    ],
  };
  api.routes['GET /messages/context/m5'] = (_) => {
    'messages': replies,
    'hasOlder': false,
    'hasNewer': false,
  };
  api.routes['GET /messages/channel/c1'] = (_) => {'messages': []};
  api.routes['GET /messages/channel/thread-1'] = (_) => {'messages': replies};
  api.routes['GET /servers/s1/members/bob/profile'] = (_) => {
    'userId': 'bob',
    'displayName': 'Bob',
  };
  for (final path in ['read', 'read-all']) {
    api.routes['POST /channels/thread-1/$path'] = (_) => {
      'maxReadSeq': 9,
      'readStateVersion': 3,
    };
  }
  api.routes['POST /feature-flags/evaluate'] = (_) => {'evaluations': []};
  api.routes['GET /servers/s1/setup-projection'] = (_) => {
    'phase': 'complete',
    'surface': 'complete',
    'blocksChat': false,
  };
  await tester.pumpWidget(
    MaterialApp(
      theme: raftTheme(RaftFamily.brutal),
      home: withAppServices(
        WorkspaceView(
          controller: w,
          appearance: RaftAppearance(light: RaftFamily.brutal),
          onAppearance: (_) async {},
          onLogout: () async {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('activity-thread-thread-1')));
  await _settle(tester);
  expect(w.threadChannelId, 'thread-1');
  return (w, client, followers);
}

bool _seen(String text, {bool covered = false}) => find
    .textContaining(text, findRichText: true, skipOffstage: !covered)
    .evaluate()
    .isNotEmpty;

void main() {
  testWidgets('a thread page covered by a profile shows the new reply, the '
      'new count and the new followers as soon as it is current again', (
    tester,
  ) async {
    final (w, client, followers) = await _mount(tester);
    expect(_seen('The first reply'), isTrue);
    expect(_seen('1 replies'), isTrue);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('thread-followers-thread-1')),
        matching: find.byType(ChannelCandidateAvatar),
      ),
      findsOneWidget,
    );

    // A page opens over the thread.
    w.openProfile(RaftProfileKind.human, 'bob');
    await _settle(tester);
    expect(w.location.profile, isNotNull);
    final thread = find.byKey(
      const Key('workspace-mobile-detail-header'),
      skipOffstage: false,
    );
    expect(thread, findsOneWidget, reason: 'the thread page is still mounted');

    // While it is covered: a reply arrives and a follower is added.
    followers.add(follower('a2', 'Product UX'));
    client.ingress.add(RaftEvent('message:new', _reply(6, 'A newer reply')));
    // The thread's parent message changes (an edit lands in the workspace).
    final parent = w.messageDomain.state.threadParent!;
    w.messageDomain.state.threadParent = RaftMessage({
      ...parent.json,
      'content': 'The parent message was edited',
    });
    w.notifyListeners();
    client.ingress.add(
      RaftEvent('thread:followers-updated', {'threadChannelId': 'thread-1'}),
    );
    await _settle(tester);
    expect(
      w.services.threadFollowers.roster('thread-1')?.agents.length,
      2,
      reason: 'the store took the change while the page was covered',
    );

    // The covered page really kept its last build (the test is not vacuous).
    expect(
      _seen('The parent message of', covered: true),
      isTrue,
      reason: 'the covered page kept its last build (the test is not vacuous)',
    );

    // Back to the thread.
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(w.location.profile, isNull);
    expect(w.location.thread, isNotNull);
    expect(_seen('was edited'), isTrue, reason: 'edited parent message');
    expect(
      _seen('The parent message of', covered: true),
      isFalse,
      reason: 'no stale parent message left',
    );
    expect(_seen('A newer reply'), isTrue, reason: 'new reply');
    expect(_seen('2 replies'), isTrue, reason: 'new reply count');
    expect(_seen('1 replies'), isFalse, reason: 'old reply count');
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('thread-followers-thread-1')),
        matching: find.byType(ChannelCandidateAvatar),
      ),
      findsNWidgets(2),
      reason: 'new follower count in the header',
    );
  });

  testWidgets('a channel page covered by a thread shows the message that '
      'arrived under it as soon as it is current again', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (w, api) = await pageFixture(tester, section: 'chat');
    Map<String, dynamic> row(String id, int seq, String text) => {
      'id': id,
      'channelId': 'c1',
      'seq': '$seq',
      'messageType': 'chat',
      'senderId': 'u2',
      'senderType': 'user',
      'senderName': 'Dana',
      'content': text,
      'createdAt': '2026-06-22T02:30:00.000Z',
    };
    final rows = [
      for (var i = 1; i <= 6; i++) row('f$i', i, 'Filler message $i'),
      {...row('mt', 7, 'The thread parent'), 'replyCount': 1},
    ];
    api.routes['GET /messages/channel/c1'] = (_) => {'messages': rows};
    api.routes['GET /channels/c1/available-mentions'] = (_) => {
      'humans': [],
      'agents': [],
    };
    api.routes['GET /agents'] = (_) => [];
    api.routes['GET /servers/s1/members'] = (_) => [];
    api.routes['GET /channels/c1/threads/mt'] = (_) => {
      'threadChannelId': 't1',
    };
    api.routes['GET /messages/channel/t1'] = (_) => {
      'messages': [
        {...row('mt', 1, 'The thread parent'), 'channelId': 't1'},
      ],
    };
    api.routes['GET /channels/threads/followers'] = (_) => {'threads': []};
    await tester.runAsync(() => w.entityDirectory.preload());
    w.messageDomain.ledger.ingest(
      rows,
      expectedGeneration: w.messageDomain.ledger.generation,
    );
    w.messageDomain.visibleIds['c1'] = {
      for (final r in rows) r['id'] as String,
    };
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: withAppServices(
          WorkspaceView(
            controller: w,
            appearance: RaftAppearance(light: RaftFamily.elegant),
            onAppearance: (_) async {},
            onLogout: () async {},
          ),
        ),
      ),
    );
    await _settle(tester);
    expect(_seen('Filler message 3'), isTrue);

    await tester.runAsync(
      () => w.messageDomain.threads.openThread(RaftMessage(rows.last)),
    );
    await _settle(tester);
    expect(w.location.thread, isNotNull);

    // While the channel page is covered by the thread, a message arrives.
    final arrival = row('live1', 8, 'A message that arrived under the thread');
    w.messageDomain.ledger.ingest([
      arrival,
    ], expectedGeneration: w.messageDomain.ledger.generation);
    w.messageDomain.visibleIds['c1'] = {
      ...?w.messageDomain.visibleIds['c1'],
      'live1',
    };
    w.notifyListeners();
    await _settle(tester);

    await tester.tap(find.byKey(const Key('mobile-detail-back')));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(w.location.thread, isNull);
    expect(
      _seen('A message that arrived under the thread'),
      isTrue,
      reason: 'the channel page is up to date on the first settled frame',
    );
    expect(_seen('Filler message'), isTrue);
  });
}
