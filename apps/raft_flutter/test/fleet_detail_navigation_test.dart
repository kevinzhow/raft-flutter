import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/features/fleet_views.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/agent_panel_fixture.dart';

const _channelId = '11111111-1111-4111-8111-111111111111';
const _messageId = '22222222-2222-4222-8222-222222222222';

class _Workspace extends AgentPanelWorkspace {
  _Workspace(super.client, {super.routes});
  final jumps = <(String, String?)>[];
  @override
  Future<void> jumpToMessage(
    String channelId,
    String? messageId, {
    bool navigate = true,
    bool replaceEntry = false,
  }) async => jumps.add((channelId, messageId));
}

/// FleetDetail's navigation handlers (the agent profile's Info rows, Chat
/// rows and reminder chips), against a recording controller.
void main() {
  late _Workspace w;
  late AgentPanelClient client;
  var closed = 0;

  Future<void> open(
    WidgetTester tester, {
    required Map<String, Object? Function()> routes,
    AgentDetailTab tab = AgentDetailTab.profile,
    String role = 'owner',
  }) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    closed = 0;
    client = AgentPanelClient()..selectServer('s');
    w = _Workspace(client, routes: routes)
      ..server = RaftRecord({
        'id': 's',
        'name': 'Fixture',
        'slug': 'dev',
        'role': role,
      });
    addTearDown(() async {
      w.dispose();
      await client.stream.close();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant)
            .copyWith(platform: TargetPlatform.linux),
        home: Scaffold(
          body: FleetDetail(
            controller: w,
            computers: false,
            initial: const {'id': 'a'},
            initialTab: tab,
            onClose: () => closed++,
            onLeaveForMessage: () => closed++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Map<String, Object?> agent() => {
    ...agentPanelAgent,
    'creator': {
      'id': 'bob',
      'type': 'human',
      'name': 'bob',
      'displayName': 'Bob',
      'avatarUrl': null,
    },
  };

  Map<String, Object? Function()> routes([Map<String, Object?>? extra]) => {
    '/agents': () => [agent()],
    '/agents/a': agent,
    '/servers/s/machines': () => {'machines': agentPanelMachines},
    '/agents/a/skills': () => {'global': [], 'workspace': []},
    '/agents/a/channels': () => {
      'channels': [
        {'id': 'c1', 'name': 'general', 'type': 'channel'},
      ],
    },
    '/agents/a/agent-dms': () => {'dms': []},
    '/reminders': () => {
      'reminders': [
        {
          'reminderId': 'r1',
          'title': 'Check',
          'fireAt': DateTime.now()
              .add(const Duration(hours: 2))
              .toUtc()
              .toIso8601String(),
          'status': 'scheduled',
          'ownerAgentId': 'a',
          'msgRef': '#general:2222',
          'msgPermalink':
              'https://app.raft.build/s/dev/channel/$_channelId?msg=$_messageId',
        },
      ],
    },
  };

  testWidgets('the creator opens their profile in place', (tester) async {
    await open(tester, routes: routes());
    final link = find.byKey(const ValueKey('agent-creator-link'));
    await tester.ensureVisible(link);
    await tester.tap(link);
    await tester.pump();
    expect(w.location.query('profile'), contains('bob'));
  });

  testWidgets('the Computer opens in the workspace', (tester) async {
    await open(tester, routes: routes());
    final link = find.byKey(const ValueKey('agent-computer-link'));
    await tester.ensureVisible(link);
    await tester.tap(link);
    await tester.pump();
    expect(w.location.route, RaftRoute.computer);
    expect(w.location.entityId, 'm1');
  });

  testWidgets('a channel row leaves the profile for that channel', (
    tester,
  ) async {
    await open(tester, routes: routes(), tab: AgentDetailTab.chat);
    await tester.tap(find.text('general'));
    await tester.pump();
    expect(w.jumps, [('c1', null)]);
    expect(closed, 1);
  });

  testWidgets('a reminder chip leaves the profile for the message', (
    tester,
  ) async {
    await open(tester, routes: routes(), tab: AgentDetailTab.reminders);
    await tester.tap(find.byKey(const ValueKey('reminder-msg-ref')));
    await tester.pump();
    expect(w.jumps, [(_channelId, _messageId)]);
    expect(closed, 1);
  });
}
