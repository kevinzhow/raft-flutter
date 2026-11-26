import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/channel_settings.dart';
import 'package:raft_flutter/features/channel_side_flags.dart';
import 'package:raft_flutter/features/channel_side_store.dart';
import 'package:raft_flutter/features/message_task_actions.dart';
import 'package:raft_flutter/features/quick_switcher.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../message_presentation_test.dart' show MessageAdapter;
import '../workspace_activity_activation_test.dart' show channelRow, message;
import '../workspace_source_location_contract_test.dart' show pageFixture;
import 'app_services_fixture.dart';

const sidePanelMatrixSizes = <(String, Size, TargetPlatform)>[
  ('360x640', Size(360, 640), TargetPlatform.android),
  ('412x915', Size(412, 915), TargetPlatform.android),
  ('412x450', Size(412, 450), TargetPlatform.android),
  ('640x360', Size(640, 360), TargetPlatform.android),
  ('600x960', Size(600, 960), TargetPlatform.android),
  ('915x412', Size(915, 412), TargetPlatform.android),
  ('841x701', Size(841, 701), TargetPlatform.android),
  ('856x944', Size(856, 944), TargetPlatform.android),
  ('884x1104', Size(884, 1104), TargetPlatform.android),
  ('944x856', Size(944, 856), TargetPlatform.android),
  ('1180x820', Size(1180, 820), TargetPlatform.android),
  ('1440x900', Size(1440, 900), TargetPlatform.linux),
];

bool isPhoneHostSize(Size size) => size.width < 768 || size.height < 480;

Future<(WorkspaceController, MessageAdapter)> mountSidePanelMatrixWorkspace(
  WidgetTester t,
  Size size, {
  TargetPlatform platform = TargetPlatform.android,
  String section = 'chat',
  RaftRoute initialRoute = RaftRoute.channel,
  String initialEntityId = 'c1',
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  DevicePreferences.reset();
  SharedPreferences.setMockInitialValues({});
  await t.runAsync(() async {
    DevicePreferences.adopt(await SharedPreferences.getInstance());
  });
  addTearDown(DevicePreferences.reset);

  final (w, api) = await pageFixture(t, section: section);
  w.server = RaftRecord({
    'id': 's1',
    'slug': 'demo',
    'name': 'Demo',
    'role': 'owner',
  });
  final channel = RaftChannel({
    ...w.channel!.json,
    'id': 'c1',
    'name': 'general',
    'channelCapabilities': {
      'editChannelMetadata': true,
      'archiveChannels': false,
      'deleteChannels': false,
    },
  });
  final lounge = RaftChannel({
    'id': 'l1',
    'name': 'martin-lounge',
    'type': 'channel',
    'joined': true,
    'loungeAgentId': 'agent-martin',
    'canPost': true,
  });
  final humanDm = RaftChannel({
    'id': 'd-human',
    'name': 'Bob',
    'type': 'dm',
    'joined': true,
    'peerId': 'bob',
    'peerType': 'user',
    'peerName': 'bob',
    'peerDisplayName': 'Bob',
  });
  final agentDm = RaftChannel({
    'id': 'd-agent',
    'name': 'Martin',
    'type': 'dm',
    'joined': true,
    'peerId': 'agent-martin',
    'peerType': 'agent',
    'peerName': 'martin',
    'peerDisplayName': 'Martin',
  });
  w.channels = [channel, lounge];
  w.dms = [humanDm, agentDm];
  w.channel = switch (initialEntityId) {
    'l1' => lounge,
    'd-human' => humanDm,
    'd-agent' => agentDm,
    _ => channel,
  };
  if (section == 'chat') {
    w.navigation.navigate(
      RaftLocation.at(
        serverSlug: 'demo',
        route: initialRoute,
        entityId: initialEntityId,
      ),
    );
  }

  const martinAgent = {
    'id': 'agent-martin',
    'userId': 'agent-martin',
    'name': 'martin',
    'displayName': 'Martin',
    'status': 'online',
    'runtime': 'claude',
    'model': 'sonnet',
    'activity': 'online',
  };
  const bobMember = {
    'userId': 'bob',
    'name': 'bob',
    'displayName': 'Bob',
    'role': 'member',
  };
  api.routes.addAll({
    'GET /channels': (_) => [channel.json, lounge.json],
    'GET /channels/dm': (_) => [humanDm.json, agentDm.json],
    'GET /channels/c1': (_) => channel.json,
    'GET /channels/l1': (_) => lounge.json,
    'GET /channels/d-human': (_) => humanDm.json,
    'GET /channels/d-agent': (_) => agentDm.json,
    'GET /agents': (_) => [martinAgent],
    'GET /agents/agent-martin': (_) => martinAgent,
    'GET /agents/agent-martin/skills': (_) => {'global': [], 'workspace': []},
    'POST /agents/agent-martin/lounge': (_) => {
      'channel': lounge.json,
      'joined': true,
      'canPost': true,
    },
    'POST /feature-flags/evaluate': (_) => {
      'evaluations': [
        {'key': 'agent_lounge_v0', 'enabled': true},
      ],
    },
    'GET /servers/s1/machines': (_) => {'machines': []},
    'GET /servers/s1/members': (_) => [bobMember],
    'GET /servers/s1/members/bob/profile': (_) => bobMember,
    'GET /channels/inbox': (_) => {
      'items': [
        {
          ...channelRow,
          'kind': 'dm',
          'channelId': 'd-agent',
          'channelName': 'Martin',
          'firstUnreadMessageId': 'm-dm',
        },
        {
          ...channelRow,
          'kind': 'channel',
          'channelId': 'c1',
          'channelName': 'general',
          'firstUnreadMessageId': 'm-ch',
        },
      ],
    },
    'GET /messages/search': (_) => {
      'results': [
        {
          ...message('m-dm', 'd-agent'),
          'channelName': 'Martin',
          'channelType': 'dm',
          'content': 'needle dm',
        },
        {
          ...message('m-ch', 'c1'),
          'channelName': 'general',
          'channelType': 'channel',
          'content': 'needle channel',
        },
      ],
      'hasMore': false,
    },
    'GET /messages/context/m-dm': (_) => {
      'messages': [message('m-dm', 'd-agent')],
    },
    'GET /messages/context/m-ch': (_) => {
      'messages': [message('m-ch', 'c1')],
    },
    'GET /messages/channel/d-agent': (_) => {
      'messages': [
        {...message('m-dm', 'd-agent'), 'replyCount': 1},
      ],
    },
    'GET /messages/channel/d-human': (_) => {
      'messages': [message('m-h', 'd-human')],
    },
    'GET /messages/channel/c1': (_) => {
      'messages': [
        {...message('m-ch', 'c1'), 'replyCount': 1},
      ],
    },
    'GET /messages/channel/l1': (_) => {'messages': []},
    'GET /channels/c1/threads/m-ch': (_) => {'threadChannelId': 't1'},
    'GET /messages/channel/t1': (_) => {
      'messages': [message('m-ch', 't1')],
    },
    'POST /channels/d-agent/read': (_) => {},
    'POST /channels/d-human/read': (_) => {},
    'POST /channels/c1/read': (_) => {},
    'POST /channels/l1/read': (_) => {},
    'POST /channels/t1/read': (_) => {},
    for (final id in ['c1', 'l1', 'd-human', 'd-agent']) ...{
      'GET /tasks/channel/$id': (_) => {'tasks': [], 'nextCursor': null},
      'GET /channels/$id/files': (_) => {'files': [], 'nextCursor': null},
      'GET /channels/$id/announcement': (_) => {'announcement': null},
      'GET /channels/$id/members': (_) => {'humans': [], 'agents': []},
      'GET /channels/$id/message-display-settings': (_) => {},
      'GET /channels/$id/notification-settings': (_) => {},
    },
    'GET /announcements/active': (_) => {'announcements': []},
  });

  await t.runAsync(() async {
    ChannelSideStore.of(w);
    ChannelSideFlags.of(w);
    await Future<void>.delayed(const Duration(milliseconds: 20));
  });
  TaskV2ConversationsFlag.of(w).markEnabled();

  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme().copyWith(platform: platform),
      builder: (_, child) => RaftToastHost(child: child!),
      home: withAppServices(
        WorkspaceView(
          controller: w,
          appearance: const RaftAppearance(),
          onAppearance: (_) async {},
          onLogout: () async {},
        ),
      ),
    ),
  );
  await matrixFrames(t, 6);
  return (w, api);
}

Future<void> matrixFrames(WidgetTester t, [int count = 5]) async {
  for (var i = 0; i < count; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 8)),
    );
    await t.pump(const Duration(milliseconds: 40));
  }
}

Future<void> unmountMatrixWorkspace(WidgetTester t) async {
  await t.pumpWidget(const SizedBox.shrink());
  await t.pumpAndSettle();
}

Tristate? toggleState(WidgetTester t, Finder finder) =>
    t.getSemantics(finder).getSemanticsData().flagsCollection.isToggled;

void expectPanelOnScreen(
  WidgetTester t,
  Finder surface,
  Size window, {
  String? reason,
}) {
  expect(surface, findsOneWidget, reason: reason);
  expect(surface.hitTestable(), findsOneWidget, reason: reason);
  final rect = t.getRect(surface);
  expect(rect.width, greaterThan(0), reason: reason);
  expect(rect.height, greaterThan(0), reason: reason);
  final visible = rect.intersect(Offset.zero & window);
  expect(visible.width, greaterThan(0), reason: reason);
  expect(visible.height, greaterThan(0), reason: reason);
  expect(
    visible.width * visible.height,
    greaterThanOrEqualTo(rect.width * rect.height * 0.5),
    reason: reason ?? 'surface must be >=50% inside viewport',
  );
  final ro = t.renderObject(surface);
  final hit = t.hitTestOnBinding(visible.center);
  expect(
    hit.path.any((entry) => identical(entry.target, ro)),
    isTrue,
    reason: reason ?? 'center tap must hit the target surface',
  );
}

void expectTogglesMatchVisibility(WidgetTester t, Size window) {
  final tasksShown = find
      .byKey(const Key('channel-side-card-tasks'))
      .hitTestable()
      .evaluate()
      .isNotEmpty;
  final filesShown = find
      .byKey(const Key('channel-side-card-files'))
      .hitTestable()
      .evaluate()
      .isNotEmpty;
  final tasksToggle = find.byKey(const Key('channel-tasks-toggle'));
  final filesToggle = find.byKey(const Key('channel-files-toggle'));
  if (tasksToggle.hitTestable().evaluate().isNotEmpty) {
    expect(
      toggleState(t, tasksToggle),
      tasksShown ? Tristate.isTrue : Tristate.isFalse,
    );
  }
  if (filesToggle.hitTestable().evaluate().isNotEmpty) {
    expect(
      toggleState(t, filesToggle),
      filesShown ? Tristate.isTrue : Tristate.isFalse,
    );
  }
  if (tasksShown) {
    expectPanelOnScreen(
      t,
      find.byKey(const Key('channel-side-card-tasks')),
      window,
    );
  }
  if (filesShown) {
    expectPanelOnScreen(
      t,
      find.byKey(const Key('channel-side-card-files')),
      window,
    );
  }
}

Future<void> exerciseConversationHeaderButtons(
  WidgetTester t,
  WorkspaceController w,
  Size size, {
  String? profileKey,
  bool checkLounge = false,
  VoidCallback? beforeBack,
}) async {
  final phone = isPhoneHostSize(size);
  expect(
    find.byKey(const Key('workspace-top-bar')),
    phone ? findsNothing : findsOneWidget,
  );

  final tasksToggle = find.byKey(const Key('channel-tasks-toggle'));
  final filesToggle = find.byKey(const Key('channel-files-toggle'));
  expect(tasksToggle.hitTestable(), findsOneWidget);
  expect(filesToggle.hitTestable(), findsOneWidget);
  expectTogglesMatchVisibility(t, size);

  // Tasks: open via toggle -> >=50% visible & hit-testable; tap Back -> gone.
  await t.tap(tasksToggle);
  await matrixFrames(t);
  final tasksCard = find.byKey(const Key('channel-side-card-tasks'));
  expectPanelOnScreen(t, tasksCard, size);
  expectTogglesMatchVisibility(t, size);
  if (phone) {
    expect(find.byKey(const Key('channel-side-overlay')), findsOneWidget);
    await t.tap(tasksToggle);
  } else {
    final covering = find
        .byKey(const Key('channel-side-overlay'))
        .evaluate()
        .isNotEmpty;
    final backOrClose = find.byKey(
      Key(
        covering
            ? 'channel-side-card-tasks-back'
            : 'channel-side-card-tasks-close',
      ),
    );
    await t.tap(backOrClose);
  }
  await matrixFrames(t);
  expect(tasksCard, findsNothing);
  expectTogglesMatchVisibility(t, size);

  // Files: open via toggle -> Back closes it cleanly.
  await t.tap(filesToggle);
  await matrixFrames(t);
  final filesCard = find.byKey(const Key('channel-side-card-files'));
  expectPanelOnScreen(t, filesCard, size);
  expectTogglesMatchVisibility(t, size);
  if (phone) {
    await t.tap(find.byKey(const Key('mobile-detail-back')));
  } else {
    final covering = find
        .byKey(const Key('channel-side-overlay'))
        .evaluate()
        .isNotEmpty;
    await t.tap(
      find.byKey(
        Key(
          covering
              ? 'channel-side-card-files-back'
              : 'channel-side-card-files-close',
        ),
      ),
    );
  }
  await matrixFrames(t);
  expect(filesCard, findsNothing);
  expectTogglesMatchVisibility(t, size);

  // Settings / Details button.
  await t.tap(find.byKey(const Key('channel-overflow-trigger')));
  await t.pumpAndSettle();
  if (phone) {
    expectPanelOnScreen(t, find.byType(ChannelSettings), size);
    await t.tap(find.byKey(const ValueKey('channel-overflow-back')));
    await t.pumpAndSettle();
    expect(find.byType(ChannelSettings), findsNothing);
  } else {
    final details = find.byKey(const Key('channel-details'));
    expectPanelOnScreen(t, details, size);
    final covering = find
        .byKey(const Key('channel-side-overlay'))
        .evaluate()
        .isNotEmpty;
    await t.tap(
      find.byKey(
        Key(covering ? 'channel-overflow-back' : 'channel-details-close'),
      ),
    );
    await t.pumpAndSettle();
    expect(details, findsNothing);
  }

  // Search button.
  await t.tap(find.byKey(const Key('channel-topbar-search')));
  await t.pumpAndSettle();
  if (phone) {
    expect(w.section, 'search');
    beforeBack?.call();
    await t.tap(find.byTooltip('Back').first);
    await t.pumpAndSettle();
  } else {
    expectPanelOnScreen(t, find.byType(QuickSwitcher), size);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    expect(find.byType(QuickSwitcher), findsNothing);
  }

  // Avatar -> Profile panel / page (Human DM, Agent DM, Lounge).
  if (profileKey != null) {
    await t.tap(find.byKey(const Key('dm-header-avatar-button')));
    await matrixFrames(t, 6);
    final profile = find.byKey(ValueKey(profileKey));
    expectPanelOnScreen(t, profile, size);
    if (phone) {
      await t.tap(
        find.descendant(of: profile, matching: find.byTooltip('Back')).first,
      );
      await t.pumpAndSettle();
    } else {
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await matrixFrames(t, 6);
    }
    expect(profile, findsNothing);
  }

  // Lounge button on Agent DM.
  if (checkLounge) {
    final loungeBtn = find.byKey(const ValueKey('agent-dm-open-lounge'));
    expect(loungeBtn.hitTestable(), findsOneWidget);
    await t.tap(loungeBtn);
    await matrixFrames(t, 6);
    expect(
      find.byKey(const ValueKey('lounge-audience-notice')),
      findsOneWidget,
    );
  }
}
