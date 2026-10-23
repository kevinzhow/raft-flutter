// Joint channel settings (Web EditChannelDialog `channel-settings-joint-section`):
// connected servers, Resend Invite, the invitation form with the RFC 075
// same-admin direct connection, and Disconnect instead of Delete.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/channel_settings.dart';
import 'package:raft_flutter/features/joint_same_admin.dart';
import 'package:raft_ui/raft_ui.dart';

import 'support/joint_channel_fixture.dart' show fixture;

Map<String, dynamic> jointChannel({
  bool federate = true,
  bool archived = false,
  List<Map<String, dynamic>>? servers,
  List<Map<String, dynamic>>? pending,
}) => {
  'id': 'c1',
  'serverId': 's1',
  'name': 'partners',
  'type': 'joint',
  'joined': true,
  'archivedAt': archived ? '2026-10-01T00:00:00.000Z' : null,
  'channelCapabilities': {
    'editChannelMetadata': true,
    'archiveChannels': true,
    'deleteChannels': true,
    'federateChannels': federate,
    'addChannelMembers': true,
  },
  'jointServers':
      servers ??
      [
        {
          'serverId': 's1',
          'serverName': 'Visual Server',
          'serverSlug': 'visual',
          'status': 'active',
          'isCurrentServer': true,
          'plan': 'free',
        },
        {
          'serverId': 's2',
          'serverName': 'Acme Partners',
          'serverSlug': 'acme-partners',
          'status': 'active',
          'plan': 'paid',
        },
        {
          'serverId': 's3',
          'serverName': 'Globex',
          'serverSlug': 'globex',
          'status': 'pending',
          'plan': 'free',
        },
      ],
  'jointPendingInvites':
      pending ??
      [
        {'id': 'i1', 'fromServerId': 's1', 'serverSlug': 'globex'},
      ],
};

void main() {
  Finder key(String value) => find.byKey(ValueKey(value));
  String slugText(WidgetTester t) => t
      .widget<TextField>(
        find.descendant(
          of: key('channel-settings-joint-server-slug'),
          matching: find.byType(TextField),
        ),
      )
      .controller!
      .text;
  Future<(WorkspaceController, dynamic)> mount(
    WidgetTester t,
    Map<String, dynamic> row, {
    String role = 'owner',
    List<RaftRecord> servers = const [],
  }) async {
    final (w, api) = (await t.runAsync(() => fixture(role)))!;
    addTearDown(w.dispose);
    w.client.user = RaftRecord({
      'id': 'alice',
      'name': 'alice',
      'email': 'Alice@Example.com',
    });
    w.servers = servers;
    w.server = RaftRecord({
      'id': 's1',
      'slug': 'visual',
      'name': 'Visual Server',
      'role': role,
    });
    final channel = RaftChannel(row);
    w.channels = [channel];
    api.routes['GET /channels/c1/members'] = (_) => {
      'humans': [],
      'agents': [],
    };
    api.routes['GET /servers/s1/sidebar-order'] = (_) => {'pinned': []};
    api.routes['GET /channels/c1/message-display-settings'] = (_) => {
      'collapseLongMessages': true,
    };
    api.routes['GET /channels/c1/notification-settings'] = (_) => {
      'activityMuted': false,
    };
    api.routes['POST /feature-flags/evaluate'] = (_) => {'evaluations': []};
    t.view.physicalSize = const Size(1280, 2600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              key: const ValueKey('host-open'),
              onPressed: () => ChannelSettings.show(
                context,
                controller: w,
                channel: channel,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await t.tap(key('host-open'));
    await t.pumpAndSettle();
    return (w, api);
  }

  Iterable<String> calls(dynamic api, String method) => [
    for (final c in api.calls as List)
      if (c.method == method) '${c.method} ${c.path}',
  ];

  test(
    'same-admin rule: self by handle or email, target owned or administered',
    () {
      const me = (name: 'alice', email: 'Alice@Example.com');
      expect(jointInvitesSelf(['@alice'], me), isTrue);
      expect(jointInvitesSelf(['alice'], me), isTrue);
      expect(jointInvitesSelf(['alice@example.com'], me), isTrue);
      expect(jointInvitesSelf(['@bob', 'bob@example.com'], me), isFalse);
      expect(jointInvitesSelf(['@alice'], null), isFalse);
      final servers = [
        RaftRecord({'slug': 'partner', 'name': 'Partner', 'role': 'owner'}),
        RaftRecord({'slug': 'guest-of', 'name': 'Guest Of', 'role': 'member'}),
        RaftRecord({'slug': 'visual', 'name': 'Visual', 'role': 'owner'}),
      ];
      RaftRecord? find(String slug, [List<String> people = const ['@alice']]) =>
          findSameAdminJointTarget(
            servers: servers,
            currentServerSlug: 'visual',
            user: me,
            targetServerSlug: slug,
            invitedPeople: people,
          );
      expect(find('partner')?.name, 'Partner');
      expect(find('guest-of'), isNull, reason: 'only owner or admin');
      expect(find('visual'), isNull, reason: 'not the current server');
      expect(find('nowhere'), isNull);
      expect(find('partner', ['@bob']), isNull);
      expect(find(''), isNull);
    },
  );

  testWidgets('lists the connected servers with plan and status', (t) async {
    await mount(t, jointChannel());
    expect(find.text('Acme Partners'), findsOneWidget);
    expect(find.text('Globex'), findsOneWidget);
    expect(find.textContaining('This server'), findsOneWidget);
    for (final slug in ['visual', 'acme-partners', 'globex']) {
      expect(key('channel-settings-joint-server-row:$slug'), findsOneWidget);
    }
    expect(find.text('Paid'), findsOneWidget);
    expect(find.text('Free'), findsNWidgets(2));
    expect(find.text('active'), findsNWidgets(2));
    expect(find.text('pending'), findsOneWidget);
  });

  testWidgets('a joint channel offers Disconnect, never Delete', (t) async {
    final (_, api) = await mount(t, jointChannel());
    expect(find.text('Delete Channel'), findsNothing);
    final action = key('channel-settings-delete-action');
    expect(action, findsOneWidget);
    expect(find.text('Disconnect Channel'), findsOneWidget);
    await t.ensureVisible(action);
    await t.tap(action);
    await t.pumpAndSettle();
    expect(key('channel-settings-confirm-dialog'), findsOneWidget);
    expect(find.text('DISCONNECT JOINT CHANNEL'), findsOneWidget);
    expect(
      find.text(
        '"partners" will be removed from this server. Other connected servers keep their own projection and history.',
      ),
      findsOneWidget,
    );
    api.routes['POST /channels/c1/disconnect'] = (_) => {'ok': true};
    api.routes['GET /channels'] = (_) => [];
    await t.tap(
      find.descendant(
        of: key('channel-settings-confirm-dialog'),
        matching: find.text('Disconnect'),
      ),
    );
    await t.pumpAndSettle(const Duration(milliseconds: 100));
    expect(calls(api, 'POST'), contains('POST /channels/c1/disconnect'));
    expect(calls(api, 'DELETE'), isEmpty);
    expect(find.byType(RaftOverflowSheet), findsNothing);
  });

  testWidgets('a regular channel keeps Delete Channel', (t) async {
    await mount(t, {...jointChannel(), 'type': 'channel', 'jointServers': []});
    expect(find.text('Delete Channel'), findsOneWidget);
    expect(find.text('Disconnect Channel'), findsNothing);
    expect(key('channel-settings-joint-section'), findsNothing);
  });

  testWidgets('Resend Invite shows only while this server has invites out', (
    t,
  ) async {
    final (_, api) = await mount(t, jointChannel());
    api.routes['POST /channels/c1/joint-invite/resend'] = (_) => {
      'resentCount': 1,
    };
    expect(key('channel-settings-joint-resend'), findsOneWidget);
    await t.ensureVisible(key('channel-settings-joint-resend'));
    await t.tap(key('channel-settings-joint-resend'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(
      calls(api, 'POST'),
      contains('POST /channels/c1/joint-invite/resend'),
    );
    expect(find.text('Invite resent'), findsOneWidget);
    await t.pump(const Duration(milliseconds: 1600));
    expect(find.text('Resend Invite'), findsOneWidget);
  });

  testWidgets('no pending invites from this server: no Resend', (t) async {
    await mount(
      t,
      jointChannel(
        pending: [
          {'id': 'i9', 'fromServerId': 's2'},
        ],
      ),
    );
    expect(key('channel-settings-joint-resend'), findsNothing);
  });

  testWidgets(
    'without federateChannels the list shows but nothing is editable',
    (t) async {
      await mount(t, jointChannel(federate: false));
      expect(find.text('Acme Partners'), findsOneWidget);
      expect(key('channel-settings-joint-resend'), findsNothing);
      expect(key('channel-settings-joint-invite-form'), findsNothing);
    },
  );

  testWidgets('an archived joint channel offers no invitation', (t) async {
    await mount(t, jointChannel(archived: true));
    expect(key('channel-settings-joint-invite-form'), findsNothing);
    expect(key('channel-settings-joint-resend'), findsNothing);
  });

  testWidgets('Send Invite validates the slug and needs a person', (t) async {
    final (_, api) = await mount(t, jointChannel());
    final send = key('channel-settings-joint-send-invite');
    await t.ensureVisible(send);
    expect(t.widget<RaftSettingsRecipeButton>(send).onPressed, isNull);
    await t.enterText(key('channel-settings-joint-server-slug'), 'Not A Slug');
    await t.enterText(key('channel-settings-joint-invited-people'), '@bob');
    await t.pump();
    expect(t.widget<RaftSettingsRecipeButton>(send).onPressed, isNull);
    await t.enterText(key('channel-settings-joint-server-slug'), 'partner');
    await t.pump();
    expect(t.widget<RaftSettingsRecipeButton>(send).onPressed, isNotNull);
    expect(
      calls(api, 'POST').where((c) => c.contains('joint-invites')),
      isEmpty,
    );
  });

  testWidgets('Send Invite posts the slug and people and reports the emails', (
    t,
  ) async {
    final (_, api) = await mount(t, jointChannel());
    Map<String, dynamic>? body;
    api.routes['POST /channels/c1/joint-invites'] = (o) {
      body = Map<String, dynamic>.from(o.data as Map);
      return jointChannel();
    };
    await t.enterText(key('channel-settings-joint-server-slug'), 'partner');
    await t.enterText(
      key('channel-settings-joint-invited-people'),
      '@bob, carol@example.com',
    );
    await t.pump();
    final send = key('channel-settings-joint-send-invite');
    await t.ensureVisible(send);
    await t.tap(send);
    await t.pumpAndSettle();
    expect(body, {
      'targetServerSlug': 'partner',
      'invitedPeople': ['@bob', 'carol@example.com'],
    });
    expect(find.text('2 invite emails sent.'), findsOneWidget);
    expect(slugText(t), isEmpty);
  });

  testWidgets('a server error under the slug stays on the slug field', (
    t,
  ) async {
    final (_, api) = await mount(t, jointChannel());
    api.routes['POST /channels/c1/joint-invites'] = (_) => {
      'error': 'Target server not found',
    };
    api.statuses['POST /channels/c1/joint-invites'] = 404;
    await t.enterText(key('channel-settings-joint-server-slug'), 'nowhere');
    await t.enterText(key('channel-settings-joint-invited-people'), '@bob');
    await t.pump();
    final send = key('channel-settings-joint-send-invite');
    await t.ensureVisible(send);
    await t.tap(send);
    await t.pumpAndSettle();
    expect(find.text('Target server not found'), findsOneWidget);
    expect(key('channel-settings-joint-invite-submit-error'), findsNothing);
  });

  testWidgets('the 30-server cap replaces the form with its explanation', (
    t,
  ) async {
    await mount(
      t,
      jointChannel(
        servers: [
          for (var i = 0; i < 30; i++)
            {
              'serverId': 'x$i',
              'serverName': 'Server $i',
              'serverSlug': 'server-$i',
              'status': 'active',
            },
        ],
      ),
    );
    expect(
      find.text('Joint channels support a maximum of 30 servers.'),
      findsOneWidget,
    );
    expect(key('channel-settings-joint-invite-form'), findsNothing);
  });

  group('RFC 075 same-admin direct connection', () {
    final owned = [
      RaftRecord({
        'id': 's1',
        'slug': 'visual',
        'name': 'Visual Server',
        'role': 'owner',
      }),
      RaftRecord({
        'id': 's9',
        'slug': 'partner',
        'name': 'Partner HQ',
        'role': 'admin',
      }),
    ];

    Future<void> fill(WidgetTester t, String slug, String people) async {
      await t.enterText(key('channel-settings-joint-server-slug'), slug);
      await t.enterText(key('channel-settings-joint-invited-people'), people);
      await t.pump();
    }

    testWidgets('inviting yourself on a server you administer asks first', (
      t,
    ) async {
      final (_, api) = await mount(t, jointChannel(), servers: owned);
      await fill(t, 'partner', '@alice');
      expect(key('joint-same-admin-notice'), findsOneWidget);
      expect(
        find.text(
          "You're an admin of both Visual Server and Partner HQ. The connection will be made directly as admin of both, and no email will be sent.",
        ),
        findsOneWidget,
      );
      final send = key('channel-settings-joint-send-invite');
      await t.ensureVisible(send);
      await t.tap(send);
      await t.pumpAndSettle();
      expect(
        find.text(
          'Confirm the direct connection, or remove yourself from the invited people.',
        ),
        findsOneWidget,
      );
      expect(
        calls(api, 'POST').where((c) => c.contains('joint-invites')),
        isEmpty,
      );
    });

    testWidgets('confirmed: sameAdmin is sent and success names the server', (
      t,
    ) async {
      final (_, api) = await mount(t, jointChannel(), servers: owned);
      Map<String, dynamic>? body;
      api.routes['POST /channels/c1/joint-invites'] = (o) {
        body = Map<String, dynamic>.from(o.data as Map);
        return jointChannel(
          servers: [
            {
              'serverId': 's9',
              'serverName': 'Partner HQ',
              'serverSlug': 'partner',
              'status': 'active',
            },
          ],
        );
      };
      await fill(t, 'partner', '@alice');
      await t.tap(key('joint-same-admin-confirm'));
      await t.pump();
      final send = key('channel-settings-joint-send-invite');
      await t.ensureVisible(send);
      await t.tap(send);
      await t.pumpAndSettle();
      expect(body, {
        'targetServerSlug': 'partner',
        'invitedPeople': ['@alice'],
        'sameAdmin': true,
      });
      expect(find.text('Connected Partner HQ directly.'), findsOneWidget);
    });

    testWidgets('editing the draft asks for the confirmation again', (t) async {
      await mount(t, jointChannel(), servers: owned);
      await fill(t, 'partner', '@alice');
      await t.tap(key('joint-same-admin-confirm'));
      await t.pump();
      expect(
        t.widget<RaftCheckbox>(key('joint-same-admin-confirm')).value,
        true,
      );
      await t.enterText(
        key('channel-settings-joint-invited-people'),
        '@alice, @bob',
      );
      await t.pump();
      expect(
        t.widget<RaftCheckbox>(key('joint-same-admin-confirm')).value,
        false,
      );
    });

    testWidgets(
      'a server you only belong to, or other people, show no notice',
      (t) async {
        await mount(
          t,
          jointChannel(),
          servers: [
            ...owned,
            RaftRecord({'slug': 'member-only', 'name': 'M', 'role': 'member'}),
          ],
        );
        await fill(t, 'member-only', '@alice');
        expect(key('joint-same-admin-notice'), findsNothing);
        await fill(t, 'partner', '@bob');
        expect(key('joint-same-admin-notice'), findsNothing);
      },
    );
  });

  testWidgets('an unsent invitation guards closing and cannot be saved away', (
    t,
  ) async {
    await mount(t, jointChannel());
    await t.enterText(key('channel-settings-joint-server-slug'), 'partner');
    await t.pump();
    await t.tap(key('channel-overflow-scrim'));
    await t.pumpAndSettle();
    expect(key('channel-overflow-unsaved-prompt'), findsOneWidget);
    expect(
      find.text(
        'A Joint invitation has not been sent. Keep editing to send it, or discard all unsaved changes before closing.',
      ),
      findsOneWidget,
    );
    expect(key('channel-overflow-unsaved-save'), findsNothing);
    await t.tap(find.text('Keep editing'));
    await t.pumpAndSettle();
    expect(find.byType(RaftOverflowSheet), findsOneWidget);
    expect(slugText(t), 'partner');
    await t.tap(key('channel-overflow-scrim'));
    await t.pumpAndSettle();
    await t.tap(key('channel-overflow-unsaved-discard'));
    await t.pumpAndSettle();
    expect(find.byType(RaftOverflowSheet), findsNothing);
  });

  testWidgets('a clean joint drawer closes straight from the scrim', (t) async {
    await mount(t, jointChannel());
    await t.tap(key('channel-overflow-scrim'));
    await t.pumpAndSettle();
    expect(find.byType(RaftOverflowSheet), findsNothing);
  });
}
