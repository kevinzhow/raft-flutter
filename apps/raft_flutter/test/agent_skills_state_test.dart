import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/agent_skills_section.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show fixture;
import 'panel_revisit_cache_test.dart' show settle;

const _stale =
    'This Computer did not answer in time, so this skill list may be out of date.';
const _unavailable =
    'Could not load skills from this Computer in time. Try again later.';

const _deploy = {
  'name': 'deploy',
  'displayName': 'Deploy',
  'description': 'Ship it',
  'sourcePath': '~/.claude/skills',
  'userInvocable': true,
};

/// Web `AgentSkills` states ok | stale | unavailable
/// (components/agent/AgentSkills.tsx): a stale list says so and offers Retry, an
/// unavailable one is an error with Retry, a failed read is the catalog text,
/// and the Retry of each resolves the notice.
void main() {
  Finder eyebrow(String label) => find.byWidgetPredicate(
    (w) => w is RaftSectionEyebrow && w.label == label,
  );
  Widget host(Widget child) => MaterialApp(
    theme: raftTheme(),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );

  for (final (label, size, platform) in [
    ('fold 856x944', const Size(856, 944), TargetPlatform.android),
    ('fold 944x856', const Size(944, 856), TargetPlatform.android),
    ('narrow desktop 390x844', const Size(390, 844), TargetPlatform.linux),
  ]) {
    testWidgets(
      'a stale list shows its notice and Retry resolves it ($label)',
      (t) async {
        debugDefaultTargetPlatformOverride = platform;
        final (w, api) = (await t.runAsync(() => fixture('owner')))!;
        addTearDown(w.dispose);
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        var reads = 0;
        api.routes['GET /agents/a1/skills'] = (_) {
          reads++;
          return reads == 1
              ? {
                  'global': [_deploy],
                  'workspace': [],
                  'state': 'stale',
                  'fetchedAt': 1,
                }
              : {
                  'global': [_deploy],
                  'workspace': [],
                  'state': 'ok',
                };
        };
        await t.pumpWidget(
          host(AgentSkillsSection(controller: w, agentId: 'a1')),
        );
        await settle(t);
        // Not shown while the Computer answered in time: nothing yet to retry.
        expect(find.text(_stale), findsOneWidget);
        expect(eyebrow('Skills'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('agent-skills-stale-retry')),
          findsOne,
        );

        await t.tap(find.byKey(const ValueKey('agent-skills-stale-retry')));
        await settle(t);
        expect(reads, 2);
        expect(find.text(_stale), findsNothing);
        expect(
          find.byKey(const ValueKey('agent-skills-stale-retry')),
          findsNothing,
        );

        // Reopened: the answered list is remembered, so no notice at the first
        // frame and none after the silent refresh.
        await t.pumpWidget(const SizedBox());
        await t.pumpWidget(
          host(AgentSkillsSection(controller: w, agentId: 'a1')),
        );
        expect(find.text(_stale), findsNothing);
        await settle(t);
        expect(find.text(_stale), findsNothing);
        debugDefaultTargetPlatformOverride = null;
      },
    );
  }

  testWidgets('a fresh list shows no notice', (t) async {
    final (w, api) = (await t.runAsync(() => fixture('owner')))!;
    addTearDown(w.dispose);
    api.routes['GET /agents/a1/skills'] = (_) => {
      'global': [_deploy],
      'workspace': [],
    };
    await t.pumpWidget(host(AgentSkillsSection(controller: w, agentId: 'a1')));
    await settle(t);
    expect(eyebrow('Skills'), findsOneWidget);
    expect(find.text(_stale), findsNothing);
    expect(find.text(_unavailable), findsNothing);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('an unavailable list is an error with Retry that resolves it', (
    t,
  ) async {
    final (w, api) = (await t.runAsync(() => fixture('owner')))!;
    addTearDown(w.dispose);
    var reads = 0;
    api.routes['GET /agents/a1/skills'] = (_) {
      reads++;
      return reads == 1
          ? {'global': [], 'workspace': [], 'state': 'unavailable'}
          : {
              'global': [_deploy],
              'workspace': [],
              'state': 'ok',
            };
    };
    await t.pumpWidget(host(AgentSkillsSection(controller: w, agentId: 'a1')));
    await settle(t);
    expect(find.text(_unavailable), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    // The empty header is not drawn under the error (Web returns the error alone).
    expect(eyebrow('Skills'), findsNothing);

    await t.tap(find.text('Retry'));
    await settle(t);
    expect(reads, 2);
    expect(find.text(_unavailable), findsNothing);
    expect(eyebrow('Skills'), findsOneWidget);
  });

  testWidgets('a failed read says so in catalog text, never the server text', (
    t,
  ) async {
    final (w, api) = (await t.runAsync(() => fixture('owner')))!;
    addTearDown(w.dispose);
    // No route: the adapter answers 404 {"error": "Unexpected endpoint"}.
    await t.pumpWidget(host(AgentSkillsSection(controller: w, agentId: 'a1')));
    await settle(t);
    expect(find.text('Failed to load skills'), findsOneWidget);
    expect(find.text('Unexpected endpoint'), findsNothing);

    api.routes['GET /agents/a1/skills'] = (_) => {
      'global': [_deploy],
      'workspace': [],
    };
    await t.tap(find.text('Retry'));
    await settle(t);
    expect(find.text('Failed to load skills'), findsNothing);
    expect(eyebrow('Skills'), findsOneWidget);
  });

  testWidgets('a background refresh that fails keeps the list on screen', (
    t,
  ) async {
    final (w, api) = (await t.runAsync(() => fixture('owner')))!;
    addTearDown(w.dispose);
    api.routes['GET /agents/a1/skills'] = (_) => {
      'global': [_deploy],
      'workspace': [],
    };
    await t.pumpWidget(host(AgentSkillsSection(controller: w, agentId: 'a1')));
    await settle(t);
    api.routes.remove('GET /agents/a1/skills');
    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(host(AgentSkillsSection(controller: w, agentId: 'a1')));
    await settle(t);
    expect(eyebrow('Skills'), findsOneWidget);
    expect(find.text('Failed to load skills'), findsNothing);
  });
}
