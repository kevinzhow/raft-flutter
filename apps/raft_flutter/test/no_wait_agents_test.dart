import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/data/workspace_entity_directory.dart';
import 'package:raft_flutter/features/agent_apps_view.dart';
import 'package:raft_flutter/features/agent_detail_view.dart';
import 'package:raft_flutter/features/external_agent_setup.dart';
import 'package:raft_flutter/features/fleet_views.dart';
import 'package:raft_flutter/features/member_graph_view.dart';
import 'package:raft_flutter/features/member_profile_view.dart';
import 'package:raft_flutter/features/server_views.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show MessageAdapter;
import 'support/close_support.dart';
import 'support/no_wait_support.dart';
import 'flutter_test_config.dart' show leakDebt;

/// No-wait UI, group "agents, computers, profiles": every surface opens (and
/// shows its final content) from what is already local while the network
/// never answers.

Future<void> push(BuildContext context, Widget page) =>
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => Scaffold(body: page)));

const machine = {
  'id': 'm1',
  'name': 'Studio Mac',
  'status': 'online',
  'isComputer': true,
  'userId': 'alice',
  'os': 'darwin',
  'createdAt': '2026-06-18T09:00:00.000Z',
};

const externalAgent = {
  'id': 'ext1',
  'name': 'bridge',
  'displayName': 'Hermes Bridge',
  'status': 'active',
  'runtime': 'external',
  'model': 'external',
  'external': true,
  'creatorType': 'user',
  'creatorId': 'alice',
};

Future<(WorkspaceController, MessageAdapter)> mount(WidgetTester t) async {
  final (w, api) = await mountWorkspace(t, const Size(1280, 800));
  api.routes['GET /servers/s1/machines'] = (_) => {
    'machines': [machine],
  };
  api.routes['GET /agents'] = (_) => [
    {
      'id': 'a1',
      'name': 'cindy',
      'displayName': 'Cindy',
      'status': 'active',
      // The REST row carries the derived activity (a status-only row reads as
      // online, as in Web resolveAgentDisplayState): offline offers Start.
      'activity': 'offline',
      'runtime': 'claude',
      'model': 'sonnet',
      'machineId': 'm1',
      'creatorType': 'user',
      'creatorId': 'alice',
    },
    externalAgent,
  ];
  await t.runAsync(() async {
    for (final kind in [
      WorkspaceEntityKind.agents,
      WorkspaceEntityKind.computers,
    ]) {
      await w.entityDirectory.refresh(kind, force: true);
    }
  });
  expect(w.entityDirectory.state(WorkspaceEntityKind.computers).loaded, true);
  return (w, api);
}

void main() {
  // Leak debt (dialog notifier): see docs/development.md, Leak tracking.
  leakDebt(const [
    'ValueNotifier<(Object?)?>',
    'ValueNotifier<Map<String, dynamic>>',
    'ValueNotifier<Object?>',
    'ValueNotifier<String?>',
  ]);
  testWidgets('agent detail opened with an id-only row renders the directory '
      'agent at the first frame', (t) async {
    final (w, api) = await mount(t);
    await expectOpensWithoutNetwork(
      t,
      w,
      api,
      surface: find.byType(AgentDetailPanel),
      open: (c) => push(
        c,
        FleetDetail(controller: w, computers: false, initial: {'id': 'a1'}),
      ),
    );
    expect(find.text('Cindy'), findsWidgets);
    expect(find.byType(SourceProfileLoadingPanel), findsNothing);
  });

  testWidgets('computer detail opened with an id-only row renders the '
      'directory computer at the first frame', (t) async {
    final (w, api) = await mount(t);
    await expectOpensWithoutNetwork(
      t,
      w,
      api,
      surface: find.text('Studio Mac'),
      open: (c) => push(
        c,
        FleetDetail(controller: w, computers: true, initial: {'id': 'm1'}),
      ),
    );
    expect(find.byType(SourceProfileLoadingPanel), findsNothing);
    // The agents that run on it come from the same directory.
    expect(find.text('Cindy'), findsWidgets);
  });

  testWidgets('the agents and computers lists show their rows at once', (
    t,
  ) async {
    final (w, api) = await mount(t);
    for (final (computers, text) in [(false, 'Cindy'), (true, 'Studio Mac')]) {
      await expectOpensWithoutNetwork(
        t,
        w,
        api,
        surface: find.text(text),
        open: (c) => push(c, FleetView(controller: w, computers: computers)),
      );
      expect(find.byType(RaftSpinner), findsNothing);
      await systemBack(t);
    }
  });

  testWidgets('start confirmation opens from the row on screen and reads '
      'only when confirmed', (t) async {
    final (w, api) = await mount(t);
    await expectOpensWithoutNetwork(
      t,
      w,
      api,
      surface: find.byType(AgentDetailPanel),
      open: (c) => push(
        c,
        FleetDetail(controller: w, computers: false, initial: {'id': 'a1'}),
      ),
    );
    api.hangAll = true;
    final start = find.byKey(const Key('agent-profile-inline-start-stop'));
    expect(start, findsWidgets);
    await t.tap(start.first);
    await frames(t, 6);
    expect(find.byType(RaftFormDialog), findsOneWidget);
    expect(find.text('Start Agent'), findsWidgets);
    api.hangAll = false;
  });

  testWidgets('the members page lists the directory members at once and its '
      'profile dialog opens without waiting for the profile read', (t) async {
    final (w, api) = await mount(t);
    await expectOpensWithoutNetwork(
      t,
      w,
      api,
      surface: find.text('Bob'),
      open: (c) => push(c, MembersView(controller: w)),
    );
    expect(find.byType(RaftSpinner), findsNothing);
    api.hangAll = true;
    await t.tap(
      find
          .descendant(of: find.byType(MembersView), matching: find.text('Bob'))
          .first,
    );
    await frames(t, 6);
    expect(
      find.byWidgetPredicate((w) => w is AlertDialog || w is RaftAlertDialog),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byWidgetPredicate(
          (w) => w is AlertDialog || w is RaftAlertDialog,
        ),
        matching: find.text('Bob'),
      ),
      findsOneWidget,
    );
    api.hangAll = false;
  });

  testWidgets('a member profile shows the directory member at once without '
      'empty detail sections', (t) async {
    final (w, api) = await mount(t);
    await expectOpensWithoutNetwork(
      t,
      w,
      api,
      surface: find.text('Bob'),
      open: (c) => push(
        c,
        MemberProfileView(
          controller: w,
          userId: 'bob',
          onClose: () {},
          onBack: () {},
        ),
      ),
    );
    expect(find.text('Created Agents'), findsNothing);
    expect(find.text('No created agents'), findsNothing);
  });

  testWidgets('revisits show the last accepted data with a dead network', (
    t,
  ) async {
    final (w, api) = await mount(t);
    api.routes['GET /servers/s1/member-graph'] = (_) => {
      'humans': [
        {
          'type': 'human',
          'id': 'h1',
          'name': 'ann',
          'displayName': 'Annabel',
          'avatarUrl': null,
          'gravatarHash': '',
          'role': 'member',
          'channelIds': ['g1'],
        },
      ],
      'agents': [],
      'channels': [
        {
          'id': 'g1',
          'name': 'design',
          'type': 'channel',
          'archivedAt': null,
          'humanCount': 1,
          'agentCount': 0,
          'memberCount': 1,
        },
      ],
      'edges': [],
    };
    api.routes['GET /agents/ext1/credentials'] = (_) => {
      'agentId': 'ext1',
      'credentials': [
        {
          'id': 'cred-1234abcd',
          'maskedToken': 'sk_agent_ab12***9f3e',
          'name': null,
          'createdAt': '2026-06-18T09:00:00.000Z',
          'revokedAt': null,
        },
      ],
    };
    api.routes['GET /agents/ext1/external-status'] = (_) => {
      'setupState': 'credential_minted',
      'credentialLastUsedAt': null,
    };
    api.routes['GET /agents/ext1'] = (_) => externalAgent;
    final context = t.element(find.byType(WorkspaceView));
    final pages = <(String, Widget, Finder)>[
      ('member graph', MemberGraphPage(controller: w), find.text('Annabel')),
      (
        'external agent setup',
        SingleChildScrollView(
          child: ExternalAgentSetup(controller: w, agent: externalAgent),
        ),
        find.textContaining('sk_agent_ab12'),
      ),
    ];
    for (final (name, page, shown) in pages) {
      // First visit, network alive.
      unawaited(push(context, page));
      await frames(t, 12);
      expect(shown, findsWidgets, reason: '$name first visit');
      await systemBack(t);
      expect(shown, findsNothing);
      // Second visit, network dead.
      await expectOpensWithoutNetwork(
        t,
        w,
        api,
        surface: shown,
        open: (c) => push(c, page),
      );
      await systemBack(t);
    }
  });

  testWidgets('an agent workspace file preview and a fleet inspection file '
      'dialog open before their read lands', (t) async {
    final (w, api) = await mount(t);
    api.routes['GET /agents/a1/workspace-files'] = (_) => {
      'files': [
        {'name': 'notes.md', 'path': 'notes.md', 'isDirectory': false},
      ],
    };
    api.routes['GET /agents/a1/workspace-files/read'] = (_) => {
      'content': 'hello notes',
    };
    api.routes['GET /agents/a1/activity-log'] = (_) => [];
    unawaited(
      push(
        t.element(find.byType(WorkspaceView)),
        AgentWorkspaceTab(controller: w, agentId: 'a1'),
      ),
    );
    await frames(t, 12);
    expect(find.text('notes.md'), findsOneWidget);
    api.hangAll = true;
    await t.tap(find.text('notes.md'));
    await frames(t, 6);
    // The file is selected at once (wide layout: embedded preview).
    expect(find.byType(RaftWorkspaceFilePreview), findsOneWidget);
    api.hangAll = false;
    await systemBack(t);

    // The fleet inspection lists the same folder; its file dialog opens at
    // once too.
    unawaited(
      push(
        t.element(find.byType(WorkspaceView)),
        FleetInspection(
          controller: w,
          base: '/agents/a1',
          kind: 'workspace-files',
          computers: false,
        ),
      ),
    );
    await frames(t, 12);
    expect(find.text('notes.md'), findsOneWidget);
    api.hangAll = true;
    await t.tap(find.text('notes.md'));
    await frames(t, 6);
    expect(
      find.byWidgetPredicate((w) => w is AlertDialog || w is RaftAlertDialog),
      findsOneWidget,
    );
    api.hangAll = false;
  });

  testWidgets('the app event row opens before the payload read '
      'lands', (t) async {
    final (w, api) = await mount(t);
    api.routes['GET /integrations/agents/a1'] = (_) => [];
    api.routes['GET /integrations/agents/a1/grantable-apps'] = (_) => {
      'apps': [],
    };
    api.routes['GET /integrations/agents/a1/events'] = (_) => {
      'events': [
        {'id': 'e1', 'summary': 'Build finished'},
      ],
    };
    api.routes['GET /integrations/agents/a1/events/e1'] = (_) => {
      'payload': {'ok': true},
    };
    unawaited(
      push(
        t.element(find.byType(WorkspaceView)),
        AgentAppAccessView(controller: w, agentId: 'a1'),
      ),
    );
    await frames(t, 12);
    final event = find.text('Build finished');
    expect(event, findsWidgets);
    api.hangAll = true;
    await t.tap(event.first);
    await frames(t, 6);
    expect(
      find.byWidgetPredicate((w) => w is AlertDialog || w is RaftAlertDialog),
      findsNothing,
    );
    expect(find.text('Refreshing…'), findsOneWidget);
    api.hangAll = false;
  });
}
