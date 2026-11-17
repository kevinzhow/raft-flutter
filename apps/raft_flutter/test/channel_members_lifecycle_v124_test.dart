import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/channel_members.dart';

import 'support/joint_channel_fixture.dart' show fixture, host;

void main() {
  testWidgets(
    'a rejected add marks the choices and a corrected retry clears it',
    (t) async {
      final (w, api) = (await t.runAsync(() => fixture()))!;
      addTearDown(w.dispose);
      addTearDown(w.client.dispose);
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final channel = RaftChannel({
        'id': 'c1',
        'name': 'work',
        'type': 'channel',
        'channelCapabilities': {'addChannelMembers': true},
      });
      w.channels = [channel];
      const path = 'POST /channels/c1/members/batch';
      var joined = false;
      api.routes['GET /channels/c1/members'] = (_) => {
        'humans': const [],
        'agents': [
          if (joined) {'id': 'a1', 'name': 'Cindy'},
        ],
      };
      api.routes[path] = (request) {
        if (api.statuses[path] == 409) return {'error': 'Refused'};
        expect(request.data, {
          'userIds': [],
          'agentIds': ['a1'],
        });
        joined = true;
        return <String, dynamic>{};
      };
      api.statuses[path] = 409;
      await t.pumpWidget(
        host(
          ChannelMembers(
            controller: w,
            channel: channel,
            page: true,
            startInAdd: true,
          ),
        ),
      );
      await t.pumpAndSettle();
      Finder key(String value) => find.byKey(ValueKey(value));
      final confirm = key('add-member-confirm');
      await t.tap(key('add-candidate-agent:a1'));
      await t.tap(key('add-candidate-human:bob'));
      await t.pumpAndSettle();
      await t.tap(confirm);
      await t.pumpAndSettle();
      expect(
        find.text('None of the selected members could be added.'),
        findsOneWidget,
      );
      expect(find.text('Failed to add'), findsNWidgets(2));
      await t.tap(find.bySemanticsLabel('Deselect Bob'));
      await t.pumpAndSettle();
      expect(
        find.text('None of the selected members could be added.'),
        findsNothing,
      );
      expect(find.text('Failed to add'), findsOneWidget);
      api.statuses.remove(path);
      await t.tap(confirm);
      await t.pumpAndSettle();
      expect(joined, isTrue);
      expect(find.text('Failed to add'), findsNothing);
      expect(key('member-page-row-agent-a1'), findsOneWidget);
      await t.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final button in [false, true]) {
    testWidgets(
      'mounted member ${button ? 'trigger' : 'roster'} follows a changed channel',
      (t) async {
        final (w, api) = (await t.runAsync(() => fixture()))!;
        addTearDown(w.dispose);
        addTearDown(w.client.dispose);
        final channels = [
          for (final id in ['c1', 'c2'])
            RaftChannel({'id': id, 'name': id, 'type': 'channel'}),
        ];
        w.channels = channels;
        for (var i = 0; i < channels.length; i++) {
          final channel = channels[i];
          api.routes['GET /channels/${channel.id}/members'] = (_) => {
            'humans': [
              for (var n = 0; n <= i; n++)
                {'id': '${channel.id}-$n', 'name': '${channel.id} person $n'},
            ],
            'agents': <dynamic>[],
          };
        }
        Widget view(RaftChannel channel) => host(
          button
              ? ChannelMembersButton(controller: w, channel: channel)
              : ChannelMembers(controller: w, channel: channel),
        );
        await t.pumpWidget(view(channels[0]));
        await t.pumpAndSettle();
        expect(find.text(button ? '1' : 'c1 person 0'), findsOneWidget);
        await t.pumpWidget(view(channels[1]));
        await t.pumpAndSettle();
        expect(find.text(button ? '2' : 'c2 person 0'), findsOneWidget);
        if (!button) expect(find.text('c1 person 0'), findsNothing);
        await t.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets('member picker filters the signed-in user by channel roster', (
    t,
  ) async {
    final (w, api) = (await t.runAsync(() => fixture()))!;
    addTearDown(w.dispose);
    addTearDown(w.client.dispose);
    final channels = [
      for (final id in ['c1', 'c2'])
        RaftChannel({
          'id': id,
          'name': id,
          'type': 'channel',
          'channelCapabilities': {'addChannelMembers': true},
        }),
    ];
    w.channels = channels;
    api.routes['GET /channels/c1/members'] = (_) => {
      'humans': const [],
      'agents': const [],
    };
    api.routes['GET /channels/c2/members'] = (_) => {
      'humans': [
        {'userId': 'alice', 'name': 'Self'},
      ],
      'agents': const [],
    };
    Widget view(RaftChannel channel) =>
        host(ChannelMembers(controller: w, channel: channel, startInAdd: true));
    await t.pumpWidget(view(channels.first));
    await t.pumpAndSettle();
    expect(find.text('Self'), findsOneWidget);
    await t.pumpWidget(view(channels.last));
    await t.pumpAndSettle();
    expect(find.text('Self'), findsNothing);
    expect(find.text('Bob'), findsOneWidget);
    await t.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('new agent names preserve an internal @ exactly as typed', (
    t,
  ) async {
    final (w, api) = (await t.runAsync(() => fixture()))!;
    addTearDown(w.dispose);
    addTearDown(w.client.dispose);
    final channel = RaftChannel({
      'id': 'c1',
      'name': 'work',
      'type': 'channel',
      'channelCapabilities': {'addChannelMembers': true},
    });
    w.channels = [channel];
    api.routes['GET /channels/c1/members'] = (_) => {
      'humans': [],
      'agents': [],
    };
    String? received;
    t.view.physicalSize = const Size(1280, 1200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      host(
        ChannelMembers(
          controller: w,
          channel: channel,
          startInAdd: true,
          createAgentForm: (context, w, {initialName}) async {
            received = initialName;
            return null;
          },
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).first, 'deploy@bot');
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('add-member-create-agent-entry')));
    await t.pumpAndSettle();
    expect(received, 'deploy@bot');
    await t.pumpWidget(const SizedBox.shrink());
  });
}
