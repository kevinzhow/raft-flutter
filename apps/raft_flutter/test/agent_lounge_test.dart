// Agent Lounge v0 (Web v1.24 components/agent/agentLounge.ts,
// AgentProfileOverflowMenu.tsx onOpenLounge, AgentDMStatus.tsx): the flag, the
// profile's Lounge entry, the opened row, and what a list refresh or a server
// switch does to an opened Lounge.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/agent_detail_view.dart';
import 'package:raft_flutter/features/agent_dm_header_extras.dart';
import 'package:raft_flutter/features/agent_lounge.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_presentation_test.dart' show MessageAdapter, fixture;
import 'panel_revisit_cache_test.dart' show settle;
import 'workspace_source_location_contract_test.dart' show LocalClient;

Map<String, dynamic> _agent({
  String? deletedAt,
  String? assistantOwnerUserId,
}) => {
  'id': 'a1',
  'name': 'bot',
  'displayName': 'Bot',
  'status': 'active',
  'runtime': 'claude',
  'model': 'sonnet',
  'deletedAt': ?deletedAt,
  'assistantOwnerUserId': ?assistantOwnerUserId,
};

Map<String, dynamic> _flag(bool enabled) => {
  'evaluations': [
    {'key': 'agent_lounge_v0', 'enabled': enabled},
  ],
};

void main() {
  setUp(() async {
    DevicePreferences.reset();
    SharedPreferences.setMockInitialValues({});
    DevicePreferences.adopt(await SharedPreferences.getInstance());
  });
  tearDown(DevicePreferences.reset);

  test(
    'the flag: remembered first, then the evaluation, a denial turns it off',
    () async {
      final (w, api) = await fixture('owner');
      addTearDown(w.dispose);
      FeatureFlagMemory.write(
        ['https://example.invalid', 'alice', 's1', 'owner'],
        {'agent_lounge_v0': true},
      );
      final answer = Completer<dynamic>();
      api.routes['POST /feature-flags/evaluate'] = (_) => answer.future;
      final flag = AgentLoungeFlag.of(w)..evaluate();
      // First frame: the remembered value, before any answer.
      expect(flag.enabled, isTrue);
      answer.complete(_flag(false));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(flag.enabled, isFalse);
      // Not for a Guest, even with the flag on.
      api.routes['POST /feature-flags/evaluate'] = (_) => _flag(true);
      w.server = RaftRecord({'id': 's1', 'role': 'guest'});
      expect(flag.enabled, isFalse);
    },
  );

  test('agentOffersLounge: not deleted, not a personal assistant', () {
    expect(agentOffersLounge(_agent()), isTrue);
    expect(agentOffersLounge(_agent(deletedAt: '2026-01-01')), isFalse);
    expect(agentOffersLounge(_agent(assistantOwnerUserId: 'u1')), isFalse);
  });

  test('the answer of POST /agents/:id/lounge becomes the row', () {
    final row = loungeRowFromOpenAnswer({
      'channel': {'id': 'lg1', 'name': 'bot-lounge', 'joined': false},
      'joined': true,
      'canPost': false,
    }, 'a1')!;
    expect(row.loungeAgentId, 'a1');
    expect(row.joined, isTrue);
    expect(row.canPost, isFalse);
    expect(loungeRowFromOpenAnswer({'channel': 1}, 'a1'), isNull);
    expect(loungeRowFromOpenAnswer(null, 'a1'), isNull);
  });

  test(
    'a list refresh keeps an opened Lounge; a server switch clears it',
    () async {
      final api = MessageAdapter();
      api.routes['POST /auth/login'] = (_) => {
        'accessToken': 'fixture-only',
        'refreshToken': 'fixture-only',
        'user': {'id': 'alice'},
      };
      final client = LocalClient(api);
      await client.login('fixture', 'fixture');
      client.selectServer('s1');
      final w = WorkspaceController(client)
        ..server = RaftRecord({'id': 's1', 'role': 'owner'})
        ..channels = [
          RaftChannel({'id': 'c1', 'name': 'test', 'joined': true}),
        ];
      addTearDown(w.dispose);
      api.routes['GET /channels'] = (_) => [];
      api.routes['GET /channels/dm'] = (_) => [];
      final lounge = loungeRowFromOpenAnswer({
        'channel': {'id': 'lg1', 'name': 'bot-lounge', 'type': 'channel'},
      }, 'a1')!;
      w.putSharedChannelRow(lounge);
      expect(w.channels.map((c) => c.id), containsAll(['c1', 'lg1']));
      await w.refreshChannels();
      // GET /channels does not list Lounges; the list never retires one, while
      // an ordinary channel it no longer carries is retired as before.
      expect(w.channels.map((c) => c.id), ['lg1']);
      await w.selectServer(RaftRecord({'id': 's2', 'role': 'owner'}));
      expect(w.channels.where((c) => c.id == 'lg1'), isEmpty);
    },
  );

  testWidgets('the minute clock re-renders once a minute only while active', (
    t,
  ) async {
    var now = 0;
    var builds = 0;
    Widget host({required bool active}) => MaterialApp(
      home: AgentStuckMinuteClock(
        active: active,
        nowMs: () => now,
        builder: (_, ms) {
          builds++;
          return Text('t$ms');
        },
      ),
    );
    await t.pumpWidget(host(active: true));
    expect(find.text('t0'), findsOneWidget);
    now = 60000;
    await t.pump(const Duration(minutes: 1));
    expect(find.text('t60000'), findsOneWidget);
    await t.pumpWidget(host(active: false));
    final before = builds;
    now = 120000;
    await t.pump(const Duration(minutes: 3));
    expect(builds, before);
    await t.pumpWidget(const SizedBox());
  });

  for (final (size, platform) in [
    (const Size(856, 944), TargetPlatform.android),
    (const Size(944, 856), TargetPlatform.android),
    (const Size(390, 844), TargetPlatform.linux),
  ]) {
    // The panel folds its commands into the menu at 480px and below.
    for (final folded in [if (size.width > 480) false, true]) {
      testWidgets(
        'the profile offers the Lounge ${folded ? 'in the overflow menu' : 'inline'} at $size $platform',
        (t) async {
          final (w, api) = (await t.runAsync(() => fixture('owner')))!;
          addTearDown(w.dispose);
          api.routes['POST /feature-flags/evaluate'] = (_) => _flag(true);
          // The workspace shell evaluates the server's flag once; the profile
          // only reads it.
          AgentLoungeFlag.of(w).evaluate();
          api.routes['POST /agents/a1/lounge'] = (_) => {
            'channel': {'id': 'lg1', 'name': 'bot-lounge', 'type': 'channel'},
          };
          t.view.physicalSize = size;
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.reset);
          Future<void> mount(Map<String, dynamic> agent) async {
            await t.pumpWidget(
              MaterialApp(
                theme: raftTheme().copyWith(platform: platform),
                home: Scaffold(
                  body: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: folded ? 400 : size.width,
                      child: AgentDetailPanel(
                        controller: w,
                        agent: agent,
                        machines: const [],
                        canManage: true,
                        canViewPrivate: true,
                        canControlRuntime: true,
                        actions: AgentDetailActions(onMessage: () {}),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await settle(t);
            await t.pumpAndSettle();
          }

          final entry = folded
              ? find.text('Lounge')
              : find.byKey(const Key('agent-profile-inline-lounge'));
          // Not for an assistant or a deleted agent, whatever the flag says.
          await mount(_agent(assistantOwnerUserId: 'u1'));
          expect(
            find.byKey(const Key('agent-profile-inline-lounge')),
            findsNothing,
          );
          await mount(_agent());
          if (folded) {
            await t.tap(
              find.byKey(const Key('agent-profile-overflow-trigger')),
            );
            await t.pumpAndSettle();
          }
          expect(entry, findsOneWidget);
          await t.tap(entry);
          await t.pumpAndSettle();
          expect(
            api.calls.where((c) => c.path == '/agents/a1/lounge').length,
            1,
          );
          expect(w.channelById('lg1')?.loungeAgentId, 'a1');
          await t.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
