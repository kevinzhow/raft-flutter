@Tags(['slow'])
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show MessageAdapter;
import 'workspace_source_location_contract_test.dart' show pageFixture;
import 'support/app_services_fixture.dart';

TargetPlatform platform = TargetPlatform.android;

void main() {
  Map<String, dynamic> row(String id, int seq, Map<String, dynamic> extra) => {
    'id': id,
    'channelId': 'c1',
    'seq': '$seq',
    'messageType': 'chat',
    'content': 'Hello $id',
    'createdAt': '2026-06-22T02:30:00.000Z',
    ...extra,
  };

  // Newest last. m1..m6 filler so the list scrolls on a phone; the sender
  // rows sit near the bottom, `mention` pings an agent.
  List<Map<String, dynamic>> rows() => [
    for (var i = 1; i <= 14; i++)
      row('f$i', i, {
        'senderId': 'u2',
        'senderType': 'user',
        'senderName': 'Dana',
        'content': 'Filler message number $i with some body text to wrap',
      }),
    row('mh', 15, {
      'senderId': 'bob',
      'senderType': 'user',
      'senderName': 'Bob',
      'content': 'human row',
    }),
    row('ma', 16, {
      'senderId': 'a1',
      'senderType': 'agent',
      'senderName': 'Cindy',
      'content': 'agent row',
    }),
    row('mx', 17, {
      'senderId': 'slack-ada',
      'senderType': 'external_projection',
      'senderName': 'Ada',
      'content': 'external row',
      'externalAuthor': {
        'displayName': 'Ada Lovelace',
        'provider': 'slack',
        'actorKind': 'human',
        'workspaceName': 'Acme Product Studio',
      },
    }),
    row('mm', 18, {
      'senderId': 'u2',
      'senderType': 'user',
      'senderName': 'Dana',
      'content': 'ping @cindy please',
      'mentions': [
        {'type': 'agent', 'id': 'a1', 'name': 'cindy'},
      ],
    }),
    row('mt', 19, {
      'senderId': 'u2',
      'senderType': 'user',
      'senderName': 'Dana',
      'content': 'thread parent',
      'replyCount': 1,
    }),
  ];

  Future<void> frames(WidgetTester t, [int n = 14]) async {
    for (var i = 0; i < n; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
  }

  Future<(WorkspaceController, MessageAdapter)> mount(
    WidgetTester t,
    Size size,
  ) async {
    debugDefaultTargetPlatformOverride = platform;
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final (w, api) = await pageFixture(t, section: 'chat');
    api.routes['GET /messages/channel/c1'] = (_) => {'messages': rows()};
    api.routes['GET /channels/c1/available-mentions'] = (_) => {
      'humans': [],
      'agents': [],
    };
    const agent = {
      'id': 'a1',
      'name': 'cindy',
      'displayName': 'Cindy',
      'status': 'active',
      'runtime': 'claude',
      'model': 'sonnet',
    };
    api.routes['GET /agents'] = (_) => [agent];
    api.routes['GET /servers/s1/members'] = (_) => [
      {'userId': 'bob', 'name': 'bob', 'displayName': 'Bob', 'role': 'member'},
      {'userId': 'u2', 'name': 'dana', 'displayName': 'Dana', 'role': 'member'},
    ];
    api.routes['GET /channels/c1/threads/mt'] = (_) => {
      'threadChannelId': 't1',
    };
    api.routes['GET /messages/channel/t1'] = (_) => {
      'messages': [
        row('mt', 1, {
          'channelId': 't1',
          'senderId': 'u2',
          'senderType': 'user',
          'senderName': 'Dana',
          'content': 'thread parent',
        }),
      ],
    };
    api.routes['GET /channels/threads/followers'] = (_) => {
      'threads': [
        {
          'threadChannelId': 't1',
          'canManage': true,
          'agents': [
            {
              'id': 'a1',
              'name': 'Cindy',
              'displayName': 'Cindy',
              'status': 'active',
              'avatarUrl': 'pixel:robot',
              'isCurrentServer': true,
              'canRemove': true,
            },
          ],
        },
      ],
    };
    api.routes['GET /agents/a1'] = (_) => agent;
    api.routes['GET /servers/s1/machines'] = (_) => {'machines': []};
    api.routes['GET /agents/a1/skills'] = (_) => {
      'global': [],
      'workspace': [],
    };
    api.routes['GET /servers/s1/members/bob/profile'] = (_) => {
      'userId': 'bob',
      'displayName': 'Bob',
    };
    await t.runAsync(() => w.entityDirectory.preload());
    w.messageDomain.ledger.ingest(
      rows(),
      expectedGeneration: w.messageDomain.ledger.generation,
    );
    w.messageDomain.visibleIds['c1'] = {
      for (final r in rows()) r['id'] as String,
    };
    await t.pumpWidget(
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
    await frames(t, 30);
    return (w, api);
  }

  Finder avatar(String id) => find.byKey(ValueKey('sender-avatar-$id'));

  // The agent profile's Direct Message action, then the composer focused with
  // the soft keyboard up: the DM must stay open (it used to pop back to the
  // channel on a phone because the profile's Back ran after the jump).
  for (final (name, size, plat) in [
    ('phone', const Size(390, 844), TargetPlatform.android),
    ('foldable folded', const Size(360, 780), TargetPlatform.android),
    ('foldable unfolded', const Size(856, 944), TargetPlatform.android),
    ('desktop', const Size(1280, 800), TargetPlatform.linux),
  ]) {
    testWidgets('DM from the agent profile stays open ($name)', (t) async {
      platform = plat;
      final (w, api) = await mount(t, size);
      const dm = {
        'id': 'dm1',
        'name': 'cindy',
        'type': 'dm',
        'joined': true,
        'peerId': 'a1',
        'peerType': 'agent',
        'peerDisplayName': 'Cindy',
      };
      api.routes['POST /channels/dm'] = (_) => dm;
      api.routes['GET /channels/dm1'] = (_) => dm;
      api.routes['GET /messages/channel/dm1'] = (_) => {'messages': []};
      api.routes['POST /channels/dm1/read'] = (_) => {};
      await t.ensureVisible(avatar('ma'));
      await frames(t, 4);
      await t.tap(avatar('ma'));
      await frames(t, 20);
      expect(find.byKey(const Key('profile-panel')), findsOneWidget);
      final inline = find.byKey(const Key('agent-profile-inline-message'));
      if (inline.evaluate().isNotEmpty) {
        await t.tap(inline);
      } else {
        await t.tap(find.byKey(const Key('agent-profile-overflow-trigger')));
        await frames(t, 10);
        await t.tap(find.text('Direct Message'));
      }
      await frames(t, 30);
      expect(w.channel?.id, 'dm1');
      expect(w.location.route, RaftRoute.dm);
      expect(find.byKey(const Key('profile-panel')), findsNothing);
      final field = find.byType(EditableText);
      expect(field, findsOneWidget);
      await t.tap(field);
      await frames(t, 10);
      if (plat == TargetPlatform.android) {
        t.view.viewInsets = const FakeViewPadding(bottom: 300);
        await frames(t, 20);
        expect(w.channel?.id, 'dm1');
        t.view.resetViewInsets();
        await frames(t, 20);
      }
      expect(w.channel?.id, 'dm1');
      expect(w.location.route, RaftRoute.dm);
      expect(field, findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });
  }
}
