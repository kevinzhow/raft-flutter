// The channel members page lays the external-invite entry and the Invited
// group out the way Web v1.24 does.
//
// Kevin, 2026-11-26 (task #377, screenshots k12747/k12745): the "Invite
// people outside {server}" button ran edge to edge with no side inset, and
// the "Invited" rows were raw two-line text with no padding or row styling.
//
// Web (packages/web/src/features/channel/ChannelMembers.tsx):
//   :1187-1219  the invite button shares the pinned footer with Add member
//               (`border-t border-line-seam p-3`, `gap-2`, `w-full`).
//   :1120-1128  the Invited group is a MemberPageSection ABOVE Humans.
//   ExternalInviteRows.tsx:148-164  each invite is a ChannelMemberRow, so it
//               carries the member row's `px-4` inset.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/channel_members.dart';

import 'support/joint_channel_fixture.dart' show fixture, host;

void main() {
  testWidgets('the invite entry and the Invited group follow Web geometry', (
    t,
  ) async {
    t.view.physicalSize = const Size(412, 915);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final (workspace, api) = (await t.runAsync(fixture))!;
    addTearDown(workspace.dispose);
    final channel = RaftChannel({
      'id': 'c1',
      'serverId': 's1',
      'name': 'project',
      'type': 'private',
      'joined': true,
    });
    workspace.channels = [channel];
    workspace.server = RaftRecord({
      'id': 's1',
      'name': 'Alpha',
      'slug': 'alpha',
      'role': 'owner',
      'plan': 'pro',
    });
    api.routes['POST /feature-flags/evaluate'] = (_) => {
      'evaluations': [
        {'key': 'external_channels_v1', 'enabled': true},
      ],
    };
    api.routes['GET /channels/c1/members'] = (_) => {
      'humans': [
        {'id': 'u1', 'name': 'Kevin', 'displayName': 'Kevin'},
      ],
      'agents': [],
    };
    api.routes['GET /channels/external-availability'] = (_) => {
      'freeLimitReached': false,
    };
    api.routes['GET /channels/c1/external-invites'] = (_) => {
      'invites': [
        {
          'id': 'i1',
          'email': 'guest@example.invalid',
          'expiresAt': DateTime.now()
              .add(const Duration(days: 14))
              .toIso8601String(),
        },
      ],
    };
    await t.pumpWidget(
      host(ChannelMembers(channel: channel, controller: workspace, page: true)),
    );
    await t.pumpAndSettle();

    final email = find.text('guest@example.invalid');
    final invited = find.text('Invited');
    final humans = find.text('Humans');
    final button = find.text('Invite people outside Alpha');
    expect(email, findsOneWidget);
    expect(invited, findsOneWidget);
    expect(button, findsOneWidget);

    // Web `p-3` footer: the entry is inset, never edge to edge.
    final entry = find.byKey(const ValueKey('member-page-invite-outside'));
    expect(entry, findsOneWidget);
    expect(
      t.getRect(entry).left,
      closeTo(12, .5),
      reason: 'invite entry is full-bleed; Web insets it by the footer p-3',
    );
    expect(
      t.getRect(entry).right,
      closeTo(412 - 12, .5),
      reason: 'invite entry is full-bleed; Web insets it by the footer p-3',
    );

    // Web ChannelMemberRow `px-4`: the invited row is inset like a member row.
    expect(
      t.getRect(email).left,
      greaterThanOrEqualTo(16),
      reason: 'invited row has no inset; Web gives it the member row px-4',
    );

    // Web renders the Invited group above Humans.
    expect(
      t.getRect(invited).top,
      lessThan(t.getRect(humans).top),
      reason: 'Web puts the Invited group above Humans',
    );

    // The entry sits below the roster, in the pinned footer.
    expect(t.getRect(entry).top, greaterThan(t.getRect(email).top));

    // Web keeps the days-left state on the email's line, not under it.
    expect(find.text('14 days left'), findsOneWidget);
    expect(
      t.getRect(find.text('14 days left')).center.dy,
      closeTo(t.getRect(email).center.dy, 4),
      reason: 'Web puts the invite state on the email line, in hint ink',
    );

    await t.pumpWidget(const SizedBox());
  });
}
