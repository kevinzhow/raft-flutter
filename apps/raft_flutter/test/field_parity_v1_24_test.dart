// Field-parity (server v1.24.0 shapes): the new wire fields read from
// test/fixtures/field_parity/v1_24-*.json, and the same readers on the
// v1.21.23 fixtures beside them, which an older server still sends. Fixtures
// only, no real server: every payload names its source in `_source`.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/message_action_card.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show fixture, host;

dynamic _fixture(String name) => jsonDecode(
  File('test/fixtures/field_parity/$name.json').readAsStringSync(),
);
Map<String, dynamic> _map(Object? v) => Map<String, dynamic>.from(v as Map);
List<Map<String, dynamic>> _rows(Object? v) => [
  for (final row in v as List) _map(row),
];

void main() {
  group('v1.24 channels and members', () {
    final body = _map(_fixture('v1_24-channels-and-members'));
    final channels = [for (final c in _rows(body['channels'])) RaftChannel(c)];

    test('a channel row carries its notification level, visitor and external '
        'facts', () {
      final general = channels[0];
      expect(general.notificationLevel, RaftNotificationLevel.mentions);
      expect(general.visitorVisible, isTrue);
      expect(general.hasExternalRelation, isTrue);
      expect(general.loungeAgentId, isNull);
      expect(general.canPost, isTrue);
      expect(channels[2].notificationLevel, RaftNotificationLevel.none);
      // `visitorVisible` decides; the legacy `guestVisible` mirror only when
      // the row has no `visitorVisible` (an older server).
      expect(channels[1].visitorVisible, isFalse);
      expect(channels[3].visitorVisible, isTrue);
    });

    test('an Agent Lounge row and the DM row that names it', () {
      final lounge = channels[1];
      expect(lounge.loungeAgentId, 'a1000000-0000-4000-8000-0000000000aa');
      expect(lounge.canPost, isFalse);
      expect(lounge.notificationLevel, isNull);
      final dm = RaftChannel(_rows(body['dms']).single);
      expect(dm.notificationLevel, RaftNotificationLevel.byDefault);
      expect(dm.lounge, (
        channelId: lounge.id,
        joined: false,
        unreadCount: 3,
        mentionCount: 1,
      ));
    });

    test('a bridged channel says why Slack delivery is held', () {
      final bridge = channels[2].bridge!;
      expect(channels[2].bridgeProvider, 'slack');
      expect(bridge.state, 'paused');
      expect(bridge.stateReason, 'app_removed');
      expect(bridge.outboundStatus, 'waiting');
      expect(bridge.outboundReason, 'invite_app');
      expect(bridge.outboundDetail, 'marker_unconfirmed');
      expect(bridge.outboundSince, DateTime.utc(2026, 11, 13, 15));
      expect(bridge.installState, 'reauth_required');
      expect(channels[0].bridge, isNull);
    });

    test('a joint peer human has no roles and is not of the viewed server', () {
      final humans = _rows(_map(body['channelMembers'])['humans']);
      final own = RaftChannelHumanFields(humans[0]);
      final peer = RaftChannelHumanFields(humans[1]);
      expect(own.serverRole, 'owner');
      expect(own.canRemoveFromChannel, isFalse);
      expect(own.inViewerServer, isTrue);
      expect(peer.role, isNull);
      expect(peer.serverRole, isNull);
      expect(peer.channelRole, isNull);
      expect(peer.canRemoveFromChannel, isTrue);
      expect(peer.inViewerServer, isFalse);
    });

    test('a roster member row names its servers; broken entries drop', () {
      final members = _rows(body['serverMembers']);
      expect(RaftServerMemberFields(members[0]).roster, isNull);
      final roster = RaftServerMemberFields(members[1]).roster!;
      expect(roster.serverSlug, 'acme-partners');
      expect(roster.inViewerServer, isFalse);
      expect(roster.servers, [
        (
          id: 's0000000-0000-4000-8000-000000000002',
          name: 'Acme Partners',
          slug: 'acme-partners',
        ),
      ]);
    });
  });

  group('v1.24 agents and machines', () {
    final body = _map(_fixture('v1_24-agents-and-machines'));
    final agents = [for (final a in _rows(body['agents'])) RaftAgentFields(a)];
    final machines = [
      for (final m in _rows(body['machines'])) RaftMachineFields(m),
    ];

    test('a ready agent from the stack reads as an ordinary member', () {
      final cindy = agents[0];
      expect(cindy.readiness!.ready, isTrue);
      expect(cindy.readiness!.primary, isNull);
      expect(cindy.blockedReason, isNull);
      expect(cindy.personalAssistant, isFalse);
      expect(cindy.inMemberLists, isTrue);
      expect(cindy.lastRuntimeError, isNull);
      expect(cindy.modelDefaultsReported, isNull);
    });

    test('a blocked agent names the broken link, its owner and the fix', () {
      final builder = agents[1];
      expect(builder.blockedReason, 'computer_version_unsupported');
      final readiness = builder.readiness!;
      expect(readiness.state, 'blocked');
      expect(readiness.primary!.resourceKind, 'computer');
      expect(readiness.primary!.code, 'computer_too_old');
      expect(readiness.primary!.behaviour, 'blocked');
      expect(readiness.primary!.params, {'managedByDesktop': false});
      expect(
        readiness.primary!.since,
        DateTime.fromMillisecondsSinceEpoch(1794578465733, isUtc: true),
      );
      expect(
        (readiness.scope, readiness.actor, readiness.action),
        ('computer', 'computer_owner', 'update_computer'),
      );
      expect(readiness.actorName, 'Alice');
      // A code this build does not know is kept; its behaviour decides.
      expect(readiness.also.single.code, 'a_code_from_the_future');
      expect(readiness.also.single.resource, {
        'kind': 'runtime',
        'runtime': 'codex',
      });
      expect(readiness.also.single.until, isNotNull);
      expect(builder.modelDefaultsReported, isTrue);
      final error = builder.lastRuntimeError!;
      expect(error.code, 'usage_limit');
      expect(error.requiredAction, 'user_reauth');
      expect(error.actionRequired, isTrue);
      expect(error.clientSeq, 42);
      expect(error.occurrenceId, isNotNull);
      expect(error.daemonInstanceId, 'daemon-1');
      expect(error.recoveryLaunchId, 'launch-2');
      expect(error.at, DateTime.utc(2026, 11, 13, 15));
    });

    test('a personal assistant and an App Bot stay out of member lists', () {
      final assistant = agents[2];
      expect(assistant.personalAssistant, isTrue);
      expect(assistant.inMemberLists, isFalse);
      expect(assistant.assistantPausedAt, DateTime.utc(2026, 11, 13, 16));
      expect(assistant.assistantPausedBy, (
        id: 'u1000000-0000-4000-8000-0000000000c1',
        name: 'Alice',
      ));
      final bot = agents[3];
      expect(bot.inMemberLists, isFalse);
      expect(bot.managedByAppInstallId, isNotNull);
      expect(bot.managedByApp!.name, 'Linear');
      expect(bot.managedByApp!.botStatusText, 'Syncing issues');
      expect(bot.managedByApp!.description, isNull);
      // An unknown runtime error code is no code (the generic sentence).
      expect(bot.lastRuntimeError!.code, isNull);
      expect(bot.lastRuntimeError!.message, 'Agent encountered an error');
    });

    test('a machine row: owner, host facts, readiness per runtime', () {
      final dev = machines[0];
      expect(dev.ownerUserId, isNull);
      expect(dev.owner, isNull);
      expect(dev.userId, 'u1000000-0000-4000-8000-0000000000c1');
      expect(dev.deviceClass, 'desktop');
      expect(dev.osRelease, 'Ubuntu 26.04');
      expect(dev.hostProvider, isNull);
      expect(dev.memoryStatus, (
        availableBytes: 48795996160,
        totalBytes: 92600377344,
      ));
      expect(dev.readiness!.runtimes.keys, ['claude', 'codex']);
      expect(dev.readiness!.runtimes['codex']!.ready, isTrue);
      expect(dev.attention, (count: 0, waitingAgents: 0, waitingUntil: null));
      expect(dev.versionGate, isNull);

      final laptop = machines[1];
      expect(laptop.owner!.name, 'Alice');
      expect(laptop.hostProvider, 'aws_ec2');
      expect(laptop.sameMachineGroup, 'machine-1');
      expect(laptop.credentialExposureFoundAt, isNotNull);
      // available > total is not a memory report (isValidMachineDiskStatus).
      expect(laptop.memoryStatus, isNull);
      expect(laptop.installerRepairHint, 'unrecovered_operation');
      expect(laptop.versionGate!.enforced, isTrue);
      expect(laptop.versionGate!.minVersion, '0.0.40');
      expect(laptop.readiness!.runtimes['codex']!.state, 'blocked');
      expect(laptop.attention!.waitingAgents, 1);
      expect(laptop.attention!.waitingUntil, isNotNull);
    });
  });

  group('v1.24 tasks, threads and messages', () {
    final body = _map(_fixture('v1_24-tasks-and-messages'));

    test('a server task summary row carries its source and activity', () {
      final row = RaftTaskFields(
        _rows(_map(body['serverTasks'])['tasks']).single,
      );
      expect(row.sourceMessageId, 'm2000000-0000-4000-8000-000000000001');
      expect(row.sourceRecorded, isTrue);
      expect(row.sourceSenderType, 'user');
      expect(row.conversationReplyCount, 0);
      expect(row.activityAt, DateTime.utc(2026, 11, 13, 15, 20));
      expect(row.conversationFollowed, isNull);
    });

    test('a task v2 task names its own conversation', () {
      final task = RaftTaskFields(_map(body['channelTask']));
      expect(
        task.conversationChannelId,
        'c3000000-0000-4000-8000-000000000017',
      );
      expect(task.conversationAnchored, isTrue);
      expect(task.conversationFollowed, isTrue);
      expect(task.conversationReplyCount, 4);
      expect(task.hostMessageId, isNull);
      expect(task.sourceRecorded, isFalse);
      expect(task.createdByHandle, 'cindy');
      // No lastActivityAt yet: Web falls back to updatedAt.
      expect(task.activityAt, DateTime.utc(2026, 11, 13, 15, 30));
    });

    test('a followed task conversation is told apart from a thread', () {
      final rows = [
        for (final t in _rows(body['followedThreads']))
          RaftFollowedThreadFields(t),
      ];
      expect(rows[0].conversationKind, 'thread');
      expect(rows[0].parentInHistory, isTrue);
      expect(rows[0].repliesInHistory, isFalse);
      expect(rows[0].notificationLevel, isNull);
      expect(rows[1].conversationKind, 'task');
      expect(rows[1].taskTitle, 'Task v2 conversation');
      expect(rows[1].notificationLevel, RaftNotificationLevel.all);
      expect(rows[1].sourceMessageId, isNull);
    });

    test('messages: edit time, retraction, task info, card and author', () {
      final messages = _rows(body['messages']);
      final plain = RaftMessage(messages[0]);
      expect(plain.updatedAt, DateTime.utc(2026, 11, 13, 15, 31));
      expect(plain.deletedAt, isNull);
      expect(plain.retracted, isFalse);
      final retracted = RaftMessage(messages[1]);
      expect(retracted.retracted, isTrue);
      expect(retracted.deletedAt, DateTime.utc(2026, 11, 13, 15, 40));

      final info = RaftTaskFields(_map(messages[2]['taskInfo']));
      expect(info.sourceMessageId, plain.id);
      expect(info.conversationAnchored, isTrue);
      expect(info.conversationReplyCount, 4);

      final card = RaftActionCardFields(_map(messages[2]['actionMetadata']));
      expect(card.actionType, 'seats:add');
      expect(card.requesterUserId, 'u2000000-0000-4000-8000-0000000000c2');
      expect(card.requesterAgentId, isNull);
      expect(card.seatOutcomeKind, 'invites');
      expect(card.seatOutcomeJson!['sent'], 2);
      expect(card.expiresAt, DateTime.utc(2026, 11, 20, 15, 33));
      expect(card.withdrawnAt, isNull);
      expect(card.presentationCard!['format'], 'action-card.v1');

      final author = RaftExternalAuthorFields(
        _map(messages[3]['externalAuthor']),
      );
      expect(author.identityKind, 'provider_actor');
      expect(author.profileDisplayName, 'Deploy Bot');
      expect(author.profileAvatarUrl, '/api/external-avatars/abc');
      expect(author.appName, 'Deployer');
      expect(author.profileUnresolved, isTrue);
    });

    testWidgets('a v1.24 card type this client has no renderer for draws the '
        'generic card and fails closed', (t) async {
      final (w, _) = (await t.runAsync(() => fixture('owner')))!;
      addTearDown(w.dispose);
      final message = _map(_rows(body['messages'])[2]);
      final card = _map(message['actionMetadata']);
      await t.pumpWidget(
        host(
          MessageActionCard(
            controller: w,
            message: RaftMessage({
              ...message,
              'channelId': 'c1',
              // The fixture server of `fixture('owner')`, so not read-only.
              'actionMetadata': {...card, 'sourceServerId': w.server?.id},
            }),
          ),
        ),
      );
      final drawn = t.widget<RaftActionCard>(find.byType(RaftActionCard));
      expect(drawn.title, 'Add 2 seats');
      expect(drawn.details, [(label: 'Seats', value: '2')]);
      expect(drawn.blockedReason, 'This action needs a newer client.');
    });
  });

  group('v1.24 account and servers', () {
    final body = _map(_fixture('v1_24-account-and-servers'));

    test('the user record: send key, rail order, shortcuts', () {
      final user = RaftUserFields(_map(body['user']));
      expect(user.composerSendKey, 'mod_enter');
      expect(user.railTabOrder, ['home', 'activity', 'tasks']);
      // A combo without a key is not a shortcut.
      expect(user.shortcutOverrides, {
        'search.open': [
          (key: 'K', mod: true, ctrl: false, alt: false, shift: false),
          (key: '/', mod: false, ctrl: false, alt: false, shift: true),
        ],
      });
      expect(user.assistantOtterShortcut, 'Mod+Shift+O');
      expect(user.usedDesktopAppRecently, isFalse);
    });

    test('a server row: the member theme and its decor', () {
      final servers = [
        for (final s in _rows(body['servers'])) RaftServerFields(s),
      ];
      expect(servers[0].theme, isNull);
      expect(servers[0].themeDecor, isTrue);
      expect(servers[1].theme, 'space');
      expect(servers[1].themeDecor, isFalse);
      // An id this build does not know is Raft Yellow.
      expect(servers[2].theme, isNull);
    });

    test('billing entitlement: AppSumo and prepaid Pro time', () {
      final billing = RaftBillingEntitlementFields(_map(body['billing']));
      expect(billing.appsumoTier, 'tier2');
      expect(billing.prepaid, (
        endsAt: DateTime.utc(2027, 2),
        graceEndsAt: DateTime.utc(2027, 2, 15),
        inGrace: false,
        seatQuantity: 5,
      ));
    });

    test('client config keeps hostnames and a local embed origin only', () {
      final config = RaftClientConfig.fromJson(body['clientConfig']);
      expect(config.appHosts, ['app.raft.build', 'localhost']);
      expect(config.privacyMode, isFalse);
      expect(config.artifactsEmbedOrigin, 'http://artifacts.localhost:18787');
    });
  });

  group('older servers (the v1.21.23 fixtures) read as Web reads them', () {
    test(
      'channels: default level, no Lounge, may post, guestVisible mirror',
      () {
        for (final row in _rows(_fixture('channels-list-regular-and-joint'))) {
          final c = RaftChannel(row);
          expect(c.notificationLevel, isNull);
          expect(c.loungeAgentId, isNull);
          expect(c.lounge, isNull);
          expect(c.canPost, isTrue);
          expect(c.hasExternalRelation, isNull);
          expect(c.visitorVisible, row['guestVisible'] == true);
        }
      },
    );

    test('roster humans: roles kept, no removal or viewer-server verdict', () {
      final body = _map(_fixture('channels-members-roster-joint'));
      for (final row in _rows(body['humans'])) {
        final h = RaftChannelHumanFields(row);
        expect(h.serverRole, row['serverRole']);
        expect(h.canRemoveFromChannel, isNull);
        expect(h.inViewerServer, isNull);
      }
    });

    test('agents and machines: ready-less, owner-less, nothing blocked', () {
      for (final row in _rows(_fixture('agents-list-managed-agent'))) {
        final a = RaftAgentFields(row);
        expect(a.readiness, isNull);
        expect(a.blockedReason, isNull);
        expect(a.personalAssistant, isFalse);
        expect(a.inMemberLists, row['deletedAt'] == null);
        expect(a.managedByApp, isNull);
      }
      final machines = _map(_fixture('agents-machines-list'))['machines'];
      for (final row in _rows(machines)) {
        final m = RaftMachineFields(row);
        expect(m.ownerUserId, isNull);
        expect(m.readiness, isNull);
        expect(m.attention, isNull);
        expect(m.versionGate, isNull);
        expect(m.memoryStatus, isNull);
      }
    });

    test('tasks, followed threads and messages: no v2 conversation facts', () {
      final page = _map(_fixture('tasks-server-tasks-summary-page'));
      for (final row in _rows(page['tasks'])) {
        final t = RaftTaskFields(row);
        expect(t.conversationChannelId, isNull);
        expect(t.conversationAnchored, isFalse);
        expect(t.conversationFollowed, isNull);
        expect(t.activityAt, isNotNull);
      }
      final followed = _map(_fixture('channels-followed-threads-paged'));
      for (final row in _rows(
        _map(followed['unpaged (no limit)'])['threads'],
      )) {
        final f = RaftFollowedThreadFields(row);
        expect(f.conversationKind, 'thread');
        expect(f.parentInHistory, isNull);
        expect(f.notificationLevel, isNull);
      }
      final card = _map(_fixture('messages-action-card-null-source'));
      final fields = RaftActionCardFields(_map(card['actionMetadata']));
      expect(fields.requesterUserId, isNull);
      expect(fields.seatOutcomeKind, isNull);
      expect(fields.expiresAt, isNull);
      expect(fields.presentationCard, isNull);
      expect(RaftMessage(card).retracted, isFalse);
      final external = _map(_fixture('messages-external-projection'));
      final author = RaftExternalAuthorFields(_map(external['externalAuthor']));
      expect(author.identityKind, 'provider_actor');
      expect(author.profileDisplayName, isNull);
      expect(author.profileUnresolved, isFalse);
    });

    test('account, servers and billing: defaults', () {
      final user = RaftUserFields(_map(_fixture('members-auth-me')));
      expect(user.composerSendKey, 'enter');
      expect(user.railTabOrder, isNull);
      expect(user.shortcutOverrides, isNull);
      for (final row in _rows(_fixture('members-servers-list'))) {
        expect(RaftServerFields(row).theme, isNull);
        expect(RaftServerFields(row).themeDecor, isFalse);
      }
      final billing = RaftBillingEntitlementFields(
        _map(_fixture('members-billing-subscription-pro')),
      );
      expect(billing.appsumoTier, isNull);
      expect(billing.prepaid, isNull);
      // An older server has no client config route: the fallback.
      expect(RaftClientConfig.fromJson(null).appHosts, isNull);
      expect(RaftClientConfig.fromJson(null).artifactsEmbedOrigin, isNull);
    });
  });
}
