// WP8 (v1.21.12): Slack members in the channel overflow strip, joint-invite
// error mapping, joint roster server badges, the profile "From" label, and how
// the member pickers surface the server's refusal to put a personal assistant
// in a channel. Each case fails on the code before the port.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/add_members_dialog.dart';
import 'package:raft_flutter/features/channel_member_servers.dart';
import 'package:raft_flutter/features/channel_members.dart';
import 'package:raft_flutter/features/channel_settings.dart';
import 'package:raft_flutter/features/create_joint_channel_dialog.dart';
import 'package:raft_flutter/features/joint_invite_errors.dart';
import 'package:raft_flutter/features/member_profile_rules.dart';
import 'package:raft_flutter/features/member_profile_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'joint_channel_views_test.dart' show fixture;

const _caps = {
  'editChannelMetadata': true,
  'addChannelMembers': true,
  'removeChannelMembers': true,
  'changeChannelMemberRoles': true,
};

Map<String, dynamic> _row({String type = 'channel'}) => {
  'id': 'c1',
  'name': 'work',
  'type': type,
  'serverId': 's1',
  'joined': true,
  'channelCapabilities': _caps,
};

Widget _app(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
  locale: locale,
  supportedLocales: const [Locale('en'), Locale('zh')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  theme: raftTheme(RaftFamily.elegant),
  home: Scaffold(body: child),
);

void _settingsRoutes(dynamic api, Map<String, dynamic> roster) {
  api.routes['GET /channels/c1/members'] = (_) => roster;
  api.routes['GET /servers/s1/sidebar-order'] = (_) => {'pinned': []};
  api.routes['GET /channels/c1/message-display-settings'] = (_) => {
    'collapseLongMessages': true,
  };
  api.routes['GET /channels/c1/notification-settings'] = (_) => {
    'activityMuted': false,
  };
  api.routes['POST /feature-flags/evaluate'] = (_) => {'evaluations': []};
}

final _roster = {
  'humans': [
    {'id': 'u1', 'userId': 'u1', 'name': 'ana', 'displayName': 'Ana'},
  ],
  'agents': [
    {'id': 'a1', 'name': 'cindy', 'displayName': 'Cindy'},
  ],
  'externalMembers': [
    {
      'id': 'x1',
      'provider': 'slack',
      'displayName': 'Sam',
      'handles': ['sam'],
      'avatarUrl': null,
    },
    {
      'id': 'x2',
      'provider': 'slack',
      'displayName': 'Kim',
      'handles': <String>[],
      'avatarUrl': null,
    },
  ],
};

void main() {
  group('joint-invite error details (client allow-list)', () {
    test('keeps the target slug and the invitee, drops everything else', () {
      final error = RaftApiException.response(
        'No one matching @bob',
        status: 400,
        body: {
          'error': 'No one matching @bob',
          'code': 'joint_invitee_not_found',
          'targetServerSlug': 'acme',
          'invitee': '@bob',
          'inviteeIndex': 0,
          'stack': 'boom',
        },
      );
      expect(error.details, {
        'code': 'joint_invitee_not_found',
        'targetServerSlug': 'acme',
        'invitee': '@bob',
      });
    });

    test('a non-string slug or invitee is never exposed', () {
      final error = RaftApiException.response(
        'x',
        status: 400,
        body: {
          'error': 'x',
          'code': 'joint_invitee_not_admin',
          'targetServerSlug': {'a': 1},
          'invitee': 7,
        },
      );
      expect(error.details['targetServerSlug'], isNull);
      expect(error.details['invitee'], isNull);
    });
  });

  group('describeJointInviteError (CreateJointChannelDialog.tsx)', () {
    String format(String source, Map<String, Object?> values) =>
        source.replaceAllMapped(
          RegExp(r'\{(\w+)\}'),
          (m) => '${values[m[1]] ?? m[0]}',
        );
    String? describe(Map<String, dynamic> details, [String? current]) =>
        describeJointInviteError(details, current, format);

    test('invitee not found / not admin name the server and the invitee', () {
      expect(
        describe({
          'code': 'joint_invitee_not_found',
          'targetServerSlug': 'acme',
          'invitee': '@bob',
        }),
        'No one matching @bob was found on server "acme". Check the handle or email.',
      );
      expect(
        describe({
          'code': 'joint_invitee_not_admin',
          'targetServerSlug': 'acme',
          'invitee': 'bob@acme.test',
        }),
        'bob@acme.test must be an owner or admin of server "acme" to be invited.',
      );
    });

    test('an invitee code without its slug or invitee is not described', () {
      expect(
        describe({'code': 'joint_invitee_not_found', 'invitee': '@bob'}),
        isNull,
      );
      expect(
        describe({'code': 'joint_invitee_not_admin', 'targetServerSlug': 'a'}),
        isNull,
      );
    });

    test('target_server_invalid: only the slug tells the two causes apart', () {
      const body = {
        'code': 'joint_target_server_invalid',
        'targetServerSlug': 'home',
      };
      expect(
        describe(body, 'home'),
        "You can't invite this server to its own joint channel.",
      );
      expect(
        describe(body, 'other'),
        'Server "home" wasn\'t found. Check the slug.',
      );
      expect(describe(body), 'Server "home" wasn\'t found. Check the slug.');
      expect(describe({'code': 'joint_target_server_invalid'}, 'home'), isNull);
    });

    test('invite_required, and anything else falls through', () {
      expect(
        describe({'code': 'joint_invite_required'}),
        'At least one invited person is required',
      );
      expect(describe({'code': 'joint_server_limit'}), isNull);
      expect(describe(const {}), isNull);
    });
  });

  group('server badge labels (memberServerBadgeLabels)', () {
    const home = {'id': 's1', 'name': 'Home', 'slug': 'home'};
    const acme = {'id': 's2', 'name': 'Acme Partners', 'slug': 'acme'};

    test('a person on both sides lists both servers, viewer first', () {
      expect(
        memberServerBadgeLabels({
          'serverId': 's2',
          'servers': [home, acme],
        }, 's1'),
        ['Home', 'Acme Partners'],
      );
    });

    test('purely local members get no badge', () {
      expect(
        memberServerBadgeLabels({
          'servers': [home],
        }, 's1'),
        isEmpty,
      );
      expect(memberServerBadgeLabels({'serverId': 's1'}, 's1'), isEmpty);
      expect(memberServerBadgeLabels(const {}, 's1'), isEmpty);
      expect(
        memberServerBadgeLabels({
          'servers': [acme],
        }, null),
        isEmpty,
      );
    });

    test(
      'falls back to serverId / serverName / serverSlug without servers',
      () {
        expect(
          memberServerBadgeLabels({
            'serverId': 's2',
            'serverName': 'Acme Partners',
          }, 's1'),
          ['Acme Partners'],
        );
        expect(
          memberServerBadgeLabels({
            'serverId': 's2',
            'serverName': null,
            'serverSlug': 'acme',
          }, 's1'),
          ['acme'],
        );
        expect(
          memberServerBadgeLabels({
            'servers': [
              {'id': 's2', 'name': '', 'slug': 'acme'},
              {'id': 's3', 'name': '', 'slug': ''},
            ],
          }, 's1'),
          ['acme'],
        );
      },
    );

    test('the profile From line joins every server', () {
      expect(
        humanSourceServerLabel({
          'serverId': 's2',
          'servers': [home, acme],
        }, 's1'),
        'Home, Acme Partners',
      );
      expect(
        humanSourceServerLabel({
          'servers': [home],
        }, 's1'),
        isNull,
      );
    });

    test('only joint channels badge their rows', () {
      final member = {
        'serverId': 's2',
        'servers': [acme],
      };
      expect(
        channelMemberServerLabels(member, RaftChannel(_row(type: 'joint'))),
        ['Acme Partners'],
      );
      expect(channelMemberServerLabels(member, RaftChannel(_row())), isEmpty);
    });
  });

  group('CreateJointChannelDialog maps the typed invite rejections', () {
    Future<void> submit(
      WidgetTester t, {
      required Object error,
      String? currentSlug,
      Locale locale = const Locale('en'),
    }) async {
      t.view.physicalSize = const Size(1280, 2400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        _app(
          CreateJointChannelDialog(
            agents: const [],
            users: const [],
            currentServerSlug: currentSlug,
            onCreate: (_) async => throw error,
            onUnarchive: (_) async => {},
          ),
          locale: locale,
        ),
      );
      await t.enterText(find.byKey(const ValueKey('joint-name')), 'launch');
      await t.enterText(find.byKey(const ValueKey('joint-slug-0')), 'acme');
      await t.enterText(find.byKey(const ValueKey('joint-people-0')), '@bob');
      await t.tap(find.byKey(const ValueKey('joint-create-submit')));
      await t.pumpAndSettle();
    }

    RaftApiException rejection(Map<String, dynamic> body) =>
        RaftApiException.response(
          'English only server sentence',
          status: 400,
          body: {'error': 'English only server sentence', ...body},
        );

    testWidgets('invitee not found names invitee and server', (t) async {
      await submit(
        t,
        error: rejection({
          'code': 'joint_invitee_not_found',
          'targetServerSlug': 'acme',
          'invitee': '@bob',
        }),
      );
      expect(
        find.text(
          'No one matching @bob was found on server "acme". Check the handle or email.',
        ),
        findsOneWidget,
      );
      expect(find.text('English only server sentence'), findsNothing);
    });

    testWidgets('invitee not found in Chinese uses the Web catalog', (t) async {
      await submit(
        t,
        locale: const Locale('zh'),
        error: rejection({
          'code': 'joint_invitee_not_found',
          'targetServerSlug': 'acme',
          'invitee': '@bob',
        }),
      );
      expect(find.text('在服务器「acme」中找不到 @bob，请检查 handle 或邮箱。'), findsOneWidget);
    });

    testWidgets('not admin', (t) async {
      await submit(
        t,
        error: rejection({
          'code': 'joint_invitee_not_admin',
          'targetServerSlug': 'acme',
          'invitee': '@bob',
        }),
      );
      expect(
        find.text(
          '@bob must be an owner or admin of server "acme" to be invited.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('inviting the open server is "its own joint channel"', (
      t,
    ) async {
      await submit(
        t,
        currentSlug: 'acme',
        error: rejection({
          'code': 'joint_target_server_invalid',
          'targetServerSlug': 'acme',
        }),
      );
      expect(
        find.text("You can't invite this server to its own joint channel."),
        findsOneWidget,
      );
    });

    testWidgets('any other unknown slug is "wasn\'t found"', (t) async {
      await submit(
        t,
        currentSlug: 'home',
        error: rejection({
          'code': 'joint_target_server_invalid',
          'targetServerSlug': 'acme',
        }),
      );
      expect(
        find.text('Server "acme" wasn\'t found. Check the slug.'),
        findsOneWidget,
      );
    });

    testWidgets('an unrecognised rejection keeps the server text', (t) async {
      await submit(t, error: rejection({'code': 'something_else'}));
      expect(find.text('English only server sentence'), findsOneWidget);
    });
  });

  group('channel overflow strip counts Slack members', () {
    Future<void> open(
      WidgetTester t,
      Map<String, dynamic> roster, {
      Locale locale = const Locale('en'),
    }) async {
      final (w, api) = (await t.runAsync(() => fixture('member')))!;
      addTearDown(w.dispose);
      final channel = RaftChannel(_row());
      w.channels = [channel];
      _settingsRoutes(api, roster);
      t.view.physicalSize = const Size(1280, 1800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        _app(
          ChannelSettings(controller: w, channel: channel, isPanel: true),
          locale: locale,
        ),
      );
      await t.pumpAndSettle();
    }

    testWidgets('summary adds "· {n} Slack" and each Slack tile is labelled', (
      t,
    ) async {
      await open(t, _roster);
      expect(find.text('1 human · 1 agent · 2 Slack'), findsOneWidget);
      expect(find.bySemanticsLabel('Sam (Slack)'), findsOneWidget);
      expect(find.bySemanticsLabel('Kim (Slack)'), findsOneWidget);
      // Raft members keep their own plain labels.
      expect(find.bySemanticsLabel('Ana'), findsOneWidget);
    });

    testWidgets('a channel with no Slack participants keeps the old line', (
      t,
    ) async {
      await open(t, {..._roster, 'externalMembers': <dynamic>[]});
      expect(find.text('1 human · 1 agent'), findsOneWidget);
      expect(find.textContaining('Slack'), findsNothing);
    });

    testWidgets('an older server without externalMembers still loads', (
      t,
    ) async {
      await open(t, {'humans': _roster['humans'], 'agents': _roster['agents']});
      expect(find.text('1 human · 1 agent'), findsOneWidget);
    });

    testWidgets('Chinese summary and tile label come from the Web catalog', (
      t,
    ) async {
      await open(t, _roster, locale: const Locale('zh'));
      expect(find.text('1 位人类 · 1 个 Agent · 2 位 Slack 成员'), findsOneWidget);
      expect(find.bySemanticsLabel('Sam（Slack）'), findsOneWidget);
    });
  });

  group('joint roster server badges', () {
    final roster = {
      'humans': [
        {
          'id': 'u1',
          'userId': 'u1',
          'name': 'ana',
          'displayName': 'Ana',
          'serverId': 's1',
        },
        {
          'id': 'u2',
          'userId': 'u2',
          'name': 'pat',
          'displayName': 'Pat',
          'serverId': 's2',
          'servers': [
            {'id': 's1', 'name': 'Home', 'slug': 'home'},
            {'id': 's2', 'name': 'Acme Partners', 'slug': 'acme'},
          ],
        },
      ],
      'agents': [
        {
          'id': 'a2',
          'name': 'acme-bot',
          'displayName': 'Acme Bot',
          'serverId': 's2',
          'serverName': 'Acme Partners',
        },
      ],
    };

    Future<void> openPage(WidgetTester t, String type) async {
      final (w, api) = (await t.runAsync(() => fixture('owner')))!;
      addTearDown(w.dispose);
      final channel = RaftChannel(_row(type: type));
      w.channels = [channel];
      api.routes['GET /channels/c1/members'] = (_) => roster;
      api.routes['POST /feature-flags/evaluate'] = (_) => {'evaluations': []};
      t.view.physicalSize = const Size(1280, 1800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        _app(
          ChannelMembers(
            controller: w,
            channel: channel,
            page: true,
            onClose: () {},
          ),
        ),
      );
      await t.pumpAndSettle();
    }

    testWidgets('a person on both sides shows both servers; locals none', (
      t,
    ) async {
      await openPage(t, 'joint');
      final pat = find.byKey(const ValueKey('member-page-row-human-u2'));
      expect(
        find.descendant(of: pat, matching: find.text('Home')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: pat, matching: find.text('Acme Partners')),
        findsOneWidget,
      );
      final ana = find.byKey(const ValueKey('member-page-row-human-u1'));
      expect(
        find.descendant(
          of: ana,
          matching: find.byKey(const ValueKey('member-server-badges')),
        ),
        findsNothing,
      );
      final bot = find.byKey(const ValueKey('member-page-row-agent-a2'));
      expect(
        find.descendant(of: bot, matching: find.text('Acme Partners')),
        findsOneWidget,
      );
    });

    testWidgets('an ordinary channel never shows server badges', (t) async {
      await openPage(t, 'channel');
      expect(find.byKey(const ValueKey('member-server-badges')), findsNothing);
      expect(find.text('Acme Partners'), findsNothing);
    });
  });

  group('profile From line', () {
    Future<void> openProfile(
      WidgetTester t, {
      Map<String, dynamic>? primeServers,
      Map<String, dynamic> profile = const {},
    }) async {
      final (w, api) = (await t.runAsync(() => fixture('owner')))!;
      addTearDown(w.dispose);
      api.routes['GET /servers/s1/members/u2/profile'] = (_) => {
        'userId': 'u2',
        'name': 'pat',
        'displayName': 'Pat',
        'serverId': 's2',
        'serverName': 'Acme Partners',
        'profileProjection': 'channel_summary',
        'membershipStatus': 'active',
        'createdAgents': <dynamic>[],
        ...profile,
      };
      if (primeServers != null) {
        primeHumanProfileServers(w, 's1', 'u2', primeServers['servers']);
      }
      t.view.physicalSize = const Size(1280, 1800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        _app(
          MemberProfileView(
            controller: w,
            userId: 'u2',
            onClose: () {},
            onMessage: () async {},
          ),
        ),
      );
      await t.pumpAndSettle();
    }

    const both = [
      {'id': 's1', 'name': 'Home', 'slug': 'home'},
      {'id': 's2', 'name': 'Acme Partners', 'slug': 'acme'},
    ];

    testWidgets('the profile route lists every server', (t) async {
      await openProfile(t, profile: {'servers': both});
      expect(find.text('Home, Acme Partners'), findsOneWidget);
    });

    testWidgets('servers primed from the roster row survive the fetch', (
      t,
    ) async {
      await openProfile(t, primeServers: {'servers': both});
      expect(find.text('Home, Acme Partners'), findsOneWidget);
    });

    testWidgets('without a servers list it is the single partner server', (
      t,
    ) async {
      await openProfile(t);
      expect(find.text('Acme Partners'), findsOneWidget);
    });
  });

  group('personal assistants are refused by the server, like Web', () {
    const refusal = 'A personal assistant can only be in its DM with its owner';
    final adminBody = {'error': refusal, 'code': 'assistant_channel_forbidden'};

    testWidgets(
      'the members add view keeps the rows and says none were added',
      (t) async {
        final (w, api) = (await t.runAsync(() => fixture('owner')))!;
        addTearDown(w.dispose);
        final channel = RaftChannel(_row());
        w.channels = [channel];
        api.routes['GET /channels/c1/members'] = (_) => {
          'humans': <dynamic>[],
          'agents': <dynamic>[],
        };
        api.routes['GET /agents'] = (_) => [
          {'id': 'asst', 'name': 'helper', 'displayName': 'Helper'},
        ];
        api.routes['POST /feature-flags/evaluate'] = (_) => {'evaluations': []};
        api.routes['POST /channels/c1/members/batch'] = (_) => adminBody;
        api.statuses['POST /channels/c1/members/batch'] = 403;
        t.view.physicalSize = const Size(1280, 1800);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await t.pumpWidget(
          _app(
            ChannelMembers(controller: w, channel: channel, startInAdd: true),
          ),
        );
        await t.pumpAndSettle();
        await t.tap(find.byKey(const ValueKey('add-candidate-agent:asst')));
        await t.pump();
        await t.tap(find.byKey(const ValueKey('add-member-confirm')));
        await t.pumpAndSettle();
        expect(
          find.text('None of the selected members could be added.'),
          findsOneWidget,
        );
        // The request was the one atomic batch, and the row stays selected.
        expect(
          api.calls
              .where((c) => c.path == '/channels/c1/members/batch')
              .single
              .data,
          {
            'userIds': <dynamic>[],
            'agentIds': ['asst'],
          },
        );
        expect(
          find.byKey(const ValueKey('add-member-confirm')),
          findsOneWidget,
        );
      },
    );

    testWidgets('the add dialog shows the server sentence verbatim', (t) async {
      final (w, api) = (await t.runAsync(() => fixture('owner')))!;
      addTearDown(w.dispose);
      final channel = RaftChannel(_row());
      w.channels = [channel];
      api.routes['GET /channels/c1/members'] = (_) => {
        'humans': <dynamic>[],
        'agents': <dynamic>[],
      };
      api.routes['POST /channels/c1/members/batch'] = (_) => adminBody;
      api.statuses['POST /channels/c1/members/batch'] = 403;
      t.view.physicalSize = const Size(1280, 1800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        _app(
          AddMembersDialog(
            controller: w,
            channelId: 'c1',
            prefilledAgentIds: const ['a1'],
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('add-members-submit')));
      await t.pumpAndSettle();
      expect(find.text(refusal), findsOneWidget);
    });
  });
}
