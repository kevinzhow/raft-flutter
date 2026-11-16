// Agent Lounge v0 and the DM tool-stuck line, mounted in the real workspace
// shell (Web v1.24 ChatPanel.tsx isLounge / loungeReadOnly, useChannelHeadToggles
// onOpenLounge, AgentDMStatus useToolStuckText). Every case runs at the two
// folded-phone sizes on Android and on a narrow desktop window on Linux.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show MessageAdapter;
import 'support/app_services_fixture.dart';
import 'workspace_source_location_contract_test.dart' show pageFixture, frames;

const _configs = <(Size, TargetPlatform)>[
  (Size(856, 944), TargetPlatform.android),
  (Size(944, 856), TargetPlatform.android),
  (Size(390, 844), TargetPlatform.linux),
];

Map<String, dynamic> _agent({
  Map<String, dynamic>? toolStuck,
  String? blockedReason,
  String status = 'active',
  String? assistantOwnerUserId,
}) => {
  'id': 'a1',
  'name': 'bot',
  'displayName': 'Bot',
  'serverId': 's1',
  'runtime': 'claude',
  'status': status,
  'model': 'sonnet',
  'activity': status == 'active' ? 'online' : 'offline',
  'avatarUrl': null,
  'toolStuck': ?toolStuck,
  'blockedReason': ?blockedReason,
  'assistantOwnerUserId': ?assistantOwnerUserId,
};

Map<String, dynamic> _stuck() => {
  'toolName': 'bash',
  'quietSinceMs': DateTime.now().millisecondsSinceEpoch - 4 * 60000,
  'thresholdMs': 180000,
  'queuedMessages': 2,
};

final _dm = RaftChannel({
  'id': 'dm-bot',
  'type': 'dm',
  'joined': true,
  'peerId': 'a1',
  'peerType': 'agent',
  'peerName': 'bot',
  'peerDisplayName': 'Bot',
});

Map<String, dynamic> _loungeRow({bool canPost = true, bool joined = false}) => {
  'id': 'lg1',
  'name': 'bot-lounge',
  'type': 'channel',
  'joined': joined,
  'loungeAgentId': 'a1',
  'canPost': canPost,
};

class _Shell {
  _Shell(this.w, this.api);
  final WorkspaceController w;
  final MessageAdapter api;
}

Future<_Shell> _mount(
  WidgetTester t, {
  required Size size,
  required TargetPlatform platform,
  required RaftChannel open,
  bool flag = true,
  String role = 'owner',
  Map<String, dynamic>? agent,
}) async {
  final (w, api) = await pageFixture(t, section: 'chat');
  addTearDown(() async {
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
  });
  w.server = RaftRecord({
    'id': 's1',
    'slug': 'demo',
    'name': 'Alpha',
    'role': role,
  });
  final isDm = open.type == 'dm';
  w.channel = open;
  w.channels = isDm ? [] : [open];
  w.dms = isDm ? [open] : [];
  w.navigation.navigate(
    RaftLocation.at(
      serverSlug: w.location.serverSlug,
      route: isDm ? RaftRoute.dm : RaftRoute.channel,
      entityId: open.id,
    ),
  );
  final row = agent ?? _agent();
  api.routes['GET /channels/dm'] = (_) => [_dm.json];
  api.routes['GET /channels'] = (_) => [if (!isDm) open.json];
  api.routes['GET /announcements/active'] = (_) => null;
  api.routes['GET /servers/s1/machines'] = (_) => [];
  api.routes['GET /agents'] = (_) => [row];
  api.routes['GET /agents/a1'] = (_) => row;
  api.routes['GET /servers/s1/members'] = (_) => [];
  api.routes['POST /feature-flags/evaluate'] = (_) => {
    'evaluations': [
      {'key': 'agent_lounge_v0', 'enabled': flag},
    ],
  };
  api.routes['GET /channels/lg1'] = (_) => _loungeRow();
  api.routes['GET /messages/channel/lg1'] = (_) => {'messages': []};
  api.routes['GET /tasks/channel/lg1'] = (_) => {'tasks': []};
  api.routes['GET /channels/lg1/members'] = (_) => {'humans': [], 'agents': []};
  api.routes['POST /channels/lg1/read'] = (_) => {};
  api.routes['POST /channels/dm-bot/read'] = (_) => {};
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme().copyWith(platform: platform),
      builder: (_, child) => RaftToastHost(child: child!),
      home: withAppServices(
        WorkspaceView(
          controller: w,
          appearance: RaftAppearance(),
          onAppearance: (_) async {},
          onLogout: () async {},
        ),
      ),
    ),
  );
  await frames(t, () {});
  await t.pumpAndSettle();
  return _Shell(w, api);
}

final _lounge = RaftChannel(_loungeRow());
final _openLounge = find.byKey(const ValueKey('agent-dm-open-lounge'));

void main() {
  for (final (size, platform) in _configs) {
    final label = '${size.width.toInt()}x${size.height.toInt()} $platform';

    group('Lounge channel $label', () {
      testWidgets(
        'is named after its agent, says who is here and takes a post',
        (t) async {
          await _mount(t, size: size, platform: platform, open: _lounge);
          expect(find.text("Bot's Lounge"), findsWidgets);
          expect(
            find.descendant(
              of: find.byKey(const Key('workspace-channel-header')),
              matching: find.text('bot-lounge'),
            ),
            findsNothing,
          );
          expect(find.byKey(const ValueKey('lounge-avatar-badge')), findsOne);
          expect(
            find.text(
              'Members of this server can take part. Other agents can read it.',
            ),
            findsOneWidget,
          );
          // Nothing to join first: the first post joins you.
          expect(find.byKey(const Key('channel-join-footer')), findsNothing);
          expect(find.byType(RaftComposer), findsOneWidget);
          expect(find.text("Message Bot's Lounge"), findsOneWidget);
          expect(
            find.byKey(const Key('channel-read-only-composer')),
            findsNothing,
          );
        },
      );

      testWidgets(
        'the composer is a disabled stand-in where canPost is false',
        (t) async {
          await _mount(
            t,
            size: size,
            platform: platform,
            open: RaftChannel(_loungeRow(canPost: false)),
          );
          expect(
            find.byKey(const Key('channel-read-only-composer')),
            findsOneWidget,
          );
          expect(find.text('Chat is unavailable'), findsOneWidget);
          expect(find.byType(RaftComposer), findsNothing);
          expect(find.byKey(const Key('channel-join-footer')), findsNothing);
        },
      );

      // Web LoungeUnarchiveAction.tsx / ChatPanel.tsx:2104: the banner of an
      // archived Lounge unarchives in place, for roles that may archive.
      testWidgets(
        'an archived Lounge unarchives in place and the composer returns',
        (t) async {
          final archived = RaftChannel({
            ..._loungeRow(),
            'archivedAt': '2026-01-01T00:00:00Z',
          });
          final shell = await _mount(
            t,
            size: size,
            platform: platform,
            open: archived,
          );
          expect(
            find.textContaining('This channel is archived'),
            findsOneWidget,
          );
          expect(find.byType(RaftComposer), findsNothing);
          shell.api.routes['POST /channels/lg1/unarchive'] = (_) =>
              _loungeRow();
          shell.api.routes['GET /channels/lg1'] = (_) => _loungeRow();
          await t.tap(find.text('Unarchive'));
          await t.pumpAndSettle();
          expect(
            shell.api.calls.where((c) => c.path == '/channels/lg1/unarchive'),
            hasLength(1),
          );
          expect(find.textContaining('This channel is archived'), findsNothing);
          expect(find.byType(RaftComposer), findsOneWidget);
        },
      );

      testWidgets('a role that may not archive gets no Unarchive link', (
        t,
      ) async {
        await _mount(
          t,
          size: size,
          platform: platform,
          role: 'member',
          open: RaftChannel({
            ..._loungeRow(),
            'archivedAt': '2026-01-01T00:00:00Z',
          }),
        );
        expect(find.textContaining('This channel is archived'), findsOneWidget);
        expect(find.text('Unarchive'), findsNothing);
      });

      testWidgets('an ordinary channel has neither the notice nor the mark', (
        t,
      ) async {
        await _mount(
          t,
          size: size,
          platform: platform,
          open: RaftChannel({
            'id': 'c2',
            'name': 'general',
            'type': 'channel',
            'joined': true,
          }),
        );
        expect(
          find.byKey(const ValueKey('lounge-audience-notice')),
          findsNothing,
        );
        expect(find.byKey(const ValueKey('lounge-avatar-badge')), findsNothing);
        expect(find.text('Message #general'), findsOneWidget);
        expect(find.text('Chat is unavailable'), findsNothing);
      });

      testWidgets('a list refresh does not retire the open Lounge', (t) async {
        final shell = await _mount(
          t,
          size: size,
          platform: platform,
          open: _lounge,
        );
        // GET /channels does not list Lounges.
        shell.api.routes['GET /channels'] = (_) => [];
        await t.runAsync(shell.w.refreshChannels);
        await t.pumpAndSettle();
        expect(shell.w.channels.map((c) => c.id), contains('lg1'));
        expect(shell.w.channel?.id, 'lg1');
        expect(find.text("Bot's Lounge"), findsWidgets);
      });
    });

    group('DM Lounge toggle $label', () {
      testWidgets('opens the agent\'s Lounge', (t) async {
        final shell = await _mount(
          t,
          size: size,
          platform: platform,
          open: _dm,
        );
        expect(_openLounge, findsOneWidget);
        shell.api.routes['POST /agents/a1/lounge'] = (_) => {
          'channel': {..._loungeRow(), 'loungeAgentId': null},
          'joined': true,
          'canPost': false,
        };
        await t.tap(_openLounge);
        await t.pumpAndSettle();
        expect(
          shell.api.calls.where((c) => c.path == '/agents/a1/lounge').length,
          1,
        );
        expect(shell.w.channel?.id, 'lg1');
        // The answer's own flags win, and the row names its agent.
        expect(shell.w.channel?.loungeAgentId, 'a1');
        expect(shell.w.channel?.joined, isTrue);
        expect(shell.w.channel?.canPost, isFalse);
        expect(find.text("Bot's Lounge"), findsWidgets);
        expect(find.text('Chat is unavailable'), findsOneWidget);
        // Back in the DM, nothing of the Lounge's chrome is left.
        expect(_openLounge, findsNothing);
      });

      testWidgets('a failed open says so and a retry resolves it', (t) async {
        final shell = await _mount(
          t,
          size: size,
          platform: platform,
          open: _dm,
        );
        await t.tap(_openLounge);
        // pumpAndSettle would run the toast out; look at it while it shows.
        await t.pump(const Duration(milliseconds: 100));
        await t.pump(const Duration(milliseconds: 100));
        expect(find.text("Couldn't open the Lounge. Try again."), findsOne);
        expect(shell.w.channel?.id, 'dm-bot');
        shell.api.routes['POST /agents/a1/lounge'] = (_) => {
          'channel': _loungeRow(),
        };
        await t.pump(const Duration(seconds: 8));
        await t.pumpAndSettle();
        expect(find.text("Couldn't open the Lounge. Try again."), findsNothing);
        await t.tap(_openLounge);
        await t.pumpAndSettle();
        expect(shell.w.channel?.id, 'lg1');
        expect(find.text("Couldn't open the Lounge. Try again."), findsNothing);
      });

      testWidgets('is not offered when it should not be', (t) async {
        for (final (flag, role, agent) in [
          (false, 'owner', _agent()),
          (true, 'guest', _agent()),
          (true, 'owner', _agent(assistantOwnerUserId: 'alice')),
        ]) {
          await _mount(
            t,
            size: size,
            platform: platform,
            open: _dm,
            flag: flag,
            role: role,
            agent: agent,
          );
          expect(_openLounge, findsNothing, reason: '$flag $role');
          await t.pumpWidget(const SizedBox());
        }
      });
    });

    // Web features/channel/AgentDMStatus.tsx:16-20: the DM status line shows
    // the stuck text alone (warning colour) in place of the activity; unlike
    // the profile's notice it has no "Stop current turn" link.
    group('DM tool-stuck line $label', () {
      testWidgets('says which tool the agent is stuck on', (t) async {
        await _mount(
          t,
          size: size,
          platform: platform,
          open: _dm,
          agent: _agent(toolStuck: _stuck()),
        );
        expect(find.textContaining('Stuck on bash'), findsOneWidget);
        expect(find.textContaining('4 min'), findsOneWidget);
        expect(find.textContaining('2 messages waiting'), findsOneWidget);
        expect(find.text('Stop current turn'), findsNothing);
      });

      for (final (why, agent) in [
        ('not stuck', _agent()),
        ('offline', _agent(toolStuck: _stuck(), status: 'offline')),
        (
          'blocked',
          _agent(toolStuck: _stuck(), blockedReason: 'computer_access_revoked'),
        ),
      ]) {
        testWidgets('is not shown when the agent is $why', (t) async {
          await _mount(
            t,
            size: size,
            platform: platform,
            open: _dm,
            agent: agent,
          );
          expect(find.textContaining('Stuck on'), findsNothing);
        });
      }
    });
  }
}
