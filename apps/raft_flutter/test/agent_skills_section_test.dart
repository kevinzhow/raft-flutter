import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/agent_detail_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show fixture;
import 'panel_revisit_cache_test.dart' show settle;

/// Web AgentDetailPanel renders `<AgentSkills embedded />` in the profile
/// exactly when `canViewPrivateAgentSurfaces` (desktop and mobile alike).
void main() {
  Finder eyebrow(String label) => find.byWidgetPredicate(
    (w) => w is RaftSectionEyebrow && w.label == label,
  );
  final agent = {
    'id': 'a1',
    'name': 'bot',
    'displayName': 'Bot',
    'status': 'active',
    'runtime': 'claude',
    'model': 'sonnet',
  };

  for (final (label, size) in [
    ('desktop', const Size(1280, 900)),
    ('mobile', const Size(390, 844)),
  ]) {
    testWidgets(
      'Agent profile Skills section follows private access ($label)',
      (t) async {
        final (w, api) = (await t.runAsync(() => fixture('owner')))!;
        addTearDown(w.dispose);
        api.routes['GET /agents/a1/skills'] = (_) => {
          'global': [
            {
              'name': 'deploy',
              'displayName': 'Deploy',
              'description': 'Ship it',
              'sourcePath': '~/.claude/skills',
              'userInvocable': true,
            },
          ],
          'workspace': [],
        };
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        Widget panel(bool private) => MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: AgentDetailPanel(
              key: const Key('agent'),
              controller: w,
              agent: agent,
              machines: const [],
              actions: const AgentDetailActions(),
              canViewPrivate: private,
            ),
          ),
        );
        await t.pumpWidget(panel(true));
        await settle(t);
        await t.pumpAndSettle();
        // Collapsed by default: the header (label + count) is the whole
        // section, so the profile below it stays reachable.
        await t.scrollUntilVisible(
          find.byKey(const ValueKey('agent-skills-disclosure')),
          300,
          scrollable: find.byType(Scrollable).last,
        );
        expect(eyebrow('Skills'), findsOneWidget);
        expect(find.text('Deploy'), findsNothing);
        expect(eyebrow('Global'), findsNothing);
        expect(
          api.calls.where((r) => r.path == '/agents/a1/skills'),
          hasLength(1),
        );

        await t.tap(find.byKey(const ValueKey('agent-skills-disclosure')));
        await t.pumpAndSettle();
        await t.scrollUntilVisible(
          find.text('Deploy'),
          300,
          scrollable: find.byType(Scrollable).last,
        );
        expect(find.text('Deploy'), findsOneWidget);
        expect(find.text('/deploy'), findsOneWidget);
        expect(find.text('Ship it'), findsOneWidget);

        // Closing it again puts the section back to its one header row.
        await t.tap(find.byKey(const ValueKey('agent-skills-disclosure')));
        await t.pumpAndSettle();
        expect(find.text('Deploy'), findsNothing);

        await t.pumpWidget(panel(false));
        await settle(t);
        await t.pumpAndSettle();
        expect(find.byType(AgentSkillsSection), findsNothing);
        expect(find.text('Deploy'), findsNothing);
        expect(eyebrow('Skills'), findsNothing);
      },
    );
  }
}
