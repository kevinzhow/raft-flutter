import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/channel_members.dart';
import 'package:raft_flutter/features/channel_joint_section.dart';

import 'support/joint_channel_fixture.dart' show fixture, host;

void main() {
  testWidgets(
    'member page previews addresses before sending an external invite',
    (tester) async {
      final (workspace, api) = (await tester.runAsync(fixture))!;
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
        'plan': 'free',
      });
      api.routes['POST /feature-flags/evaluate'] = (_) => {
        'evaluations': [
          {'key': 'external_channels_v1', 'enabled': true},
        ],
      };
      api.routes['GET /channels/c1/members'] = (_) => {
        'humans': [],
        'agents': [],
      };
      api.routes['GET /channels/external-availability'] = (_) => {
        'freeLimitReached': false,
      };
      api.routes['GET /channels/c1/external-invites'] = (_) => {'invites': []};
      api.routes['GET /channels/external-connect-servers'] = (_) => {
        'servers': [],
      };
      api.routes['POST /channels/c1/external-invites/preview'] = (_) => {
        'valid': ['guest@example.invalid'],
        'invalid': ['bad-address'],
        'slotsLeft': 4,
      };
      api.routes['POST /channels/c1/external-invites'] = (_) => {
        'sent': [
          {'id': 'invite', 'email': 'guest@example.invalid'},
        ],
      };
      await tester.pumpWidget(
        host(
          ChannelMembers(channel: channel, controller: workspace, page: true),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Invite people outside Alpha'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('external-invite-emails')),
        'guest@example.invalid; bad-address',
      );
      await tester.pump();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(
        api.calls.map((call) => '${call.method} ${call.path}'),
        contains('POST /channels/c1/external-invites/preview'),
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((text) => text.data)
            .whereType<String>()
            .join(' | '),
      );
      expect(find.text('Not a valid email · no invite'), findsOneWidget);
      expect(
        api.calls.where(
          (call) =>
              call.path == '/channels/c1/external-invites' &&
              call.method == 'POST',
        ),
        isEmpty,
      );
      await tester.tap(find.text('Invite'));
      await tester.pumpAndSettle();

      final send = api.calls.singleWhere(
        (call) =>
            call.path == '/channels/c1/external-invites' &&
            call.method == 'POST',
      );
      expect(send.data, {
        'emails': ['guest@example.invalid'],
      });
      expect(
        find.byKey(const ValueKey('add-external-member-dialog')),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final (enabled, legacy) in [
    (false, false),
    (true, false),
    (true, true),
  ]) {
    testWidgets(
      'host disconnect with flag $enabled and legacy peer row $legacy',
      (tester) async {
        final (workspace, api) = (await tester.runAsync(fixture))!;
        addTearDown(workspace.dispose);
        final channel = RaftChannel({
          'id': 'c1',
          'serverId': 's1',
          'name': 'project',
          'type': 'joint',
          'jointRole': 'host',
          'joined': true,
          'channelCapabilities': {'federateChannels': true},
          if (legacy)
            'jointPeerServerSlug': 'beta'
          else
            'jointServers': [
              {
                'serverId': 's1',
                'serverSlug': 'alpha',
                'role': 'host',
                'isCurrentServer': true,
                'status': 'active',
                'serverName': 'Alpha',
              },
              {
                'serverId': 's2',
                'serverSlug': 'beta',
                'role': 'participant',
                'status': 'active',
                'serverName': 'Beta',
              },
            ],
        });
        workspace.channels = [channel];
        api.routes['POST /feature-flags/evaluate'] = (_) => {
          'evaluations': [
            {'key': 'external_channels_v1', 'enabled': enabled},
          ],
        };
        api.routes['POST /channels/c1/joint-servers/s2/disconnect'] = (_) => {
          'ok': true,
        };
        api.routes['GET /channels/c1'] = (_) => channel.json;
        await tester.pumpWidget(
          host(ChannelJointSection(controller: workspace, channelId: 'c1')),
        );
        await tester.pumpAndSettle();
        final disconnect = find.byKey(
          ValueKey(legacy ? 'joint-disconnect-beta' : 'joint-disconnect-s2'),
        );
        if (enabled && !legacy) {
          expect(disconnect, findsOneWidget);
          await tester.tap(disconnect);
          await tester.pumpAndSettle();
          expect(find.text('Disconnect Beta?'), findsOneWidget);
          expect(
            api.calls.where((call) => call.path.endsWith('/disconnect')),
            isEmpty,
          );
          await tester.tap(find.text('Disconnect Beta'));
          await tester.pumpAndSettle();
          expect(
            api.calls.where(
              (call) =>
                  call.method == 'POST' &&
                  call.path == '/channels/c1/joint-servers/s2/disconnect',
            ),
            hasLength(1),
          );
        } else {
          expect(disconnect, findsNothing);
        }
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
