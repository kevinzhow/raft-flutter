import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/personal_presentation.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_presentation_test.dart' show MessageAdapter;
import 'support/app_services_fixture.dart';
import 'workspace_source_location_contract_test.dart' show LocalClient, frames;

// Working agents are shown where they appear (Raft Design System decision
// 0006), in the real WorkspaceView: the summary on phone Home and the desktop
// global row, Working now, the agent's row, the channel header's subtitle,
// and no live bar.
class _EventClient extends LocalClient {
  _EventClient(super.adapter);
  final stream = StreamController<RaftEvent>.broadcast(sync: true);
  @override
  Stream<RaftEvent> get events => stream.stream;
}

Future<(WorkspaceController, _EventClient)> _fixture(WidgetTester t) async {
  SharedPreferences.setMockInitialValues({});
  final api = MessageAdapter();
  api.routes['POST /auth/login'] = (_) => {
    'accessToken': 'fixture-only',
    'refreshToken': 'fixture-only',
    'user': {'id': 'alice'},
  };
  final client = (await t.runAsync(() async {
    final client = _EventClient(api);
    await client.login('fixture', 'fixture');
    client.selectServer('s1');
    return client;
  }))!;
  addTearDown(client.stream.close);
  final w = WorkspaceController(client);
  addTearDown(w.dispose);
  w.channel = RaftChannel({
    'id': 'c1',
    'name': 'launch-week',
    'description': 'Ship the launch week',
    'joined': true,
  });
  w.channels = [w.channel!];
  w.dms = [
    RaftChannel({
      'id': 'dm-bugen',
      'type': 'dm',
      'joined': true,
      'peerType': 'agent',
      'peerId': 'bugen',
      'peerName': 'Bugen',
    }),
  ];
  w.loading = false;
  w.messageDomain.ledger.switchServer('s1');
  w.server = RaftRecord({
    'id': 's1',
    'slug': 'demo',
    'name': 'Launch Crew',
    'role': 'owner',
  });
  w.section = 'home';
  api.routes['GET /agents'] = (_) => [
    {
      'id': 'bugen',
      'name': 'Bugen',
      'avatarUrl': 'pixel:cat',
      'runtime': 'codex',
    },
    {
      'id': 'wug',
      'name': 'Wug',
      'avatarUrl': 'pixel:robot',
      'runtime': 'codex',
    },
    {'id': 'outsider', 'name': 'Outsider', 'avatarUrl': 'pixel:cat'},
  ];
  api.routes['GET /servers/s1/members'] = (_) => [];
  api.routes['GET /channels/c1/members'] = (_) => {
    'humans': [],
    'agents': [
      {'id': 'bugen'},
      {'id': 'wug'},
    ],
  };
  api.routes['GET /channels/inbox'] = (_) => {'items': []};
  api.routes['GET /channels/threads/followed'] = (_) => {'threads': []};
  api.routes['POST /feature-flags/evaluate'] = (_) => {'evaluations': []};
  api.routes['GET /servers/s1/setup-projection'] = (_) => {
    'phase': 'complete',
    'surface': 'complete',
    'blocksChat': false,
  };
  api.routes['POST /channels/c1/read'] = (_) => {};
  return (w, client);
}

Future<PersonalPresentationStore> _mount(
  WidgetTester t,
  WorkspaceController w, {
  required double width,
}) async {
  t.view.physicalSize = Size(width, 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final presentation = PersonalPresentationStore(desktop: false);
  addTearDown(presentation.dispose);
  await t.runAsync(() => presentation.bind(w.client.origin, w.client.user!.id));
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(),
      home: withAppServices(
        WorkspaceView(
          controller: w,
          appearance: RaftAppearance(),
          onAppearance: (_) async {},
          onLogout: () async {},
          presentation: presentation,
        ),
      ),
    ),
  );
  await frames(t, () {});
  await t.pumpAndSettle();
  return presentation;
}

void _work(
  _EventClient client,
  String id, {
  String activity = 'working',
  String? detail,
}) => client.stream.add(
  RaftEvent('agent:activity', {
    'agentId': id,
    'serverId': 's1',
    'activity': activity,
    'detail': ?detail,
  }),
);

const _liveBar = Key('live-agent-activity-bar');

void main() {
  testWidgets('phone Home: summary, Working now, row text, no bar', (t) async {
    final (w, client) = await _fixture(t);
    await _mount(t, w, width: 390);
    expect(find.byKey(const Key('working-agents-summary')), findsNothing);
    expect(find.text('Working now'), findsNothing);

    _work(client, 'bugen', detail: 'Editing Flow.tsx · #25');
    _work(client, 'wug', detail: 'Drafting release notes · #31');
    await t.pump();

    // The summary sits in the Home bar before the bell.
    final summary = find.byKey(const Key('working-agents-summary'));
    expect(summary, findsOneWidget);
    expect(find.bySemanticsLabel('2 agents working'), findsOneWidget);
    expect(
      t.getRect(summary).right,
      // Expanded touch targets may meet; they must never overlap.
      lessThanOrEqualTo(
        t.getRect(find.byKey(const Key('mobile-home-notifications'))).left,
      ),
    );
    expect(
      t.getRect(summary).top,
      lessThan(
        t.getRect(find.byKey(const Key('mobile-server-selector'))).bottom,
      ),
    );

    // The agent's row says what it is doing, in place of its runtime.
    final row = find.byKey(const ValueKey('sidebar-channel-dm-bugen'));
    expect(
      find.descendant(of: row, matching: find.text('Editing Flow.tsx · #25')),
      findsOneWidget,
    );

    // Working now: one row per agent, what it is doing on up to 2 lines.
    await t.tap(summary);
    await t.pumpAndSettle();
    expect(find.text('Working now'), findsOneWidget);
    for (final text in [
      'Editing Flow.tsx · #25',
      'Drafting release notes · #31',
    ]) {
      expect(
        find.descendant(
          of: find.byKey(const Key('working-now')),
          matching: find.text(text),
        ),
        findsOneWidget,
      );
    }
    await t.tap(find.byKey(const ValueKey('working-now-row-wug')));
    await t.pumpAndSettle();
    expect(find.text('Working now'), findsNothing);

    // Nothing is attached above the tab bar.
    expect(find.byKey(_liveBar), findsNothing);
    expect(find.byKey(const Key('live-agent-activity-text')), findsNothing);
    expect(find.byKey(const Key('workspace-mobile-home')), findsOneWidget);
  });

  testWidgets('an agent that stops leaves the summary and its row at once', (
    t,
  ) async {
    final (w, client) = await _fixture(t);
    await _mount(t, w, width: 390);
    _work(client, 'bugen', detail: 'Editing');
    _work(client, 'wug', detail: 'Reading');
    await t.pump();
    expect(find.bySemanticsLabel('2 agents working'), findsOneWidget);
    _work(client, 'wug', activity: 'error');
    await t.pump();
    expect(find.bySemanticsLabel('1 agent working'), findsOneWidget);
    _work(client, 'bugen', activity: 'offline');
    await t.pump();
    expect(find.byKey(const Key('working-agents-summary')), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('sidebar-channel-dm-bugen')),
        matching: find.byKey(const Key('nav-item-activity')),
      ),
      findsNothing,
    );
  });

  testWidgets(
    'the Appearance preference hides the summary and the channel line, not the rows',
    (t) async {
      final (w, client) = await _fixture(t);
      final presentation = await _mount(t, w, width: 390);
      _work(client, 'bugen', detail: 'Editing Flow.tsx · #25');
      await t.pump();
      expect(find.byKey(const Key('working-agents-summary')), findsOneWidget);
      presentation.update(presentation.key, liveActivity: false);
      await t.pump();
      expect(find.byKey(const Key('working-agents-summary')), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('sidebar-channel-dm-bugen')),
          matching: find.text('Editing Flow.tsx · #25'),
        ),
        findsOneWidget,
        reason: 'the row is the agent\'s state, not a feed',
      );
      presentation.update(presentation.key, liveActivity: true);
      await t.pump();
      expect(find.byKey(const Key('working-agents-summary')), findsOneWidget);
    },
  );

  testWidgets(
    'channel header subtitle counts only members, then " · " and the description',
    (t) async {
      final (w, client) = await _fixture(t);
      w.section = 'chat';
      await _mount(t, w, width: 1280);
      // The roster is read when the channel opens; nobody is working yet.
      expect(find.byKey(const Key('channel-working-line')), findsNothing);
      expect(find.text('Ship the launch week'), findsOneWidget);

      _work(client, 'outsider', detail: 'Elsewhere');
      await t.pump();
      expect(
        find.byKey(const Key('channel-working-line')),
        findsNothing,
        reason: 'not a member of this channel',
      );

      _work(client, 'bugen', detail: 'Editing Flow.tsx · #25');
      await t.pump();
      final header = find.byKey(const Key('workspace-channel-header'));
      expect(
        find.descendant(of: header, matching: find.text('1 agent working')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: header, matching: find.text('·')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: header,
          matching: find.text('Ship the launch week'),
        ),
        findsOneWidget,
      );

      _work(client, 'wug', detail: 'Drafting');
      await t.pump();
      expect(
        find.descendant(of: header, matching: find.text('2 agents working')),
        findsOneWidget,
      );

      // On desktop the summary counts everyone, in the global workspace row.
      expect(
        find.descendant(
          of: find.byType(RaftWorkspaceTopBar),
          matching: find.byKey(const Key('working-agents-summary')),
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('3 agents working'), findsOneWidget);
      expect(find.byKey(_liveBar), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );
}
