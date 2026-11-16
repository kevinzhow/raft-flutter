import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/workspace_entity_directory.dart';
import 'package:raft_flutter/features/agent_detail_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/agent_panel_fixture.dart';

/// Web v1.24 AgentChatTab (features/agent/AgentChatTab.tsx): no line under the
/// Channels / Agent DMs headings, no description under the combined empty
/// state, a kind-aware channel icon and the DM peer's live avatar.
void main() {
  Map<String, Object? Function()> routes({
    List<Map<String, dynamic>> channels = const [],
    List<Map<String, dynamic>> dms = const [],
    List<Map<String, dynamic>> agents = const [],
  }) => {
    '/agents/a/channels': () => {'channels': channels},
    '/agents/a/agent-dms': () => {'dms': dms},
    '/agents': () => agents,
  };

  Finder glyph(RaftGlyph g) =>
      find.byWidgetPredicate((w) => w is RaftIcon && w.glyph == g);

  for (final (label, size, platform) in [
    ('fold 856x944', const Size(856, 944), TargetPlatform.android),
    ('fold 944x856', const Size(944, 856), TargetPlatform.android),
    ('narrow desktop 390x844', const Size(390, 844), TargetPlatform.linux),
  ]) {
    testWidgets('the headings carry no description line ($label)', (
      tester,
    ) async {
      await pumpAgentPanel(
        tester,
        tab: AgentDetailTab.chat,
        size: size,
        platform: platform,
        routes: routes(
          channels: [
            {'id': 'c1', 'name': 'general', 'type': 'channel'},
          ],
          dms: [
            {
              'id': 'd1',
              'peerId': 'p1',
              'peerName': 'scout',
              'peerDisplayName': 'Scout',
              'createdAt': '2026-10-20T08:00:00.000Z',
            },
          ],
        ),
      );
      expect(find.text('Channels'), findsOneWidget);
      expect(find.text('Agent DMs'), findsOneWidget);
      expect(
        find.text('Channels where this agent can read or participate.'),
        findsNothing,
      );
      expect(
        find.text('Direct conversations involving this agent.'),
        findsNothing,
      );
    });
  }

  testWidgets('the combined empty state is the title alone', (tester) async {
    await pumpAgentPanel(tester, tab: AgentDetailTab.chat, routes: routes());
    expect(find.text('No chats yet'), findsOneWidget);
    expect(find.textContaining('When this agent joins channels'), findsNothing);
  });

  testWidgets('one empty list keeps its own inline empty description', (
    tester,
  ) async {
    await pumpAgentPanel(
      tester,
      tab: AgentDetailTab.chat,
      routes: routes(
        channels: [
          {'id': 'c1', 'name': 'general', 'type': 'channel'},
        ],
      ),
    );
    expect(find.text('No agent-to-agent DMs yet'), findsOneWidget);
    expect(
      find.text('Recent agent-to-agent DM activity will appear here.'),
      findsOneWidget,
    );
  });

  testWidgets('a channel row draws its kind: # lock and branch', (
    tester,
  ) async {
    await pumpAgentPanel(
      tester,
      tab: AgentDetailTab.chat,
      routes: routes(
        channels: [
          {'id': 'c1', 'name': 'open', 'type': 'channel'},
          {'id': 'c2', 'name': 'closed', 'type': 'private'},
          {'id': 'c3', 'name': 'shared', 'type': 'joint'},
        ],
      ),
    );
    expect(glyph(RaftGlyph.lock), findsOneWidget);
    expect(glyph(RaftGlyph.gitBranch), findsOneWidget);
    // The joint channel keeps its badge.
    expect(find.text('Joint'), findsOneWidget);
  });

  testWidgets('the DM peer avatar follows the live agent directory', (
    tester,
  ) async {
    final (w, _) = await pumpAgentPanel(
      tester,
      tab: AgentDetailTab.chat,
      routes: routes(
        dms: [
          {
            'id': 'd1',
            'peerId': 'p1',
            'peerName': 'scout',
            'peerDisplayName': 'Scout',
            'peerAvatarUrl': 'pixel:owl',
            'createdAt': '2026-10-20T08:00:00.000Z',
          },
        ],
        agents: [
          {'id': 'p1', 'name': 'scout', 'avatarUrl': 'pixel:fox'},
        ],
      ),
    );
    Finder avatar(String key) => find.byWidgetPredicate(
      (w) => w is RaftAvatarContent && w.pixelKey == key,
    );
    // Before the directory knows the peer: the listed snapshot.
    expect(avatar('owl'), findsOneWidget);
    await tester.runAsync(() async {
      w.services.entityDirectory.ensure([WorkspaceEntityKind.agents]);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    // Once it does, its avatar wins, not the copy from when the tab loaded.
    expect(avatar('fox'), findsOneWidget);
    expect(avatar('owl'), findsNothing);
  });
}
