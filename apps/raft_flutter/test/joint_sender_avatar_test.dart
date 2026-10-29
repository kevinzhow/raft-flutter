import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

import 'message_presentation_test.dart' show fixture;

const _peerAvatar = '/api/avatars/users/9f2c4b7a1d3e5f60.webp';
const _peerId = 'u2000000-0000-4000-8000-0000000000c2';

/// The real `GET /channels/:id/members` joint roster (field-parity fixture):
/// the peer server's human (`serverId` != the open server) listed with an
/// uploaded avatar, and a peer agent.
Map<String, dynamic> roster() {
  final body = jsonDecode(
    File('test/fixtures/field_parity/channels-members-roster-joint.json')
        .readAsStringSync(),
  ) as Map<String, dynamic>;
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
        // uploaded avatar (resolved against the active origin) and gravatar.
        final pat = contentOf(t, 'Pat (Acme)');
        expect(pat.uploadedUrl, 'https://example.invalid$_peerAvatar');
        expect(
          pat.gravatarUrl,
          startsWith('https://www.gravatar.com/avatar/2222'),
        );
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
