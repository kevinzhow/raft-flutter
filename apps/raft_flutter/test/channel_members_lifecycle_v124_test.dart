import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/channel_members.dart';

import 'support/joint_channel_fixture.dart' show fixture, host;

void main() {
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
