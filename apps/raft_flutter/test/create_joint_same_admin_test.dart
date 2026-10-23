// RFC 075 section 4.5 in the Create Joint Channel dialog: inviting yourself on a
// server you administer shows the direct-connection confirmation, blocks the
// submit until it is ticked, and sends `sameAdmin: true` for that invite.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/create_joint_channel_dialog.dart';
import 'package:raft_ui/raft_ui.dart';

void main() {
  final servers = [
    RaftRecord({
      'id': 's1',
      'slug': 'visual',
      'name': 'Visual Server',
      'role': 'owner',
    }),
    RaftRecord({
      'id': 's2',
      'slug': 'partner',
      'name': 'Partner HQ',
      'role': 'admin',
    }),
    RaftRecord({
      'id': 's3',
      'slug': 'elsewhere',
      'name': 'Elsewhere',
      'role': 'member',
    }),
  ];
  final user = RaftRecord({
    'id': 'u1',
    'name': 'alice',
    'email': 'alice@example.com',
  });

  Future<List<Map<String, dynamic>>> mount(WidgetTester t) async {
    final payloads = <Map<String, dynamic>>[];
    t.view.physicalSize = const Size(900, 1800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(RaftFamily.elegant),
        home: Scaffold(
          body: CreateJointChannelDialog(
            agents: const [],
            users: const [],
            servers: servers,
            currentUser: user,
            currentServerSlug: 'visual',
            currentServerName: 'Visual Server',
            onCreate: (payload) async {
              payloads.add(payload);
              return {'id': 'c9', 'name': payload['name']};
            },
            onUnarchive: (id) async => {'id': id},
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    return payloads;
  }

  Finder key(String value) => find.byKey(ValueKey(value));

  Future<void> fill(WidgetTester t, String slug, String people) async {
    await t.enterText(key('joint-name'), 'launch-room');
    await t.enterText(key('joint-slug-0'), slug);
    await t.enterText(key('joint-people-0'), people);
    await t.pump();
  }

  Future<void> submit(WidgetTester t) async {
    await t.ensureVisible(key('joint-create-submit'));
    await t.tap(key('joint-create-submit'));
    await t.pumpAndSettle();
  }

  testWidgets('inviting yourself on an administered server asks to confirm', (
    t,
  ) async {
    final payloads = await mount(t);
    expect(key('joint-same-admin-notice'), findsNothing);
    await fill(t, 'partner', '@alice');
    expect(key('joint-same-admin-notice'), findsOneWidget);
    expect(
      find.text(
        "You're an admin of both Visual Server and Partner HQ. The connection will be made directly as admin of both, and no email will be sent.",
      ),
      findsOneWidget,
    );
    expect(
      find.text('Connect directly as admin of both servers'),
      findsOneWidget,
    );
    await submit(t);
    expect(
      find.text(
        'Confirm the direct connection, or remove yourself from the invited people.',
      ),
      findsOneWidget,
    );
    expect(payloads, isEmpty);
  });

  testWidgets('confirmed: the invite carries sameAdmin and the dialog closes', (
    t,
  ) async {
    final payloads = await mount(t);
    await fill(t, 'partner', 'alice@example.com');
    await t.tap(key('joint-same-admin-confirm'));
    await t.pump();
    await submit(t);
    expect(payloads.single['jointInvites'], [
      {
        'targetServerSlug': 'partner',
        'invitedPeople': ['alice@example.com'],
        'sameAdmin': true,
      },
    ]);
  });

  testWidgets('editing the slug or the people withdraws the confirmation', (
    t,
  ) async {
    await mount(t);
    await fill(t, 'partner', '@alice');
    await t.tap(key('joint-same-admin-confirm'));
    await t.pump();
    expect(t.widget<RaftCheckbox>(key('joint-same-admin-confirm')).value, true);
    await t.enterText(key('joint-people-0'), '@alice, @bob');
    await t.pump();
    expect(
      t.widget<RaftCheckbox>(key('joint-same-admin-confirm')).value,
      false,
    );
  });

  testWidgets(
    'no notice for other people, a member-only server or the current server',
    (t) async {
      final payloads = await mount(t);
      await fill(t, 'partner', '@bob');
      expect(key('joint-same-admin-notice'), findsNothing);
      await fill(t, 'elsewhere', '@alice');
      expect(key('joint-same-admin-notice'), findsNothing);
      await fill(t, 'visual', '@alice');
      expect(key('joint-same-admin-notice'), findsNothing);
      await fill(t, 'partner', '@bob');
      await submit(t);
      expect(payloads.single['jointInvites'], [
        {
          'targetServerSlug': 'partner',
          'invitedPeople': ['@bob'],
        },
      ]);
    },
  );
}
