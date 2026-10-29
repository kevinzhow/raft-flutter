import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/feature_flag_client_facts.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/locale_settings_page.dart'
    show effectiveTimeFormat;
import 'package:raft_flutter/features/member_profile_rules.dart';
import 'package:raft_flutter/features/member_profile_view.dart';
import 'package:raft_flutter/features/sender_avatar_projection.dart';
import 'package:raft_ui/raft_ui.dart';

Map<String, dynamic> fixture(String name) =>
    jsonDecode(File('test/fixtures/field_parity/$name.json').readAsStringSync())
        as Map<String, dynamic>;

const currentServer = '22222222-2222-4222-8222-222222222201';

class _Client extends RaftClient {
  _Client()
    : super(origin: 'https://fixture.test', sessionStore: MemorySessionStore());
}

class _Workspace extends WorkspaceController {
  _Workspace(super.client, this.profile);
  final Map<String, dynamic> profile;
  final queries = <String>[];
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    queries.add(path);
    return path.endsWith('/profile') ? profile : [];
  }

  @override
  Future<dynamic> command(
    String method,
    String path, {
    Object? data,
    Map<String, dynamic>? query,
  }) async => path == '/feature-flags/evaluate' ? {'evaluations': []} : null;
}

void main() {
  final removed = fixture('members-member-profile-removed');
  final summary = fixture('members-member-profile-channel-summary');
  final me = fixture('members-auth-me');

  group('member profile rules (HumanDetailPanel.tsx:200-241)', () {
    test('removed member: Web shows li_wen, Removed badge, no actions', () {
      expect(humanDisplayName(removed), 'li_wen');
      expect(humanDepartureLabel(removed['membershipStatus']), 'Removed');
      expect(humanDepartureLabel('left'), 'Left');
      expect(humanDepartureLabel('active'), isNull);
      expect(humanDepartureLabel(null), isNull);
      final remote = isRemoteJointHuman(removed, currentServer);
      expect(remote, isFalse);
      expect(
        canRemoveHuman(
          membershipStatus: removed['membershipStatus'],
          remoteJoint: remote,
          hasRemoveMembers: true,
          isSelf: false,
          targetRole: removed['role'] as String?,
          actorRole: 'owner',
          ownerCount: 2,
        ),
        isFalse,
      );
      expect(
        canMessageHuman(
          membershipStatus: removed['membershipStatus'],
          remoteJoint: remote,
          actorRole: 'owner',
          targetRole: null,
        ),
        isFalse,
      );
      expect(
        canEditHumanRole(
          membershipStatus: removed['membershipStatus'],
          remoteJoint: remote,
          hasChangeMemberRoles: true,
          editableRoles: const ['member'],
        ),
        isFalse,
      );
    });

    test('channel_summary peer: source label, identity-only, no actions', () {
      expect(isChannelSummaryHuman(summary), isTrue);
      expect(isRemoteJointHuman(summary, currentServer), isTrue);
      expect(humanSourceServerLabel(summary, currentServer), 'Partner Studio');
      expect(
        humanSourceServerLabel({
          'serverSlug': 'partner-studio',
          'serverId': 'x',
        }, currentServer),
        'partner-studio',
      );
      expect(
        humanSourceServerLabel(summary, summary['serverId'] as String),
        isNull,
      );
      expect(humanDisplayName(summary), 'Jo Park');
      expect(
        canRemoveHuman(
          membershipStatus: 'active',
          remoteJoint: true,
          hasRemoveMembers: true,
          isSelf: false,
          targetRole: null,
          actorRole: 'owner',
          ownerCount: 1,
        ),
        isFalse,
      );
      expect(
        canMessageHuman(
          membershipStatus: 'active',
          remoteJoint: true,
          actorRole: 'owner',
          targetRole: null,
        ),
        isFalse,
      );
    });

    test(
      'canRemove: admin only removes members; owner needs another owner',
      () {
        bool remove(String actor, String target, {int owners = 1}) =>
            canRemoveHuman(
              membershipStatus: 'active',
              remoteJoint: false,
              hasRemoveMembers: true,
              isSelf: false,
              targetRole: target,
              actorRole: actor,
              ownerCount: owners,
            );
        expect(remove('admin', 'member'), isTrue);
        expect(remove('admin', 'admin'), isFalse);
        expect(remove('admin', 'guest'), isFalse);
        expect(remove('admin', 'owner', owners: 2), isFalse);
        expect(remove('owner', 'admin'), isTrue);
        expect(remove('owner', 'guest'), isTrue);
        expect(remove('owner', 'owner', owners: 1), isFalse);
        expect(remove('owner', 'owner', owners: 2), isTrue);
      },
    );

    test('canMessage: guests only with an existing DM', () {
      bool message(String actor, String? target, {bool dm = false}) =>
          canMessageHuman(
            membershipStatus: 'active',
            remoteJoint: false,
            actorRole: actor,
            targetRole: target,
            hasExistingDm: dm,
          );
      expect(message('member', 'member'), isTrue);
      expect(message('guest', 'member'), isFalse);
      expect(message('member', 'guest'), isFalse);
      expect(message('guest', 'member', dm: true), isTrue);
    });

    test('editable roles: guest flag off leaves a guest target uneditable', () {
      List<String> roles(String target, {required bool guest}) =>
          editableHumanServerRoles(
            actorRole: 'admin',
            targetRole: target,
            isSelf: false,
            ownerCount: 1,
            serverGuestEnabled: guest,
          );
      expect(roles('guest', guest: false), isEmpty);
      expect(roles('guest', guest: true), ['admin', 'member']);
      expect(roles('member', guest: false), ['admin']);
      expect(roles('member', guest: true), ['admin', 'guest']);
      expect(
        editableHumanServerRoles(
          actorRole: 'owner',
          targetRole: 'member',
          isSelf: false,
          ownerCount: 1,
          serverGuestEnabled: false,
        ),
        ['owner', 'admin'],
      );
    });

    test('displayName falls back on empty string too', () {
      expect(humanDisplayName({'displayName': '', 'name': 'a'}), 'a');
      expect(humanDisplayName({'displayName': null, 'name': 'a'}), 'a');
      expect(humanDisplayName({'displayName': 'A', 'name': 'a'}), 'A');
    });
  });

  group('human avatar projection (humanAvatar.ts)', () {
    test('legacy provider avatarUrl is ignored, gravatar used', () {
      final p = projectSenderAvatar(
        origin: 'https://fixture.test',
        senderId: me['id'] as String,
        senderType: 'user',
        agents: const [],
        members: [
          {...me, 'userId': me['id']},
        ],
      );
      expect(p.uploadedUrl, isNull);
      expect(
        p.gravatarUrl,
        contains('gravatar.com/avatar/${me['gravatarHash']}'),
      );
    });

    test(
      'uploaded avatar resolves against origin and preempts nothing else',
      () {
        final p = projectSenderAvatar(
          origin: 'https://fixture.test',
          senderId: 'u',
          senderType: 'user',
          agents: const [],
          members: [
            {
              'userId': 'u',
              'avatarUrl': '/api/avatars/users/abc123.webp',
              'gravatarHash': me['gravatarHash'],
            },
          ],
        );
        expect(
          p.uploadedUrl,
          'https://fixture.test/api/avatars/users/abc123.webp',
        );
      },
    );
  });

  group('feature flag client facts (featureFlagClientRules.ts:131-143)', () {
    test('android release build reports os, build number and type', () {
      expect(
        featureFlagClientFacts(
          platform: TargetPlatform.android,
          buildNumber: 6009,
          release: true,
          debug: false,
        ),
        {'os': 'android', 'buildNumber': 6009, 'buildType': 'release'},
      );
    });
    test('ios debug and desktop omit unknown facts', () {
      expect(
        featureFlagClientFacts(
          platform: TargetPlatform.iOS,
          buildNumber: -1,
          release: false,
          debug: true,
        ),
        {'os': 'ios', 'buildType': 'debug'},
      );
      expect(
        featureFlagClientFacts(
          platform: TargetPlatform.linux,
          buildNumber: -1,
          release: false,
          debug: false,
        ),
        isEmpty,
      );
    });
    test('evaluate body: mobile on Android and iOS, web on desktop', () {
      Map<String, Object?> body(TargetPlatform p) => featureFlagEvaluateBody(
        keys: const ['server_guest_v0'],
        serverId: 's',
        platform: p,
        buildNumber: 7,
        release: true,
        debug: false,
      );
      expect(body(TargetPlatform.android)['platform'], 'mobile');
      expect(body(TargetPlatform.iOS)['platform'], 'mobile');
      expect(body(TargetPlatform.macOS)['platform'], 'web');
      expect(body(TargetPlatform.android), {
        'keys': ['server_guest_v0'],
        'serverId': 's',
        'platform': 'mobile',
        'os': 'android',
        'buildNumber': 7,
        'buildType': 'release',
      });
      expect(
        featureFlagEvaluateBody(keys: const ['k']).containsKey('serverId'),
        isFalse,
      );
    });
  });

  test(
    'time format: null preference follows the device (translationStore.ts:271)',
    () {
      expect(
        effectiveTimeFormat(me['preferredTimeFormat'], device24Hour: false),
        '12h',
      );
      expect(effectiveTimeFormat(null, device24Hour: true), '24h');
      expect(effectiveTimeFormat('auto', device24Hour: true), '24h');
      expect(effectiveTimeFormat('12h', device24Hour: true), '12h');
      expect(effectiveTimeFormat('24h', device24Hour: false), '24h');
    },
  );

  group('MemberProfileView', () {
    Finder eyebrow(String label) => find.byWidgetPredicate(
      (w) => w is RaftSectionEyebrow && w.label == label,
    );

    Future<_Workspace> host(
      WidgetTester t,
      Map<String, dynamic> profile, {
      String role = 'owner',
    }) async {
      final client = _Client()..user = RaftRecord({'id': 'me'});
      client.selectServer(currentServer);
      final w = _Workspace(client, profile)
        ..server = RaftRecord({'id': currentServer, 'role': role});
      addTearDown(w.dispose);
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(dark: false),
          home: Scaffold(
            body: MemberProfileView(
              controller: w,
              userId: profile['userId'] as String,
              onClose: () {},
              onMessage: () async {},
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      return w;
    }

    testWidgets(
      'removed member: title falls back to handle, Status badge, no Remove/Message',
      (t) async {
        await host(t, removed);
        expect(find.text('li_wen'), findsWidgets);
        expect(find.text('Status'), findsOneWidget);
        expect(find.text('Removed'), findsOneWidget);
        expect(find.text('Role'), findsNothing);
        expect(find.text('Remove Member'), findsNothing);
        expect(find.byTooltip('Message'), findsNothing);
        expect(find.text('Li Helper'), findsOneWidget);
      },
    );

    testWidgets(
      'channel_summary peer: From label, no Info / Created Agents / Remove',
      (t) async {
        await host(t, summary);
        expect(find.text('Jo Park'), findsWidgets);
        expect(eyebrow('From'), findsOneWidget);
        expect(find.text('Partner Studio'), findsOneWidget);
        expect(eyebrow('Info'), findsNothing);
        expect(find.byType(RaftSectionHeader), findsNothing);
        expect(find.text('No created agents'), findsNothing);
        expect(find.text('Remove Member'), findsNothing);
        expect(find.byTooltip('Message'), findsNothing);
      },
    );

    testWidgets('guest viewer still fetches the channel-scoped profile', (
      t,
    ) async {
      final w = await host(t, summary, role: 'guest');
      expect(
        w.queries,
        contains(
          '/servers/$currentServer/members/${summary['userId']}/profile',
        ),
      );
      expect(find.text('Jo Park'), findsWidgets);
      expect(find.text('Profile unavailable'), findsNothing);
    });

    testWidgets('active member keeps Remove for an owner viewing a member', (
      t,
    ) async {
      await host(t, {
        ...removed,
        'membershipStatus': 'active',
        'role': 'member',
        'displayName': 'Li Wen',
      });
      expect(find.text('Remove Member'), findsOneWidget);
      expect(find.text('Li Wen'), findsWidgets);
    });
  });
}
