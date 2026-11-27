// Web ChannelMembers.tsx members page: open external invites are an "Invited"
// section above Humans with member-row geometry, the load failure is a banner
// in the `p-3` gutter, and "Invite people outside {server}" is a full-width
// footer button under Add member (`border-t p-3 flex-col gap-2`).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/channel_members.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/joint_channel_fixture.dart' show fixture;

const _size = Size(412, 900);

final _channel = RaftChannel({
  'id': 'c1',
  'serverId': 's1',
  'name': 'project',
  'type': 'private',
  'joined': true,
  'channelCapabilities': {'addChannelMembers': true},
});

Future<dynamic> _mount(
  WidgetTester t, {
  bool invitesFail = false,
  Size size = _size,
  double scale = 1,
  List<Map<String, dynamic>>? invites,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final (w, api) = (await t.runAsync(fixture))!;
  addTearDown(w.dispose);
  w.channels = [_channel];
  w.server = RaftRecord({
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
      {'userId': 'alice', 'name': 'alice', 'displayName': 'Alice'},
    ],
    'agents': [],
  };
  // 13 days and 23 hours: the row reads "14 days left".
  final expires = DateTime.now().toUtc().add(
    const Duration(days: 13, hours: 23),
  );
  api.routes['GET /channels/c1/external-invites'] = (_) => {
    'invites':
        invites ??
        [
          {
            'id': 'i1',
            'email': 'guest@example.invalid',
            'expiresAt': expires.toIso8601String(),
          },
        ],
  };
  if (invitesFail) api.statuses['GET /channels/c1/external-invites'] = 500;
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme().copyWith(platform: TargetPlatform.android),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: ChannelMembers(controller: w, channel: _channel, page: true),
      ),
    ),
  );
  await t.pumpAndSettle();
  return api;
}

void main() {
  testWidgets('invite button sits under Add member in the footer gutter', (
    t,
  ) async {
    await _mount(t);
    final add = t.getRect(find.byKey(const ValueKey('add-member-open')));
    final invite = t.getRect(
      find.widgetWithText(RaftButton, 'Invite people outside Alpha'),
    );
    expect(add.left, 12);
    expect(add.right, _size.width - 12);
    expect(invite.left, add.left);
    expect(invite.right, add.right);
    expect(invite.top, add.bottom + 8);
    expect(invite.bottom, lessThanOrEqualTo(_size.height - 12));
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('Invited section above Humans uses the member row recipe', (
    t,
  ) async {
    await _mount(t);
    final invited = t.getRect(find.text('Invited'));
    final humans = t.getRect(find.text('Humans'));
    final email = t.getRect(find.text('guest@example.invalid'));
    final alice = t.getRect(find.text('Alice'));
    final days = t.getRect(find.text('14 days left'));
    final tile = t.getRect(
      find.byWidgetPredicate(
        (w) => w is RaftIconTile && w.glyph == RaftGlyph.mail,
      ),
    );

    expect(invited.left, humans.left);
    expect(invited.bottom, lessThanOrEqualTo(email.top));
    expect(email.bottom, lessThanOrEqualTo(humans.top));
    // Same inset as a member: tile in the avatar column, email in the name
    // column, the state inline after the email on the title line.
    expect(email.left, alice.left);
    expect(tile.right, lessThan(email.left));
    expect(tile.size, const Size(35, 35));
    expect(days.left, greaterThan(email.right));
    expect((days.center.dy - email.center.dy).abs(), lessThan(3));
    expect(
      find.descendant(
        of: find.byTooltip('Resend invite'),
        matching: find.byWidgetPredicate(
          (w) => w is RaftIcon && w.glyph == RaftGlyph.mail,
        ),
      ),
      findsOneWidget,
    );

    // The roster search filters invites like members (Web memberMatches).
    await t.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('member-page-search')),
        matching: find.byType(EditableText),
      ),
      'guest',
    );
    await t.pumpAndSettle();
    expect(find.text('guest@example.invalid'), findsOneWidget);
    expect(find.text('Alice'), findsNothing);
    expect(find.textContaining('No members match'), findsNothing);
    await t.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('member-page-search')),
        matching: find.byType(EditableText),
      ),
      'alice',
    );
    await t.pumpAndSettle();
    expect(find.text('Invited'), findsNothing);
    expect(find.text('guest@example.invalid'), findsNothing);
    expect(find.text('Alice'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('a failed invite read is a gutter banner that Retry resolves', (
    t,
  ) async {
    final api = await _mount(t, invitesFail: true);
    final banner = find.ancestor(
      of: find.text("Couldn't load the invites."),
      matching: find.byType(RaftBanner),
    );
    expect(banner, findsOneWidget);
    final rect = t.getRect(banner);
    expect(rect.left, 12);
    expect(rect.right, _size.width - 12);
    expect(rect.bottom, lessThan(t.getRect(find.text('Humans')).top));

    (api.statuses as Map).remove('GET /channels/c1/external-invites');
    await t.tap(find.descendant(of: banner, matching: find.text('Retry')));
    await t.pumpAndSettle();
    expect(find.text("Couldn't load the invites."), findsNothing);
    expect(find.text('guest@example.invalid'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  // Web ExternalInviteRow: the email is one truncated line and the state keeps
  // its width after it. Text too large for both on one line puts the state
  // under the email instead of wrapping the email a few letters at a time.
  for (final (size, scale) in [
    (const Size(360, 800), 1.3),
    (const Size(360, 800), 2.0),
    (const Size(390, 844), 3.1),
  ]) {
    testWidgets('at ${scale}x the state goes under a one-line email', (
      t,
    ) async {
      const address = 'a-very-long-guest-address@subdomain.example.invalid';
      await _mount(
        t,
        size: size,
        scale: scale,
        invites: [
          {'id': 'i1', 'email': address, 'awaitingApproval': true},
        ],
      );
      expect(t.takeException(), isNull);
      final row = t.getRect(find.byKey(const ValueKey('external-invite-i1')));
      final email = t.getRect(find.text(address));
      final state = t.getRect(find.text('Waiting for approval'));
      // One line: as tall as a member's one-line name in the same style.
      expect(email.height, t.getSize(find.text('Alice')).height);
      expect(state.top, greaterThanOrEqualTo(email.bottom));
      expect(state.left, email.left);
      expect(state.right, lessThanOrEqualTo(row.right));
      expect(state.bottom, lessThanOrEqualTo(row.bottom));
      await t.pumpWidget(const SizedBox());
    });
  }

  // At the default text size the state stays on the email's line. A line too
  // narrow for the whole state shortens the state instead of overflowing.
  testWidgets('at 1.0x a state wider than the line stays inside it', (t) async {
    const address = 'guest@example.invalid';
    await _mount(
      t,
      size: const Size(240, 800),
      invites: [
        {'id': 'i1', 'email': address, 'awaitingApproval': true},
      ],
    );
    expect(t.takeException(), isNull);
    final row = t.getRect(find.byKey(const ValueKey('external-invite-i1')));
    final email = t.getRect(find.text(address));
    final state = t.getRect(find.text('Waiting for approval'));
    expect((state.center.dy - email.center.dy).abs(), lessThan(3));
    expect(state.right, lessThanOrEqualTo(row.right));
    await t.pumpWidget(const SizedBox());
  });
}
