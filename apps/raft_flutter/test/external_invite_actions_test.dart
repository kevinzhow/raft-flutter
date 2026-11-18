import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/external_invite_api.dart';
import 'package:raft_flutter/features/external_invite_page.dart';
import 'package:raft_flutter/features/external_invite_route.dart';
import 'package:raft_flutter/platform/raft_app_links.dart';
import 'package:raft_ui/raft_ui.dart';

const _memberServer = {
  'id': 'team',
  'name': 'Team',
  'needsApproval': true,
  'approvers': [
    {'id': 'owner', 'name': 'Team owner'},
  ],
};

class _Invitation {
  final calls = <(String, Object?)>[];
  final opened = <(String, String?)>[];
  bool waiting = false, accepted = false, needsApproval = true;

  Future<dynamic> request(String method, String path, {dynamic data}) async {
    calls.add(('$method $path', data));
    switch (path.split('/').last) {
      case 'request-approval':
        waiting = true;
        return {'requestId': 'request'};
      case 'cancel-request':
        waiting = false;
        return {};
      case 'accept-as-guest':
        return {'serverId': 'host', 'channelId': 'project'};
      case 'connect':
        return {
          'state': 'connected',
          'serverId': 'team',
          'channelId': 'project-on-team',
        };
      case 'connect-new-server':
        return {'state': 'connecting', 'serverId': 'new-server'};
      case 'invite':
        return {
          'status': accepted
              ? 'accepted'
              : waiting
              ? 'awaiting_approval'
              : 'pending',
          if (accepted)
            'accepted': {
              'outcome': 'server',
              'serverId': 'team',
              'channelId': 'project-on-team',
              'channelName': 'project',
            },
          'channelName': 'project',
          'serverName': 'Home',
          'inviterName': 'Host',
          'options': {
            'guest': true,
            'newServer': true,
            'connect': {
              'servers': [
                {
                  ..._memberServer,
                  'needsApproval': needsApproval,
                  'canConnectDirectly': !needsApproval,
                },
              ],
              'slotsLeft': 2,
            },
          },
          if (waiting)
            'pendingRequest': {
              'requestId': 'request',
              'serverId': 'team',
              'serverName': 'Team',
              'approverName': 'Team owner',
            },
        };
      default:
        throw StateError('Unexpected invitation endpoint');
    }
  }

  Future<void> mount(
    WidgetTester tester,
    Size size,
    TargetPlatform platform,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: raftTheme().copyWith(platform: platform),
        home: ExternalInvitePage(
          api: ExternalInviteApi(request),
          token: 'invite',
          account: 'fixture@example.invalid',
          onSignOut: () {},
          onClose: () {},
          onOpen: (server, channel) async {
            opened.add((server, channel));
            return true;
          },
          onUpgrade: (_) async => true,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}

Future<void> _tap(WidgetTester t, String text) async {
  final target = find.text(text).hitTestable();
  expect(target, findsOneWidget);
  await t.tap(target);
  await t.pumpAndSettle();
}

void main() {
  for (final (size, platform) in [
    (const Size(390, 844), TargetPlatform.linux),
    (const Size(856, 944), TargetPlatform.android),
    (const Size(944, 856), TargetPlatform.android),
  ]) {
    testWidgets('ask an owner and withdraw the pending request at $size', (
      tester,
    ) async {
      final invite = _Invitation();
      await invite.mount(tester, size, platform);
      await _tap(tester, 'Connect a server');
      await _tap(tester, 'Team');
      await _tap(tester, 'Continue');
      expect(invite.calls, [('GET /external-invites/invite', null)]);
      await _tap(tester, 'Send request');
      expect(
        invite.calls.last.$1,
        'POST /external-invites/invite/request-approval',
      );
      expect(invite.calls.last.$2, {
        'serverId': 'team',
        'approverUserId': 'owner',
      });
      expect(find.text('Waiting for approval'), findsOneWidget);
      await _tap(tester, 'Cancel request');
      expect(find.text('Cancel request?'), findsOneWidget);
      await _tap(tester, 'Keep request');
      expect(invite.calls, hasLength(2));
      await _tap(tester, 'Cancel request');
      final confirm = find.descendant(
        of: find.byKey(const ValueKey('external-invite-cancel-dialog')),
        matching: find.text('Cancel request'),
      );
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(invite.calls.skip(2), [
        ('POST /external-invites/invite/cancel-request', null),
        ('GET /external-invites/invite', null),
      ]);
      expect(find.text('Join #project'), findsOneWidget);
      expect(find.text('Waiting for approval'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'waiting for approval opens the accepted channel on the next poll',
    (tester) async {
      final invite = _Invitation()..waiting = true;
      await invite.mount(tester, const Size(1280, 900), TargetPlatform.linux);
      expect(find.text('Waiting for approval'), findsOneWidget);
      expect(invite.calls, hasLength(1));
      invite.accepted = true;
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(invite.calls, hasLength(2));
      expect(invite.opened, [('team', 'project-on-team')]);
      await tester.pump(const Duration(seconds: 4));
      expect(invite.calls, hasLength(2));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('join as a guest commits after confirmation', (tester) async {
    final invite = _Invitation();
    await invite.mount(tester, const Size(1280, 900), TargetPlatform.linux);
    expect(
      find.text(
        'Join just this channel yourself to work with the humans and agents there.',
      ),
      findsOneWidget,
    );
    expect(
      find.text("Bring your teammates and agents from a server you're in."),
      findsOneWidget,
    );
    await _tap(tester, 'Join as a guest');
    expect(invite.opened, isEmpty);
    expect(invite.calls, hasLength(1));
    await _tap(tester, 'Join');
    expect(invite.calls.last, (
      'POST /external-invites/invite/accept-as-guest',
      null,
    ));
    expect(invite.opened, [('host', 'project')]);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a server administrator connects directly with the chosen id', (
    tester,
  ) async {
    final invite = _Invitation()..needsApproval = false;
    await invite.mount(tester, const Size(1280, 900), TargetPlatform.linux);
    await _tap(tester, 'Connect a server');
    await _tap(tester, 'Team');
    await _tap(tester, 'Connect Team');
    expect(invite.calls.last.$1, 'POST /external-invites/invite/connect');
    expect(invite.calls.last.$2, {'serverId': 'team'});
    expect(invite.opened, [('team', 'project-on-team')]);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('create and connect uses one POST and shows the 202 progress', (
    tester,
  ) async {
    final invite = _Invitation();
    await invite.mount(tester, const Size(1280, 900), TargetPlatform.linux);
    await _tap(tester, 'Create a new server');
    await _tap(tester, 'Create');
    expect(invite.calls, hasLength(1));
    final text = find.byType(EditableText);
    await tester.enterText(text.first, 'Fixture Team');
    await tester.pump();
    await _tap(tester, 'Create');
    expect(
      invite.calls.last.$1,
      'POST /external-invites/invite/connect-new-server',
    );
    expect(invite.calls.last.$2, {
      'name': 'Fixture Team',
      'slug': 'fixture-team',
    });
    expect(find.text('Connecting Fixture Team'), findsOneWidget);
    expect(invite.opened, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('app links validate the path and keep the coordinator boundary', () {
    const coordinator = 'https://api.raft.build';
    for (final route in ExternalInviteRoute.values) {
      final uri = Uri.parse(
        'https://app.raft.build/${route.segment}/invitation',
      );
      expect(RaftAppLinks.accepts(uri, on: true, api: coordinator), isTrue);
      expect(ExternalInviteRoute.parse(uri, coordinator), (
        kind: route,
        id: 'invitation',
      ));
      expect(
        ExternalInviteRoute.parse(
          uri.replace(host: 'not-raft.invalid'),
          coordinator,
        ),
        isNull,
      );
      expect(
        ExternalInviteRoute.parse(
          uri.replace(query: 'returnTo=other'),
          coordinator,
        ),
        isNull,
      );
    }
  });

  test(
    'new-channel email review stays available to the creation entry',
    () async {
      final calls = <(String, Object?)>[];
      final api = ExternalInviteApi((method, path, {data}) async {
        calls.add(('$method $path', data));
        return {
          'valid': ['one@example.invalid'],
        };
      });
      await api.previewEmails(null, ['one@example.invalid']);
      expect(calls.single.$1, 'POST /channels/external-invites/preview');
      expect(calls.single.$2, {
        'emails': ['one@example.invalid'],
      });
    },
  );
}
