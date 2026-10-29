import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/agent_detail_view.dart';

import 'support/agent_panel_fixture.dart';

void main() {
  group('Info rows navigate', () {
    testWidgets('the Computer name opens that Computer', (tester) async {
      String? opened;
      await pumpAgentPanel(
        tester,
        actions: AgentDetailActions(onOpenComputer: (id) => opened = id),
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('agent-computer-link')),
      );
      await tester.tap(find.byKey(const ValueKey('agent-computer-link')));
      await tester.pump();
      expect(opened, 'm1');
    });

    testWidgets('without a way to open it the Computer is plain text', (
      tester,
    ) async {
      await pumpAgentPanel(tester);
      expect(find.text('Studio Mac'), findsOneWidget);
      expect(find.byKey(const ValueKey('agent-computer-link')), findsNothing);
    });

    testWidgets('the creator opens their profile, human or agent', (
      tester,
    ) async {
      final opened = <(String, String)>[];
      await pumpAgentPanel(
        tester,
        actions: AgentDetailActions(
          onOpenCreator: (type, id) => opened.add((type, id)),
        ),
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('agent-creator-link')),
      );
      await tester.tap(find.byKey(const ValueKey('agent-creator-link')));
      await tester.pump();
      expect(opened, [('human', 'alice')]);
    });

    testWidgets('an agent creator opens an agent profile', (tester) async {
      final opened = <(String, String)>[];
      await pumpAgentPanel(
        tester,
        agent: {
          ...agentPanelAgent,
          'creator': {
            'id': 'bot',
            'type': 'agent',
            'name': 'parent',
            'displayName': 'Parent',
            'avatarUrl': null,
          },
        },
        actions: AgentDetailActions(
          onOpenCreator: (type, id) => opened.add((type, id)),
        ),
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('agent-creator-link')),
      );
      await tester.tap(find.byKey(const ValueKey('agent-creator-link')));
      expect(opened, [('agent', 'bot')]);
    });
  });

  group('large avatar', () {
    testWidgets('someone who cannot edit can enlarge an uploaded avatar', (
      tester,
    ) async {
      await pumpAgentPanel(
        tester,
        agent: {
          ...agentPanelAgent,
          'avatarUrl': 'https://fixture.invalid/uploads/avatar.png',
        },
        canManage: false,
        canViewPrivate: false,
      );
      expect(
        find.byKey(const ValueKey('agent-profile-avatar-trigger')),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('View avatar'), findsWidgets);
    });

    testWidgets('pixel artwork and archived agents have no viewer', (
      tester,
    ) async {
      await pumpAgentPanel(tester, canManage: false, canViewPrivate: false);
      expect(
        find.byKey(const ValueKey('agent-profile-avatar-trigger')),
        findsNothing,
      );
    });

    testWidgets('an archived agent keeps a static avatar', (tester) async {
      await pumpAgentPanel(
        tester,
        agent: {
          ...agentPanelAgent,
          'avatarUrl': 'https://fixture.invalid/uploads/avatar.png',
          'deletedAt': '2026-10-24T01:00:00.000Z',
        },
        canManage: false,
        canViewPrivate: false,
      );
      expect(
        find.byKey(const ValueKey('agent-profile-avatar-trigger')),
        findsNothing,
      );
    });

    testWidgets('a manager still changes the avatar', (tester) async {
      var changed = 0;
      await pumpAgentPanel(
        tester,
        agent: {
          ...agentPanelAgent,
          'avatarUrl': 'https://fixture.invalid/uploads/avatar.png',
        },
        actions: AgentDetailActions(onEditAvatar: () => changed++),
      );
      await tester.tap(
        find.byKey(const ValueKey('agent-profile-avatar-trigger')),
      );
      expect(changed, 1);
    });
  });

  testWidgets('an agent profile has no Created Agents section', (tester) async {
    await pumpAgentPanel(
      tester,
      agent: {
        ...agentPanelAgent,
        'createdAgents': [
          {
            'id': 'k1',
            'name': 'kid',
            'displayName': 'Kid',
            'runtime': 'claude',
            'status': 'active',
          },
        ],
      },
    );
    expect(find.textContaining('CREATED AGENTS'), findsNothing);
    expect(find.text('Kid'), findsNothing);
  });

  group('Runtime config rows (Claude)', () {
    Map<String, dynamic> claude(Map<String, dynamic> config) => {
      ...agentPanelAgent,
      'runtime': 'claude',
      'model': 'opus',
      'runtimeConfig': {
        'version': 1,
        'runtime': 'claude',
        'model': 'opus',
        ...config,
      },
    };

    testWidgets('show the custom provider URL and the command', (tester) async {
      await pumpAgentPanel(
        tester,
        agent: claude({
          'provider': {
            'kind': 'custom',
            'apiUrl': 'https://llm.example.com/v1',
            'apiKey': 'sk-x',
          },
          'command': '  /opt/claude/bin/claude  ',
        }),
      );
      expect(find.text('https://llm.example.com/v1'), findsOneWidget);
      expect(find.text('/opt/claude/bin/claude'), findsOneWidget);
    });

    testWidgets('read Default without them', (tester) async {
      await pumpAgentPanel(tester, agent: claude({}));
      for (final key in ['provider', 'command']) {
        expect(
          find.descendant(
            of: find.byKey(ValueKey('agent-runtime-$key')),
            matching: find.text('Default'),
          ),
          findsOneWidget,
          reason: key,
        );
      }
    });

    testWidgets('are not shown for another runtime', (tester) async {
      await pumpAgentPanel(tester);
      expect(
        find.byKey(const ValueKey('agent-runtime-provider')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('agent-runtime-command')), findsNothing);
    });
  });
}
