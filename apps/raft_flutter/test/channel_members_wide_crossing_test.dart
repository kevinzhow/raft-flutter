// A phone channel members page carried onto a wide window (unfold, resize, a
// cold link): Web keeps ChannelOverflowMenu mounted with `view: "members"`, so
// the members page shows in the channel's details card beside the
// conversation, never as a dialog over the window.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/channel_details_host.dart';
import 'package:raft_flutter/features/channel_members.dart';
import 'package:raft_flutter/features/workspace_view.dart';

import 'edge_to_edge_audit_test.dart' show openChannel, settle;
import 'foldable_layout_routing_test.dart'
    show mount, phone, resize, scenario, sidebarShown, where, wide;

void expectMembersInDetailsCard(WidgetTester t, {required bool add}) {
  final members = find.byType(ChannelMembers);
  expect(members, findsOneWidget);
  expect(
    find.descendant(of: find.byType(ChannelDetailsHost), matching: members),
    findsOneWidget,
    reason: 'the members page is the details card, not a dialog',
  );
  expect(
    ModalRoute.of(t.element(members)),
    same(ModalRoute.of(t.element(find.byType(WorkspaceView)))),
  );
  expect(t.widget<ChannelMembers>(members).startInAdd, add);
  expect(sidebarShown(t), isTrue);
}

void main() {
  scenario('members page on phone, unfold: members in the details card', (
    t,
  ) async {
    final f = await mount(t, phone, '/s/alpha');
    await openChannel(t, f);
    final w = f.workspace(t);
    w.navigation.navigate(w.location.withQuery({'channelPage': 'members:ca'}));
    w.notifyListeners();
    await settle(t);
    expect(find.byType(ChannelMembers), findsOneWidget);
    await resize(t, f, wide);
    await settle(t);
    expect(where(f, t), '/channel/ca', reason: 'phone-only param dropped');
    expectMembersInDetailsCard(t, add: false);
  });

  scenario('cold wide link to the add-members page opens it in the card', (
    t,
  ) async {
    final f = await mount(
      t,
      wide,
      '/s/alpha/channel/ca?channelPage=members:ca&channelPageAdd=1',
    );
    expect(where(f, t), '/channel/ca');
    expectMembersInDetailsCard(t, add: true);
  });
}
