import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/channel_roster_invalidations.dart';
import 'package:raft_flutter/features/add_members_dialog.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/joint_channel_fixture.dart' show fixture, host;

void main() {
  testWidgets('local suggestions follow both sync and raw membership updates', (
    t,
  ) async {
    final (w, api) = (await t.runAsync(() => fixture()))!;
    addTearDown(w.dispose);
    addTearDown(w.client.dispose);
    w.channels = [
      RaftChannel({
        'id': 'c1',
        'name': 'work',
        'type': 'channel',
        'serverId': 's1',
      }),
    ];
    var localJoined = false;
    api.routes['GET /channels/c1/members'] = (_) => {
      'humans': [
        {'id': 'bob', 'name': 'Bob', 'serverId': localJoined ? 's1' : 'other'},
      ],
      'agents': <dynamic>[],
    };
    t.view.physicalSize = const Size(1280, 1200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      host(
        AddMembersDialog(
          controller: w,
          channelId: 'c1',
          prefilledHumanIds: const ['bob'],
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Bob'), findsOneWidget);
    expect(
      t
          .widget<RaftAddMembersDialogView>(
            find.byType(RaftAddMembersDialogView),
          )
          .selectedCount,
      1,
    );
    localJoined = true;
    ChannelRosterInvalidations.of(w.client).invalidate('c1');
    await t.pumpAndSettle();
    expect(find.text('Bob'), findsNothing);
    expect(
      find.text(
        'Everyone the agent suggested is already a member of this channel. Nothing to add.',
      ),
      findsOneWidget,
    );
    expect(
      t
          .widget<RaftAddMembersDialogView>(
            find.byType(RaftAddMembersDialogView),
          )
          .selectedCount,
      0,
    );
    final reads = api.calls
        .where((call) => call.path == '/channels/c1/members')
        .length;
    (w.client as dynamic).forwarded.add(
      const RaftEvent('channel:members-updated', {'channelId': 'other'}),
    );
    await t.pumpAndSettle();
    expect(
      api.calls.where((call) => call.path == '/channels/c1/members'),
      hasLength(reads),
    );
    localJoined = false;
    (w.client as dynamic).forwarded.add(
      const RaftEvent('channel:members-updated', {'channelId': 'c1'}),
    );
    await t.pumpAndSettle();
    final view = t.widget<RaftAddMembersDialogView>(
      find.byType(RaftAddMembersDialogView),
    );
    expect(view.nothingToAdd, isFalse);
    expect(view.humanSection, isTrue);
    expect(
      view.selectedCount,
      0,
      reason: 'membership updates preserve the user selection',
    );
    expect(
      find.text(
        'Everyone the agent suggested is already a member of this channel. Nothing to add.',
      ),
      findsNothing,
    );
    expect(
      api.calls.where((call) => call.path == '/channels/c1/members'),
      hasLength(reads + 1),
    );
    await t.pumpWidget(const SizedBox.shrink());
  });
}
