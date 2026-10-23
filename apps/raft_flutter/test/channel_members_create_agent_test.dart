// Web ChannelMembers add view: the pinned "Create Agent" entry opens the
// create-agent dialog and the new agent joins this channel.
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/channel_members.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/joint_channel_fixture.dart' show fixture;

Map<String, dynamic> row() => {
  'id': 'c1',
  'name': 'work',
  'type': 'channel',
  'joined': true,
  'channelCapabilities': {
    'addChannelMembers': true,
    'removeChannelMembers': true,
    'editChannelMetadata': true,
  },
};

List<RequestOptions> calls(dynamic api) => (api.calls as List).cast();

void main() {
  Finder key(String v) => find.byKey(ValueKey(v));

  Future<(WorkspaceController, dynamic, List<String?>)> open(
    WidgetTester t, {
    String role = 'owner',
    Map<String, dynamic>? created,
    bool dismiss = false,
  }) async {
    final (w, api) = (await t.runAsync(() => fixture(role)))!;
    addTearDown(w.dispose);
    final channel = RaftChannel(row());
    w.channels = [channel];
    api.routes['GET /channels/c1/members'] = (_) => {
      'humans': <dynamic>[],
      'agents': <dynamic>[],
    };
    api.routes['GET /agents'] = (_) => [
      {'id': 'a-helper', 'name': 'helper', 'displayName': 'Helper'},
    ];
    api.routes['POST /feature-flags/evaluate'] = (_) => {'evaluations': []};
    final names = <String?>[];
    t.view.physicalSize = const Size(1280, 1800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: Scaffold(
          body: ChannelMembers(
            controller: w,
            channel: channel,
            startInAdd: true,
            createAgentForm: (context, w, {initialName}) async {
              names.add(initialName);
              return dismiss
                  ? null
                  : created ?? {'id': 'a-new', 'name': 'deploy-bot'};
            },
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    return (w, api, names);
  }

  testWidgets('the entry is pinned in the add view and names the channel', (
    t,
  ) async {
    await open(t);
    expect(key('add-member-create-agent-entry'), findsOneWidget);
    expect(find.text('Create Agent'), findsOneWidget);
    expect(
      find.text('Joins #work automatically after creation'),
      findsOneWidget,
    );
  });

  testWidgets('creating an agent joins it with the one atomic batch', (
    t,
  ) async {
    final (_, api, names) = await open(t);
    api.routes['POST /channels/c1/members/batch'] = (_) => {'ok': true};
    await t.tap(key('add-member-create-agent-entry'));
    await t.pumpAndSettle();
    // A generic row never smuggles the search text into the dialog.
    expect(names, [null]);
    expect(
      api.calls
          .where((c) => c.path == '/channels/c1/members/batch')
          .single
          .data,
      {
        'userIds': <dynamic>[],
        'agentIds': ['a-new'],
      },
    );
    expect(key('add-member-create-agent-join-failed'), findsNothing);
  });

  testWidgets('a search with no hit promotes the entry and carries the name', (
    t,
  ) async {
    final (_, api, names) = await open(t);
    api.routes['POST /channels/c1/members/batch'] = (_) => {'ok': true};
    await t.enterText(find.byType(TextField).first, '@deploy-bot');
    await t.pump();
    expect(find.text('Create Agent “deploy-bot”'), findsOneWidget);
    await t.tap(key('add-member-create-agent-entry'));
    await t.pumpAndSettle();
    expect(names, ['deploy-bot'], reason: 'the leading @ is dropped');
  });

  testWidgets('a search that matches somebody keeps the generic entry', (
    t,
  ) async {
    final (_, _, names) = await open(t);
    await t.enterText(find.byType(TextField).first, 'help');
    await t.pump();
    expect(find.text('Create Agent'), findsOneWidget);
    await t.tap(key('add-member-create-agent-entry'));
    await t.pumpAndSettle();
    expect(names, [null]);
  });

  testWidgets('a dismissed dialog adds nobody', (t) async {
    final (_, api, _) = await open(t, dismiss: true);
    await t.tap(key('add-member-create-agent-entry'));
    await t.pumpAndSettle();
    expect(calls(api).where((c) => c.path.endsWith('/members/batch')), isEmpty);
  });

  testWidgets(
    'a failed join keeps the agent, says so, and retries the same batch',
    (t) async {
      final (_, api, _) = await open(t);
      var fail = true;
      api.routes['POST /channels/c1/members/batch'] = (_) => {
        'error': fail ? 'nope' : 'ok',
      };
      api.statuses['POST /channels/c1/members/batch'] = 500;
      await t.tap(key('add-member-create-agent-entry'));
      await t.pumpAndSettle();
      expect(key('add-member-create-agent-join-failed'), findsOneWidget);
      expect(
        find.text('Agent “deploy-bot” was created but could not join #work'),
        findsOneWidget,
      );
      // It is staged in the ordinary selection too.
      expect(find.byKey(const ValueKey('add-member-confirm')), findsOneWidget);
      fail = false;
      api.statuses.remove('POST /channels/c1/members/batch');
      await t.tap(key('add-member-create-agent-retry-join'));
      await t.pumpAndSettle();
      expect(key('add-member-create-agent-join-failed'), findsNothing);
      expect(
        calls(api).where((c) => c.path == '/channels/c1/members/batch').length,
        2,
      );
      expect(
        calls(api).where((c) => c.path == '/agents' && c.method == 'POST'),
        isEmpty,
        reason: 'a retry never creates a second agent',
      );
    },
  );

  testWidgets(
    'without createAgents the row stays visible but inert, with the reason',
    (t) async {
      final (w, api, names) = await open(t, role: 'member');
      expect(w.can('createAgents'), isFalse);
      expect(key('add-member-create-agent-entry-disabled'), findsOneWidget);
      expect(
        find.text(
          'You can add members here, but creating Agents on this server needs an owner or admin. Ask one to grant the permission, or have them create the Agent so you can add it.',
        ),
        findsOneWidget,
      );
      await t.tap(find.text('Create Agent'));
      await t.pumpAndSettle();
      expect(names, isEmpty);
      expect(
        calls(api).where((c) => c.path.endsWith('/members/batch')),
        isEmpty,
      );
    },
  );
}
