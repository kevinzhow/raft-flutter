import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/add_members_dialog.dart';
import 'package:raft_flutter/features/create_joint_channel_dialog.dart';
import 'package:raft_ui/raft_ui.dart';

import 'activity_incremental_refresh_test.dart' show ActivityClient;

class _Workspace extends WorkspaceController {
  _Workspace(super.client);
  final commands = <(String, String, dynamic)>[];
  Object? commandError;
  @override
  Future<void> refreshUnread() async {}
  @override
  Future<dynamic> query(String path, {Map<String, dynamic>? query}) async {
    return switch (path) {
      '/channels/c1/members' => {
        'humans': [
          {'userId': 'u-member'},
        ],
        'agents': [
          {'id': 'a-member'},
        ],
      },
      '/servers/s/members' => [
        {'userId': 'u-member', 'name': 'member', 'displayName': 'Member'},
        {
          'userId': 'u-new',
          'name': 'designer',
          'displayName': 'Designer',
          'description': 'Product design',
        },
        {'userId': 'u-plain', 'name': 'plain'},
      ],
      '/agents' => [
        {'id': 'a-member', 'name': 'old', 'displayName': 'Old agent'},
        {
          'id': 'a-new',
          'name': 'ux',
          'displayName': 'Product UX Designer',
          'description': 'Turns feedback into specs',
        },
      ],
      _ => <dynamic>[],
    };
  }

  @override
  Future<dynamic> command(String method, String path, {dynamic data}) async {
    commands.add((method, path, data));
    if (commandError != null) throw commandError!;
    return <String, dynamic>{};
  }
}

void main() {
  late ActivityClient client;
  late _Workspace w;
  setUp(() {
    client = ActivityClient()..user = RaftRecord({'id': 'alice'});
    client.selectServer('s');
    w = _Workspace(client)
      ..server = RaftRecord({'id': 's', 'role': 'owner'})
      ..channels = [
        RaftChannel({
          'id': 'c1',
          'name': 'design',
          'type': 'channel',
          'joined': true,
        }),
      ];
  });
  tearDown(() async {
    w.dispose();
    await client.dispose();
  });

  Future<void> open(
    WidgetTester t,
    Widget Function(BuildContext) dialog,
  ) async {
    t.view.physicalSize = const Size(1280, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showRaftModal<Object?>(context, builder: dialog),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
  }

  group('AddMembersDialog', () {
    AddMembersDialog dialog({
      List<String> humans = const ['u-member', 'u-new'],
      List<String> agents = const ['a-member', 'a-new'],
      Future<void> Function()? start,
      void Function(Object)? failed,
      Future<void> Function(AddMembersResult)? submitted,
    }) => AddMembersDialog(
      controller: w,
      channelId: 'c1',
      prefilledHumanIds: humans,
      prefilledAgentIds: agents,
      draftHint: 'Cindy suggested them',
      actionCardMessageId: 'm1',
      actionCardConfirmationVersion: 7,
      onSubmitStart: start,
      onSubmitError: failed,
      onSubmitted: submitted,
    );

    testWidgets('lists only net-new members under Agents and Humans', (
      t,
    ) async {
      await open(t, (_) => dialog());
      expect(find.text('Add Members'), findsOneWidget);
      expect(
        find.textContaining('design — target channel', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Cindy suggested them'), findsOneWidget);
      expect(find.text('Agents'), findsOneWidget);
      expect(find.text('Humans'), findsOneWidget);
      expect(find.text('Product UX Designer'), findsOneWidget);
      expect(find.text('Turns feedback into specs'), findsOneWidget);
      expect(find.text('Designer'), findsOneWidget);
      // Existing members are dropped from the suggestion.
      expect(find.text('Old agent'), findsNothing);
      expect(find.text('Member'), findsNothing);
      expect(find.text('Add 2 Members'), findsOneWidget);
    });

    testWidgets('removing a row adds only the effective selection', (t) async {
      final events = <String>[];
      AddMembersResult? result;
      await open(
        t,
        (_) => dialog(
          start: () async => events.add('start'),
          submitted: (r) async => result = r,
        ),
      );
      await t.tap(find.byKey(const ValueKey('add-members-remove-agent:a-new')));
      await t.pump();
      expect(find.text('Product UX Designer'), findsNothing);
      // The Agents header stays while the agent candidate exists.
      expect(find.text('Agents'), findsOneWidget);
      expect(find.text('Add 1 Member'), findsOneWidget);
      await t.tap(find.text('Add 1 Member'));
      await t.pumpAndSettle();
      expect(events, ['start']);
      expect(w.commands.single.$1, 'POST');
      expect(w.commands.single.$2, '/channels/c1/members/batch');
      expect(w.commands.single.$3, {
        'userIds': ['u-new'],
        'agentIds': <String>[],
        'actionCardMessageId': 'm1',
        'actionCardConfirmationVersion': 7,
      });
      expect(result?.addedHumanIds, ['u-new']);
      expect(result?.addedAgentIds, isEmpty);
      expect(result?.channelName, 'design');
      // The dialog closed.
      expect(find.text('Add Members'), findsNothing);
    });

    testWidgets('a failed add keeps the dialog with the error', (t) async {
      Object? failed;
      w.commandError = RaftApiException.response(
        'Boom',
        status: 500,
        body: {'error': 'Boom'},
      );
      await open(t, (_) => dialog(failed: (e) => failed = e));
      await t.tap(find.text('Add 2 Members'));
      await t.pumpAndSettle();
      expect(failed, isA<RaftApiException>());
      expect(find.text('Boom'), findsOneWidget);
      expect(find.text('Add Members'), findsOneWidget);
      expect(find.text('Add 2 Members'), findsOneWidget);
    });

    testWidgets('everyone already a member: nothing to add, submit disabled', (
      t,
    ) async {
      await open(t, (_) => dialog(humans: ['u-member'], agents: ['a-member']));
      expect(
        find.text(
          'Everyone the agent suggested is already a member of this channel. Nothing to add.',
        ),
        findsOneWidget,
      );
      await t.tap(find.byKey(const ValueKey('add-members-submit')));
      await t.pumpAndSettle();
      expect(w.commands, isEmpty);
    });
  });

  group('CreateJointChannelDialog', () {
    Future<void> openJoint(
      WidgetTester t, {
      bool free = true,
      Future<Map<String, dynamic>> Function(Map<String, dynamic>)? create,
      Future<Map<String, dynamic>> Function(String)? unarchive,
      VoidCallback? billing,
    }) => open(
      t,
      (_) => CreateJointChannelDialog(
        agents: const [
          {'id': 'a1', 'name': 'cindy', 'displayName': 'Cindy'},
        ],
        users: const [
          {'userId': 'u1', 'name': 'bob', 'displayName': 'Bob'},
        ],
        freePlan: free,
        onCreate: create ?? (_) async => {'id': 'new'},
        onUnarchive: unarchive ?? (_) async => {'id': 'old'},
        onViewBilling: billing,
      ),
    );

    testWidgets(
      'free plan banner, one invite card, Add server grows to the cap',
      (t) async {
        await openJoint(t);
        expect(find.text('Create Joint Channel'), findsNWidgets(2));
        expect(
          find.textContaining(
            'Free servers can create and join Joint Channels',
          ),
          findsOneWidget,
        );
        expect(find.text('Server invite 1'), findsOneWidget);
        // A single draft cannot be removed.
        expect(
          find.byKey(const ValueKey('joint-remove-invite-1')),
          findsNothing,
        );
        final add = find.byKey(const ValueKey('joint-add-server'));
        await t.ensureVisible(add);
        await t.tap(add);
        await t.pump();
        expect(find.text('Server invite 2'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('joint-remove-invite-2')),
          findsOneWidget,
        );
        await t.ensureVisible(
          find.byKey(const ValueKey('joint-remove-invite-2')),
        );
        await t.tap(find.byKey(const ValueKey('joint-remove-invite-2')));
        await t.pump();
        expect(find.text('Server invite 2'), findsNothing);
        // No banner on a paid plan.
      },
    );

    testWidgets('paid plan has no free allowance banner', (t) async {
      await openJoint(t, free: false);
      expect(
        find.textContaining('Free servers can create and join Joint Channels'),
        findsNothing,
      );
    });

    testWidgets('incomplete invites are rejected before any request', (
      t,
    ) async {
      var created = 0;
      await openJoint(
        t,
        create: (_) async {
          created++;
          return {};
        },
      );
      await t.enterText(find.byKey(const ValueKey('joint-name')), 'launch');
      await t.tap(find.byKey(const ValueKey('joint-create-submit')));
      await t.pump();
      expect(find.text('Invite server slug is required'), findsOneWidget);
      await t.enterText(find.byKey(const ValueKey('joint-slug-0')), 'partner');
      await t.tap(find.byKey(const ValueKey('joint-create-submit')));
      await t.pump();
      expect(
        find.text('At least one invited person is required'),
        findsOneWidget,
      );
      expect(created, 0);
    });

    testWidgets('an archived name offers Unarchive and opens that channel', (
      t,
    ) async {
      String? unarchived;
      await openJoint(
        t,
        create: (_) async => throw RaftApiException.response(
          'name held',
          status: 409,
          body: {
            'code': 'archived_name_collision',
            'archivedChannelId': 'old',
            'archivedChannelName': 'launch',
            'archivedChannelType': 'joint',
            'canUnarchiveArchivedChannel': true,
          },
        ),
        unarchive: (id) async {
          unarchived = id;
          return {'id': id};
        },
      );
      await t.enterText(find.byKey(const ValueKey('joint-name')), 'launch');
      await t.enterText(find.byKey(const ValueKey('joint-slug-0')), 'partner');
      await t.enterText(find.byKey(const ValueKey('joint-people-0')), '@bob');
      await t.tap(find.byKey(const ValueKey('joint-create-submit')));
      await t.pumpAndSettle();
      expect(find.text('Unarchive'), findsOneWidget);
      expect(find.text('Change name'), findsOneWidget);
      await t.tap(find.text('Unarchive'));
      await t.pumpAndSettle();
      expect(unarchived, 'old');
      expect(find.text('Create Joint Channel'), findsNothing);
    });

    testWidgets('the free-server limit links to Billing', (t) async {
      var billing = 0;
      await openJoint(
        t,
        billing: () => billing++,
        create: (_) async => throw RaftApiException.response(
          'limit',
          status: 402,
          body: {'code': 'joint_free_server_limit'},
        ),
      );
      await t.enterText(find.byKey(const ValueKey('joint-name')), 'launch');
      await t.enterText(find.byKey(const ValueKey('joint-slug-0')), 'partner');
      await t.enterText(find.byKey(const ValueKey('joint-people-0')), '@bob');
      await t.tap(find.byKey(const ValueKey('joint-create-submit')));
      await t.pumpAndSettle();
      expect(
        find.textContaining('This Joint Channel already has 2 free servers'),
        findsOneWidget,
      );
      await t.tap(find.text('View Billing'));
      await t.pumpAndSettle();
      expect(billing, 1);
      expect(find.text('Create Joint Channel'), findsNothing);
    });
  });
}
