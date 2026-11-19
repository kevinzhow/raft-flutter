import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';

import 'mounted_message_navigation_test.dart' show mountPage, pageFixture;

Finder _key(String value) => find.byKey(ValueKey(value));

Future<void> _contextMenu(WidgetTester tester, Finder target) async {
  await tester.tapAt(
    tester.getCenter(target),
    kind: PointerDeviceKind.mouse,
    buttons: kSecondaryMouseButton,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('creating and editing a section changes its conversations', (
    tester,
  ) async {
    final (workspace, api) = await pageFixture(tester);
    workspace.channels = [
      for (final name in ['Planning', 'Review'])
        RaftChannel({'id': name, 'name': name, 'joined': true}),
    ];
    final writes = <Object?>[];
    api.routes['PATCH /servers/s1/sidebar-order'] = (request) {
      writes.add(request.data);
      return {};
    };
    await mountPage(tester, workspace, false);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await _contextMenu(tester, _key('sidebar-section-system:channels'));
    await tester.tap(_key('sidebar-menu-new-section'));
    await tester.pumpAndSettle();
    final name = find.descendant(
      of: _key('sidebar-section-dialog'),
      matching: find.byType(EditableText),
    );
    await tester.enterText(name, 'Delivery');
    await tester.pump();
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(writes, hasLength(1));
    expect(find.text('Add conversations to Delivery'), findsOneWidget);
    await tester.enterText(_key('sidebar-section-conversation-filter'), 'rev');
    await tester.pumpAndSettle();
    expect(_key('sidebar-section-add-option-Planning'), findsNothing);
    await tester.tap(_key('sidebar-section-add-option-Review'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add 1 conversation'));
    await tester.pumpAndSettle();
    expect(find.text('Add conversations to Delivery'), findsNothing);
    expect(writes, hasLength(2));
    final placements = (writes.last as Map)['sectionPlacements'] as List;
    expect(placements.single['id'], 'Review');
    await _contextMenu(tester, find.text('Delivery'));
    await tester.tap(_key('sidebar-menu-rename-section'));
    await tester.pumpAndSettle();
    await tester.tap(_key('sidebar-section-add-option-Review'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(writes, hasLength(3));
    expect((writes.last as Map)['sectionPlacements'], isEmpty);
    await tester.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('desktop Home leaves conversation search to Search', (
    tester,
  ) async {
    final (workspace, _) = await pageFixture(tester);
    await mountPage(tester, workspace, false);
    expect(_key('sidebar-conversation-finder-input'), findsNothing);
    expect(_key('nav-saved'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('Hide Empty Sections keeps custom sections available', (
    tester,
  ) async {
    final (workspace, _) = await pageFixture(tester);
    workspace.sidebarOrder = {
      'customSections': [
        {'id': 'empty', 'name': 'Empty team'},
      ],
    };
    await mountPage(tester, workspace, false);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    final custom = _key('sidebar-section-empty');
    final pinned = _key('sidebar-section-system:pinned');
    expect(custom, findsOneWidget);
    expect(pinned, findsOneWidget);
    await _contextMenu(tester, _key('sidebar-section-system:channels'));
    await tester.tap(find.text('Hide Empty Sections'));
    await tester.pumpAndSettle();
    expect(custom, findsOneWidget);
    expect(pinned, findsNothing);
    await tester.pumpWidget(const SizedBox());
    await mountPage(tester, workspace, false);
    expect(custom, findsOneWidget);
    expect(pinned, findsNothing);
    await _contextMenu(tester, _key('sidebar-section-system:channels'));
    await tester.tap(find.text('Hide Empty Sections'));
    await tester.pumpAndSettle();
    expect(pinned, findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  for (final (platform, width, height) in [
    (TargetPlatform.android, 856.0, 944.0),
    (TargetPlatform.android, 944.0, 856.0),
    (TargetPlatform.linux, 390.0, 844.0),
  ]) {
    testWidgets(
      'Home opens the channel menu with $platform input at $width×$height',
      (tester) async {
        final (workspace, _) = await pageFixture(tester);
        workspace
          ..mobileNavigation = width < 600
          ..channel = null
          ..section = 'home'
          ..channels = [
            RaftChannel({'id': 'planning', 'name': 'Planning', 'joined': true}),
          ];
        await mountPage(tester, workspace, false, width: width, height: height);
        final row = _key('sidebar-channel-planning');
        if (platform == TargetPlatform.android) {
          await tester.longPress(row);
          await tester.pumpAndSettle();
        } else {
          await _contextMenu(tester, row);
        }
        expect(_key('sidebar-menu-leave'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      },
      variant: TargetPlatformVariant.only(platform),
    );
  }

  testWidgets('an external relation belongs in External with the flag off', (
    tester,
  ) async {
    final (workspace, _) = await pageFixture(tester);
    workspace.channels = [
      RaftChannel({
        'id': 'external',
        'name': 'partner',
        'type': 'channel',
        'joined': true,
        'hasExternalRelation': true,
      }),
    ];
    await mountPage(tester, workspace, true);
    expect(find.text('External'), findsOneWidget);
    expect(find.text('Joint channels'), findsNothing);
    expect(
      tester.getTopLeft(_key('sidebar-channel-external')).dy,
      lessThan(tester.getTopLeft(_key('sidebar-section-system:channels')).dy),
    );
    await tester.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('the External section hides when empty with the flag on', (
    tester,
  ) async {
    final (workspace, api) = await pageFixture(tester);
    api.routes['POST /feature-flags/evaluate'] = (request) => {
      'evaluations': [
        for (final key in request.data['keys'] as List)
          {'key': key, 'enabled': key == 'external_channels_v1'},
      ],
    };
    await mountPage(tester, workspace, false);
    expect(_key('sidebar-section-system:joint'), findsNothing);
    await _contextMenu(tester, _key('workspace-sidebar'));
    expect(find.text('Create external channel'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('channel creation advances to members before writing', (
    tester,
  ) async {
    final (workspace, api) = await pageFixture(tester);
    api.routes['POST /feature-flags/evaluate'] = (request) => {
      'evaluations': [
        for (final key in request.data['keys'] as List)
          {'key': key, 'enabled': key == 'external_channels_v1'},
      ],
    };
    api.routes['GET /channels/external-availability'] = (_) => {
      'freeLimitReached': false,
    };
    await mountPage(tester, workspace, false);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await _contextMenu(tester, _key('workspace-sidebar'));
    await tester.tap(find.text('Create Channel'));
    await tester.pumpAndSettle();
    expect(find.text('External'), findsOneWidget);
    expect(find.text('Members'), findsNothing);
    await tester.enterText(_key('create-channel-name'), 'review-notes');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Add people to #review-notes'), findsOneWidget);
    expect(
      api.calls.where(
        (call) => call.method == 'POST' && call.path == '/channels',
      ),
      isEmpty,
    );
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('review-notes'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('a joined Lounge renders once in Direct messages', (
    tester,
  ) async {
    final (workspace, api) = await pageFixture(tester);
    api.routes['POST /feature-flags/evaluate'] = (request) => {
      'evaluations': [
        for (final key in request.data['keys'] as List)
          {'key': key, 'enabled': key == 'agent_lounge_v0'},
      ],
    };
    workspace.channels = [
      RaftChannel({
        'id': 'lounge',
        'name': 'builder-lounge',
        'type': 'channel',
        'joined': true,
        'loungeAgentId': 'builder',
      }),
    ];
    workspace.dms = [
      RaftChannel({
        'id': 'builder-dm',
        'type': 'dm',
        'peerType': 'agent',
        'peerId': 'builder',
        'lounge': {'channelId': 'lounge', 'joined': true, 'unreadCount': 2},
      }),
    ];
    await mountPage(tester, workspace, false);
    final lounge = _key('sidebar-channel-lounge');
    expect(lounge, findsOneWidget);
    expect(find.text("builder's Lounge"), findsOneWidget);
    expect(
      tester.getTopLeft(lounge).dy,
      greaterThan(tester.getTopLeft(_key('sidebar-section-system:dms')).dy),
    );
    await _contextMenu(tester, lounge);
    expect(find.text('Mark all as read'), findsOneWidget);
    expect(find.text('Pin'), findsOneWidget);
    expect(find.text('Close chat'), findsOneWidget);
    expect(find.text('Move to Section'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('a fresh mention brings a closed Lounge back to Home', (
    tester,
  ) async {
    final (workspace, api) = await pageFixture(tester);
    api.routes['POST /feature-flags/evaluate'] = (request) => {
      'evaluations': [
        for (final key in request.data['keys'] as List)
          {'key': key, 'enabled': key == 'agent_lounge_v0'},
      ],
    };
    api.routes['PATCH /servers/s1/sidebar-order'] = (_) => {};
    final loungeRow = {
      'id': 'lounge',
      'name': 'builder-lounge',
      'type': 'channel',
      'serverId': 's1',
      'joined': true,
      'loungeAgentId': 'builder',
    };
    api.routes['GET /channels/lounge'] = (_) => loungeRow;
    api.routes['GET /messages/channel/lounge'] = (_) => {'messages': []};
    api.routes['POST /channels/lounge/read'] = (_) => {};
    workspace
      ..channel = null
      ..section = 'home'
      ..channels = [RaftChannel(loungeRow)]
      ..sidebarOrder = {
        'hiddenDmIds': ['lounge'],
      };
    await mountPage(tester, workspace, false);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    final lounge = _key('sidebar-channel-lounge');
    expect(lounge, findsNothing);
    workspace.conversationReads.mentions = {'lounge'};
    workspace.notifyListeners();
    await tester.pumpAndSettle();
    expect(lounge, findsOneWidget);
    expect(workspace.sidebarOrder['hiddenDmIds'], ['lounge']);
    await tester.tap(lounge.hitTestable(), kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(workspace.channel?.id, 'lounge');
    expect(workspace.sidebarOrder['hiddenDmIds'], isEmpty);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('a summary-only Lounge loads its mute state once', (
    tester,
  ) async {
    final (workspace, api) = await pageFixture(tester);
    api.routes['POST /feature-flags/evaluate'] = (request) => {
      'evaluations': [
        for (final key in request.data['keys'] as List)
          {'key': key, 'enabled': key == 'agent_lounge_v0'},
      ],
    };
    workspace.dms = [
      RaftChannel({
        'id': 'builder-dm',
        'type': 'dm',
        'peerType': 'agent',
        'peerId': 'builder',
        'lounge': {'channelId': 'lounge', 'joined': true, 'unreadCount': 2},
      }),
    ];
    api.routes['GET /channels/lounge'] = (_) => {
      'id': 'lounge',
      'name': 'builder-lounge',
      'type': 'channel',
      'joined': true,
      'loungeAgentId': 'builder',
      'activityMuted': true,
    };
    await mountPage(tester, workspace, false);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await _contextMenu(tester, _key('sidebar-channel-lounge'));
    expect(find.text('Unmute'), findsOneWidget);
    expect(
      api.calls.where((call) => call.path == '/channels/lounge'),
      hasLength(1),
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('archive uses the returned channel and no follow-up list read', (
    tester,
  ) async {
    final (workspace, api) = await pageFixture(tester);
    const project = {'id': 'project', 'name': 'Project', 'joined': true};
    workspace.channels = [RaftChannel(project)];
    var archiveCalls = 0;
    var listReads = 0;
    api.routes['GET /channels'] = (_) {
      listReads++;
      return [project];
    };
    api.routes['POST /channels/project/archive'] = (_) {
      archiveCalls++;
      return {...project, 'archivedAt': '2026-11-19T09:00:00Z'};
    };
    await mountPage(tester, workspace, false);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    final before = listReads;
    final row = _key('sidebar-channel-project');
    await _contextMenu(tester, row);
    expect(find.text('Leave channel'), findsOneWidget);
    await tester.tap(_key('sidebar-menu-archive'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();
    expect(archiveCalls, 1);
    expect(listReads, before);
    expect(row, findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets(
    'leave mutates only after confirmation and preserves unjoined rows',
    (tester) async {
      final (workspace, api) = await pageFixture(tester);
      workspace.channels = [
        RaftChannel({'id': 'project', 'name': 'Project', 'joined': true}),
      ];
      api.routes['POST /channels/project/leave'] = (_) => {};
      await mountPage(tester, workspace, false);
      addTearDown(() => tester.pumpWidget(const SizedBox()));
      final row = _key('sidebar-channel-project');
      Future<void> openLeave() async {
        await _contextMenu(tester, row);
        await tester.tap(_key('sidebar-menu-leave'));
        await tester.pumpAndSettle();
      }

      await openLeave();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      final commands = api.calls.where(
        (call) => call.path == '/channels/project/leave',
      );
      expect(commands, isEmpty);
      await openLeave();
      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();
      expect(commands, hasLength(1));
      expect(
        api.calls.where((call) => call.path == '/channels/project/members'),
        isEmpty,
      );
      expect(workspace.channelById('project')?.joined, isFalse);
      expect(_key('sidebar-channel-leave-confirmation'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets('external invite retry reuses the created private channel', (
    tester,
  ) async {
    final (workspace, api) = await pageFixture(tester);
    api.routes['POST /feature-flags/evaluate'] = (request) => {
      'evaluations': [
        for (final key in request.data['keys'] as List)
          {'key': key, 'enabled': key == 'external_channels_v1'},
      ],
    };
    api.routes['GET /channels/external-availability'] = (_) => {};
    api.routes['GET /channels/external-connect-servers'] = (_) => {
      'servers': [],
    };
    api.routes['POST /channels/external-invites/preview'] = (request) => {
      'valid': request.data['emails'],
    };
    var created = 0, invited = 0;
    api.routes['POST /channels'] = (request) {
      created++;
      expect(request.data['visibility'], 'private');
      return {'id': 'new-channel', 'name': 'partner-review', 'joined': true};
    };
    api.routes['POST /channels/new-channel/external-invites'] = (_) {
      invited++;
      return invited == 1 ? (503, {'error': 'Temporary failure'}) : {};
    };
    await mountPage(tester, workspace, false);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await _contextMenu(tester, _key('workspace-sidebar'));
    await tester.tap(find.text('Create external channel'));
    await tester.pumpAndSettle();
    await tester.enterText(_key('create-channel-name'), 'partner-review');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Add people to #partner-review'), findsOneWidget);
    await tester.enterText(
      _key('external-invite-emails'),
      'sidebar@example.invalid',
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: _key('create-external-channel-invites'),
        matching: find.text('Create and invite'),
      ),
    );
    await tester.pumpAndSettle();
    expect((created, invited), (0, 0));
    await tester.tap(find.text('Create and invite'));
    await tester.pumpAndSettle();
    expect((created, invited), (1, 1));
    expect(find.textContaining('was created, but'), findsOneWidget);
    await tester.tap(find.text('Invite'));
    await tester.pumpAndSettle();
    expect((created, invited), (1, 2));
    expect(_key('create-external-channel-invites'), findsNothing);
    expect(find.textContaining('was created, but'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
}
