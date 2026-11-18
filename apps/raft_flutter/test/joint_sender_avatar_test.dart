import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/management_support.dart';
import 'package:raft_flutter/features/member_profile_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

import 'message_presentation_test.dart' show fixture;
import 'workspace_source_location_contract_test.dart'
    show mountPage, pageFixture, waitForPainted;

const _peerAvatar = '/api/avatars/users/9f2c4b7a1d3e5f60.webp';
const _peerId = 'u2000000-0000-4000-8000-0000000000c2';

/// The real `GET /channels/:id/members` joint roster (field-parity fixture):
/// the peer server's human (`serverId` != the open server) listed with an
/// uploaded avatar, and a peer agent.
Map<String, dynamic> roster() {
  final body =
      jsonDecode(
            File(
              'test/fixtures/field_parity/channels-members-roster-joint.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  return {
    ...body,
    'humans': [
      for (final human in body['humans'] as List)
        (human as Map)['id'] == _peerId
            ? {...human, 'avatarUrl': _peerAvatar}
            : human,
    ],
    'agents': [
      for (final agent in body['agents'] as List)
        (agent as Map)['name'] == 'acme-bot'
            ? {...agent, 'avatarUrl': 'pixel:robot'}
            : agent,
    ],
  };
}

/// Message rows exactly as a joint channel delivers them: no message-level
/// `sourceServerId` and no `senderAvatarUrl`, so the roster is the only source.
List<Map<String, dynamic>> messages() => [
  {
    'id': 'm1',
    'channelId': 'c1',
    'seq': 1,
    'senderId': _peerId,
    'senderType': 'user',
    'senderName': 'Pat (Acme)',
    'content': 'Hello from the partner server',
    'createdAt': '2026-06-22T02:30:00Z',
  },
  {
    'id': 'm2',
    'channelId': 'c1',
    'seq': 2,
    'senderId': 'a2000000-0000-4000-8000-0000000000ab',
    'senderType': 'agent',
    'senderName': 'acme-bot',
    'content': 'Peer agent reply',
    'createdAt': '2026-06-22T02:35:00Z',
  },
];

RaftAvatarContent contentOf(WidgetTester t, String name) => t
    .widgetList<RaftAvatarContent>(find.byType(RaftAvatarContent))
    .firstWhere((c) => c.name == name);

/// Alternates fake-clock pumps (timers, rebuilds) with real time (the fake
/// transport's I/O) until both have drained.
Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 50));
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
  }
  await t.pump();
}

void main() {
  for (final (kind, listed) in [
    ('human', true),
    ('human', false),
    ('agent', true),
  ]) {
    final scenario = listed ? kind : 'human absent from this channel roster';
    testWidgets('joint $scenario opens only the authorized profile', (t) async {
      final (w, api) = await pageFixture(t, section: 'chat');
      final channel = RaftChannel({
        'id': 'c1',
        'serverId': 's1',
        'name': 'Joint channel',
        'type': 'joint',
        'joined': true,
      });
      w.channel = channel;
      w.channels = [channel];
      final human = kind == 'human';
      final message = messages()[human ? 0 : 1];
      final senderId = message['senderId'] as String;
      final messageId = message['id'] as String;
      w.messageDomain.ledger.ingest([
        message,
      ], expectedGeneration: w.messageDomain.ledger.generation);
      w.messageDomain.visibleIds['c1'] = {messageId};
      final path = human
          ? '/servers/s1/members/$senderId/profile'
          : '/agents/$senderId';
      const name = 'Partner Profile', serverName = 'Displayed joint partner';
      api.routes.addAll({
        'GET /channels/c1/members': (_) => {
          ...roster(),
          if (!listed) 'humans': [],
        },
        'GET /agents': (_) => [],
        'GET /servers/s1/members': (_) => [],
        'GET /servers/s1/machines': (_) => {'machines': []},
        'GET $path': (request) => {
          'id': senderId,
          if (human) 'userId': senderId,
          'name': 'partner',
          'displayName': name,
          'serverId': listed || request.queryParameters['channelId'] == null
              ? 'partner'
              : '',
          'serverName': human && request.queryParameters['channelId'] != 'c1'
              ? 'Different joint channel'
              : listed
              ? serverName
              : '',
          'avatarUrl': null,
          'description': 'Public description',
          if (human) ...{
            'createdAgents': [],
            'email': null,
            'role': null,
            'membershipStatus': 'active',
            'profileProjection': 'channel_summary',
            if (!listed && request.queryParameters['channelId'] == 'c1')
              'servers': [],
          } else
            'status': 'active',
        },
      });
      await mountPage(t, w, false, platform: TargetPlatform.linux);
      try {
        await waitForPainted(t, messageId);
        final avatar = find
            .byKey(ValueKey('sender-avatar-$messageId'))
            .hitTestable();
        if (!human) {
          final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
          await mouse.addPointer(location: Offset.zero);
          await mouse.moveTo(t.getCenter(avatar));
          await t.pump(const Duration(milliseconds: 210));
          await t.pump(const Duration(milliseconds: 300));
          await t.pumpAndSettle();
          final hover = find.byType(RaftProfilePreviewCard);
          expect(hover, findsOneWidget);
          expect(
            find.descendant(of: hover, matching: find.text('Computer')),
            findsNothing,
          );
          expect(
            find.descendant(of: hover, matching: find.text('Recent activity')),
            findsNothing,
          );
          expect(
            api.calls.where((call) => call.path == '$path/activity-log'),
            isEmpty,
          );
          await mouse.removePointer();
          await t.pumpAndSettle();
        }
        await t.tap(avatar, kind: PointerDeviceKind.mouse);
        await t.pumpAndSettle();

        final profile = find.byKey(ValueKey('profile-$kind-$senderId'));
        expect(
          find.descendant(of: profile, matching: find.text(name)),
          findsWidgets,
        );
        expect(
          find.descendant(of: profile, matching: find.text(serverName)),
          listed ? findsWidgets : findsNothing,
        );
        expect(
          find.descendant(
            of: profile,
            matching: find.text('Different joint channel'),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: profile,
            matching: find.byTooltip(human ? 'Message' : 'Direct message'),
          ),
          findsNothing,
        );
        expect(
          find.descendant(of: profile, matching: find.text('Reminders')),
          findsNothing,
        );
        final requests = api.calls.where((call) => call.path == path);
        expect(requests, isNotEmpty);
        for (final request in requests) {
          expect(request.queryParameters['channelId'], human ? 'c1' : isNull);
        }
        expect(
          api.calls.where((call) => call.path.startsWith('$path/')),
          isEmpty,
        );
      } finally {
        await t.pumpWidget(const SizedBox.shrink());
        await t.pumpAndSettle();
      }
    });
  }

  testWidgets(
    'channel revocation closes a scoped profile and retires its read',
    (t) async {
      final (w, api) = await pageFixture(t);
      const path = '/servers/s1/members/$_peerId/profile';
      final profile = {
        'name': 'partner',
        'displayName': 'Scoped partner profile',
        'description': 'Scoped description',
      };
      final channel = RaftChannel({
        'id': 'c1',
        'serverId': 's1',
        'name': 'Joint channel',
        'type': 'joint',
        'joined': true,
      });
      w.channel = RaftChannel({
        'id': 'c2',
        'name': 'Other channel',
        'joined': true,
      });
      w.channels = [channel, w.channel!];
      api.routes['GET $path'] = (_) => profile;
      await mountPage(t, w, false, platform: TargetPlatform.linux);
      try {
        w.openProfile(RaftProfileKind.human, _peerId, channelId: 'c1');
        await t.pumpAndSettle();
        expect(find.text('Scoped description'), findsOneWidget);

        final delayed = Completer<Map<String, dynamic>>();
        api.routes['GET $path'] = (_) => delayed.future;
        final view = t.state<ManagementState<MemberProfileView>>(
          find.byType(MemberProfileView),
        );
        unawaited(view.reload());
        await settle(t);
        expect(api.calls.where((call) => call.path == path), hasLength(2));

        api.routes['GET /channels/c1'] = (_) => (404, {'error': 'Not found'});
        await t.runAsync(() => w.refreshChannel('c1'));
        await t.pumpAndSettle();
        expect(w.location.profile, isNull);
        expect(find.text('Scoped description'), findsNothing);

        delayed.complete({...profile, 'description': 'Retired profile reply'});
        await t.pumpAndSettle();
        expect(find.text('Retired profile reply'), findsNothing);
      } finally {
        await t.pumpWidget(const SizedBox.shrink());
        await t.pumpAndSettle();
      }
    },
  );

  for (final (dark) in raftThemeMatrix([(false)])) {
    testWidgets(
      '${dark ? 'dark' : 'light'} joint peer sender avatar comes from the channel roster, once, and rows update when it arrives',
      (t) async {
        final (w, transport) = (await t.runAsync(() => fixture('owner')))!;
        addTearDown(w.dispose);
        w.channel = RaftChannel({
          'id': 'c1',
          'name': 'swift-workflow',
          'type': 'joint',
          'joined': true,
        });
        w.channels = [w.channel!];
        w.messageDomain.ledger.switchServer('s1');
        w.messageDomain.ledger.ingest(
          messages(),
          expectedGeneration: w.messageDomain.ledger.generation,
        );
        w.messageDomain.visibleIds['c1'] = {'m1', 'm2'};
        // The server directory holds this server's people only.
        transport.routes['GET /servers/s1/members'] = (_) => [
          {'userId': 'alice', 'name': 'alice', 'role': 'owner'},
        ];
        transport.routes['GET /agents'] = (_) => [];
        transport.routes['POST /feature-flags/evaluate'] = (_) => {
          'evaluations': [],
        };
        final rosterReply = Completer<Map<String, dynamic>>();
        transport.routes['GET /channels/c1/members'] = (_) =>
            rosterReply.future;
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: Scaffold(body: RaftChatView(controller: w)),
          ),
        );
        await settle(t);
        expect(find.text('Hello from the partner server'), findsOneWidget);
        // Before the roster: the generic placeholder (no URL), not an error.
        expect(contentOf(t, 'Pat (Acme)').uploadedUrl, isNull);
        expect(contentOf(t, 'acme-bot').pixelKey, isNull);
        expect(contentOf(t, 'acme-bot').uploadedUrl, isNull);

        rosterReply.complete(roster());
        await settle(t);
        // The roster arrived later: the mounted rows rebuilt with the peer's
        // uploaded avatar (resolved against the active origin); its gravatar
        // hash is ignored (retired in server v1.24, as Web does).
        final pat = contentOf(t, 'Pat (Acme)');
        expect(pat.uploadedUrl, 'https://example.invalid$_peerAvatar');
        expect(pat.gravatarUrl, isNull);
        // A peer agent comes from the same roster (`pixel:` artwork).
        expect(contentOf(t, 'acme-bot').pixelKey, 'robot');
        // Fetched once per channel, never per row.
        expect(
          transport.calls.where((c) => c.path == '/channels/c1/members').length,
          1,
        );
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 1));
        expect(t.takeException(), isNull);
      },
    );
  }
}
