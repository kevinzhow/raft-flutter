// Regression tests for #raft-flutter:#376:
// Tapping Tasks or Files in a conversation header must always open a visible,
// interactive, dismissible panel, and toggle active states must reflect what is
// actually on screen across Activity/Search detail routes and narrow/compact
// Android foldable / desktop window widths.
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/channel_details_host.dart';
import 'package:raft_flutter/features/channel_settings.dart';
import 'package:raft_flutter/features/channel_side_flags.dart';
import 'package:raft_flutter/features/channel_side_store.dart';
import 'package:raft_flutter/features/message_task_actions.dart';
import 'package:raft_flutter/features/page_layout.dart';
import 'package:raft_flutter/features/quick_switcher.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'flutter_test_config.dart' show leakDebt;
import 'message_presentation_test.dart' show MessageAdapter;
import 'support/app_services_fixture.dart';
import 'workspace_activity_activation_test.dart' show channelRow, message;
import 'workspace_source_location_contract_test.dart' show pageFixture;

Future<(WorkspaceController, MessageAdapter)> _mount(
  WidgetTester t,
  Size size, {
  required String section,
  TargetPlatform platform = TargetPlatform.android,
  bool taskV2 = true,
  bool openDm = true,
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
  final channel = RaftChannel({
    ...w.channel!.json,
    'name': 'general',
    'channelCapabilities': {
      'editChannelMetadata': true,
      'archiveChannels': false,
      'deleteChannels': false,
    },
  });
  final dm = RaftChannel({
    'id': 'd1',
    'name': 'Martin',
    'type': 'dm',
    'joined': true,
    'peerId': 'agent-martin',
    'peerType': 'agent',
    'peerDisplayName': 'Martin',
  });
  w.channels = [channel];
  w.dms = [dm];
  w.channel = openDm ? dm : channel;

  const martinAgent = {
    'id': 'agent-martin',
    'userId': 'agent-martin',
    'name': 'martin',
    'displayName': 'Martin',
    'status': 'online',
    'runtime': 'claude',
    'model': 'sonnet',
  };
  api.routes.addAll({
    'GET /agents': (_) => [martinAgent],
    'GET /agents/agent-martin': (_) => martinAgent,
    'GET /agents/agent-martin/skills': (_) => {'global': [], 'workspace': []},
    'GET /servers/s1/machines': (_) => {'machines': []},
    'GET /servers/s1/members': (_) => [
      {'userId': 'bob', 'name': 'bob', 'displayName': 'Bob', 'role': 'member'},
    ],
    'GET /servers/s1/members/bob/profile': (_) => {
      'userId': 'bob',
      'name': 'bob',
      'displayName': 'Bob',
      'role': 'member',
    },
    'GET /channels/inbox': (_) => {
      'items': [
        {
          ...channelRow,
          'kind': 'dm',
          'channelId': 'd1',
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
          ...message('m-dm', 'd1'),
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
      'messages': [message('m-dm', 'd1')],
    },
    'GET /messages/context/m-ch': (_) => {
      'messages': [message('m-ch', 'c1')],
    },
    'GET /messages/channel/d1': (_) => {
      'messages': [
        {...message('m-dm', 'd1'), 'replyCount': 1},
      ],
    },
    'GET /messages/channel/c1': (_) => {
      'messages': [
        {...message('m-ch', 'c1'), 'replyCount': 1},
      ],
    },
    'GET /channels/d1/threads/m-dm': (_) => {'threadChannelId': 't-dm'},
    'GET /channels/c1/threads/m-ch': (_) => {'threadChannelId': 't-ch'},
    'GET /messages/channel/t-dm': (_) => {
      'messages': [message('m-dm', 't-dm')],
    },
    'GET /messages/channel/t-ch': (_) => {
      'messages': [message('m-ch', 't-ch')],
    },
    'GET /tasks/channel/d1': (_) => {'tasks': [], 'nextCursor': null},
    'GET /tasks/channel/c1': (_) => {'tasks': [], 'nextCursor': null},
    'GET /channels/d1/files': (_) => {'files': [], 'nextCursor': null},
    'GET /channels/c1/files': (_) => {'files': [], 'nextCursor': null},
    'GET /channels/d1/announcement': (_) => {'announcement': null},
    'GET /channels/c1/announcement': (_) => {'announcement': null},
    'GET /announcements/active': (_) => {'announcements': []},
    'GET /channels/d1/members': (_) => {'humans': [], 'agents': []},
    'GET /channels/c1/members': (_) => {'humans': [], 'agents': []},
    'GET /channels/d1/message-display-settings': (_) => {},
    'GET /channels/c1/message-display-settings': (_) => {},
    'GET /channels/d1/notification-settings': (_) => {},
    'GET /channels/c1/notification-settings': (_) => {},
    'POST /channels/d1/read': (_) => {},
    'POST /channels/t-dm/read': (_) => {},
    'POST /channels/t-ch/read': (_) => {},
  });

  await t.runAsync(() async {
    ChannelSideStore.of(w);
    ChannelSideFlags.of(w);
    await Future<void>.delayed(const Duration(milliseconds: 20));
  });
  if (taskV2) TaskV2ConversationsFlag.of(w).markEnabled();

  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme().copyWith(platform: platform),
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
  await _frames(t, 12);
  return (w, api);
}

Future<void> _frames(WidgetTester t, [int count = 8]) async {
  for (var i = 0; i < count; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await t.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _unmount(WidgetTester t) async {
  await t.pumpWidget(const SizedBox.shrink());
  await t.pumpAndSettle();
}

Future<void> _openDetailRow(
  WidgetTester t,
  String section, {
  required bool dm,
}) async {
  if (section == 'search') {
    await t.enterText(find.byType(TextField).first, 'needle');
    await t.pump(const Duration(milliseconds: 220));
    await _frames(t, 8);
    final rows = find.byType(RaftSearchResultSurface);
    await t.tap(dm ? rows.first : rows.last);
  } else {
    final key = ValueKey(dm ? 'activity-dm-d1' : 'activity-channel-c1');
    await t.tap(find.byKey(key));
  }
  await _frames(t, 10);
}

Tristate? _toggled(WidgetTester t, Finder finder) =>
    t.getSemantics(finder).getSemanticsData().flagsCollection.isToggled;

void main() {
  leakDebt(const ['SourceChannelFilesStore']);

  for (final section in ['activity', 'search']) {
    for (final (label, size, platform) in [
      ('medium 805x826', const Size(805, 826), TargetPlatform.android),
      ('medium 841x701', const Size(841, 701), TargetPlatform.android),
      ('medium 884x1104', const Size(884, 1104), TargetPlatform.android),
      ('wide 1180x820', const Size(1180, 820), TargetPlatform.android),
      ('wide 1280x900', const Size(1280, 900), TargetPlatform.linux),
    ]) {
      testWidgets(
        '$section DM detail at $label: Tasks, Files, Search, Settings, Thread all open visible surfaces',
        (t) async {
          final semantics = t.ensureSemantics();
          try {
            final (w, _) = await _mount(
              t,
              size,
              section: section,
              platform: platform,
            );
            await _openDetailRow(t, section, dm: true);
            expect(find.byType(RaftDmHeader), findsOneWidget);

            final detailFinder = find.byKey(
              const Key('desktop-content-detail'),
            );
            final detailRect = t.getRect(detailFinder);
            final tasksToggle = find.byKey(const Key('channel-tasks-toggle'));
            final filesToggle = find.byKey(const Key('channel-files-toggle'));
            expect(tasksToggle.hitTestable(), findsOneWidget);
            expect(filesToggle.hitTestable(), findsOneWidget);
            expect(_toggled(t, tasksToggle), Tristate.isFalse);
            expect(_toggled(t, filesToggle), Tristate.isFalse);

            // 1. Tap Tasks -> visible Tasks card inside the detail pane only.
            await t.tap(tasksToggle);
            await _frames(t, 8);
            expect(
              find.byKey(const Key('channel-side-card-tasks')).hitTestable(),
              findsOneWidget,
            );
            expect(_toggled(t, tasksToggle), Tristate.isTrue);
            expect(_toggled(t, filesToggle), Tristate.isFalse);
            final tasksCovering = find
                .byKey(const Key('channel-side-overlay'))
                .evaluate()
                .isNotEmpty;
            if (tasksCovering) {
              expect(
                t.getRect(find.byKey(const Key('channel-side-overlay'))),
                detailRect,
              );
              await t.tap(
                find.byKey(const Key('channel-side-card-tasks-back')),
              );
            } else {
              expect(
                find.byKey(const Key('channel-side-column-1')),
                findsOneWidget,
              );
              expect(
                t.getRect(find.byKey(const Key('channel-side-column-1'))).right,
                closeTo(detailRect.right, 1.0),
              );
              await t.tap(
                find.byKey(const Key('channel-side-card-tasks-close')),
              );
            }
            await _frames(t, 8);
            expect(
              find.byKey(const Key('channel-side-card-tasks')),
              findsNothing,
            );
            expect(_toggled(t, tasksToggle), Tristate.isFalse);

            // 2. Tap Files -> visible Files card, then close cleanly.
            await t.tap(filesToggle);
            await _frames(t, 8);
            expect(
              find.byKey(const Key('channel-side-card-files')).hitTestable(),
              findsOneWidget,
            );
            expect(_toggled(t, filesToggle), Tristate.isTrue);
            final filesCovering = find
                .byKey(const Key('channel-side-overlay'))
                .evaluate()
                .isNotEmpty;
            if (filesCovering) {
              expect(
                t.getRect(find.byKey(const Key('channel-side-overlay'))),
                detailRect,
              );
              await t.tap(
                find.byKey(const Key('channel-side-card-files-back')),
              );
            } else {
              await t.tap(
                find.byKey(const Key('channel-side-card-files-close')),
              );
            }
            await _frames(t, 8);
            expect(
              find.byKey(const Key('channel-side-card-files')),
              findsNothing,
            );
            expect(_toggled(t, filesToggle), Tristate.isFalse);

            // 3. When room allows beside (1280x900), opening both Tasks & Files
            //    renders both stacked with both toggles active.
            if (!tasksCovering) {
              await t.tap(tasksToggle);
              await _frames(t, 6);
              await t.tap(filesToggle);
              await _frames(t, 6);
              expect(
                find.byKey(const Key('channel-side-card-tasks')).hitTestable(),
                findsOneWidget,
              );
              expect(
                find.byKey(const Key('channel-side-card-files')).hitTestable(),
                findsOneWidget,
              );
              expect(_toggled(t, tasksToggle), Tristate.isTrue);
              expect(_toggled(t, filesToggle), Tristate.isTrue);
              await t.tap(
                find.byKey(const Key('channel-side-card-tasks-close')),
              );
              await t.tap(
                find.byKey(const Key('channel-side-card-files-close')),
              );
              await _frames(t, 6);
            }

            // 4. Settings (channel details) opens visible Details and closes cleanly.
            await t.tap(find.byKey(const Key('channel-overflow-trigger')));
            await _frames(t, 8);
            expect(find.byKey(const Key('channel-details')), findsOneWidget);
            final detailsCovering = find
                .byKey(const Key('channel-side-overlay'))
                .evaluate()
                .isNotEmpty;
            await t.tap(
              find.byKey(
                Key(
                  detailsCovering
                      ? 'channel-overflow-back'
                      : 'channel-details-close',
                ),
              ),
            );
            await _frames(t, 8);
            expect(find.byKey(const Key('channel-details')), findsNothing);

            // 5. Search opens QuickSwitcher and closes cleanly via Escape.
            await t.tap(find.byKey(const Key('channel-topbar-search')));
            await _frames(t, 6);
            expect(find.byType(QuickSwitcher), findsOneWidget);
            await t.sendKeyEvent(LogicalKeyboardKey.escape);
            await _frames(t, 6);
            expect(find.byType(QuickSwitcher), findsNothing);

            // 6. Thread opens and closes cleanly via Escape.
            await t.runAsync(
              () => w.openThreadIdentity(
                parentChannelId: 'd1',
                parentMessageId: 'm-dm',
                initialThreadChannelId: 't-dm',
              ),
            );
            await _frames(t, 8);
            expect(
              find.byKey(const Key('workspace-thread-header')),
              findsOneWidget,
            );
            await t.sendKeyEvent(LogicalKeyboardKey.escape);
            await _frames(t, 8);
            expect(
              find.byKey(const Key('workspace-thread-header')),
              findsNothing,
            );

            expect(t.takeException(), isNull);
          } finally {
            semantics.dispose();
            await _unmount(t);
          }
        },
      );
    }

    testWidgets(
      '$section Channel detail at 841x701 & 1280x900 exposes working Tasks and Files toggles',
      (t) async {
        for (final (size, platform) in [
          (const Size(841, 701), TargetPlatform.android),
          (const Size(1280, 900), TargetPlatform.linux),
        ]) {
          final (w, _) = await _mount(
            t,
            size,
            section: section,
            platform: platform,
            openDm: false,
          );
          await _openDetailRow(t, section, dm: false);
          expect(
            find.descendant(
              of: find.byKey(const Key('desktop-content-detail')),
              matching: find.byType(RaftPageHeader),
            ),
            findsOneWidget,
          );
          final tasksToggle = find.byKey(const Key('channel-tasks-toggle'));
          final filesToggle = find.byKey(const Key('channel-files-toggle'));
          expect(tasksToggle.hitTestable(), findsOneWidget);
          expect(filesToggle.hitTestable(), findsOneWidget);

          await t.tap(tasksToggle);
          await _frames(t, 8);
          expect(
            find.byKey(const Key('channel-side-card-tasks')),
            findsOneWidget,
          );
          final medium = size.width < 1024;
          await t.tap(
            find.byKey(
              Key(
                medium
                    ? 'channel-side-card-tasks-back'
                    : 'channel-side-card-tasks-close',
              ),
            ),
          );
          await _frames(t, 8);
          expect(
            find.byKey(const Key('channel-side-card-tasks')),
            findsNothing,
          );

          await t.tap(filesToggle);
          await _frames(t, 8);
          expect(
            find.byKey(const Key('channel-side-card-files')),
            findsOneWidget,
          );
          await t.tap(
            find.byKey(
              Key(
                medium
                    ? 'channel-side-card-files-back'
                    : 'channel-side-card-files-close',
              ),
            ),
          );
          await _frames(t, 8);
          expect(
            find.byKey(const Key('channel-side-card-files')),
            findsNothing,
          );
          expect(
            ChannelSideStore.of(w).cardOpen(ChannelSideCard.tasks),
            isFalse,
          );
          expect(
            ChannelSideStore.of(w).cardOpen(ChannelSideCard.files),
            isFalse,
          );
          expect(t.takeException(), isNull);
          await _unmount(t);
        }
      },
    );
  }

  testWidgets(
    'Escape on medium Activity DM detail closes Details but leaves Tasks card open',
    (t) async {
      final (w, _) = await _mount(
        t,
        const Size(841, 701),
        section: 'activity',
        platform: TargetPlatform.android,
      );
      try {
        await _openDetailRow(t, 'activity', dm: true);
        await t.tap(find.byKey(const Key('channel-tasks-toggle')));
        await _frames(t, 8);
        expect(
          find.byKey(const Key('channel-side-card-tasks')),
          findsOneWidget,
        );
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await _frames(t, 8);
        expect(
          find.byKey(const Key('channel-side-card-tasks')),
          findsOneWidget,
        );
        await t.tap(find.byKey(const Key('channel-side-card-tasks-back')));
        await _frames(t, 8);
        expect(find.byKey(const Key('channel-side-card-tasks')), findsNothing);

        ChannelDetailsStore.of(w).open(w.channel!, dmName: 'Martin');
        await _frames(t, 8);
        expect(find.byKey(const Key('channel-details')), findsOneWidget);
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await _frames(t, 8);
        expect(find.byKey(const Key('channel-details')), findsNothing);
        expect(t.takeException(), isNull);
      } finally {
        await _unmount(t);
      }
    },
  );

  testWidgets(
    'non-conversation routes never show leaked side cards or Details',
    (t) async {
      for (final section in [
        'activity',
        'search',
        'tasks',
        'members',
        'settings',
      ]) {
        final (w, _) = await _mount(
          t,
          const Size(1280, 900),
          section: section,
          platform: TargetPlatform.linux,
        );
        ChannelSideStore.of(w).setCardOpen(ChannelSideCard.tasks, true);
        ChannelSideStore.of(w).setCardOpen(ChannelSideCard.files, true);
        ChannelDetailsStore.of(w).open(w.channel!, dmName: 'Martin');
        await _frames(t, 8);
        expect(find.byKey(const Key('channel-side-card-tasks')), findsNothing);
        expect(find.byKey(const Key('channel-side-card-files')), findsNothing);
        expect(find.byKey(const Key('channel-details')), findsNothing);
        expect(find.byKey(const Key('channel-side-overlay')), findsNothing);
        if (section == 'activity') {
          w.navigation.navigate(w.location.withQuery({'open': 'human:bob'}));
          w.notifyListeners();
          await _frames(t, 8);
          expect(
            find.byKey(const Key('channel-side-card-tasks')),
            findsNothing,
          );
          expect(find.byKey(const Key('channel-details')), findsNothing);
        }
        expect(t.takeException(), isNull);
        await _unmount(t);
      }
    },
  );

  testWidgets(
    'compact/narrow Android split-screen and narrow desktop DM/Channel toggles open and close cleanly',
    (t) async {
      for (final (size, platform) in [
        (const Size(402, 826), TargetPlatform.android),
        (const Size(390, 844), TargetPlatform.linux),
        (const Size(480, 850), TargetPlatform.android),
        (const Size(600, 900), TargetPlatform.android),
        (const Size(700, 900), TargetPlatform.android),
      ]) {
        for (final dm in [true, false]) {
          final (w, _) = await _mount(
            t,
            size,
            section: 'chat',
            platform: platform,
            openDm: dm,
          );
          w.navigation.navigate(
            RaftLocation.at(
              serverSlug: 'demo',
              route: dm ? RaftRoute.dm : RaftRoute.channel,
              entityId: dm ? 'd1' : 'c1',
            ),
          );
          w.notifyListeners();
          await _frames(t, 8);

          // Tasks
          await t.tap(find.byKey(const Key('channel-tasks-toggle')));
          await _frames(t, 8);
          expect(find.byKey(const Key('channel-side-overlay')), findsOneWidget);
          expect(
            find.byKey(const Key('channel-side-card-tasks')),
            findsOneWidget,
          );
          await t.tap(find.byKey(const Key('mobile-detail-back')));
          await _frames(t, 8);
          expect(
            find.byKey(const Key('channel-side-card-tasks')),
            findsNothing,
          );

          // Files
          await t.tap(find.byKey(const Key('channel-files-toggle')));
          await _frames(t, 8);
          expect(find.byKey(const Key('channel-side-overlay')), findsOneWidget);
          expect(
            find.byKey(const Key('channel-side-card-files')),
            findsOneWidget,
          );
          await t.tap(find.byKey(const Key('mobile-detail-back')));
          await _frames(t, 8);
          expect(
            find.byKey(const Key('channel-side-card-files')),
            findsNothing,
          );

          // Settings -> ChannelSettings page -> Back
          await t.tap(find.byKey(const Key('channel-overflow-trigger')));
          await t.pumpAndSettle();
          expect(find.byType(ChannelSettings), findsOneWidget);
          await t.tap(find.byKey(const ValueKey('channel-overflow-back')));
          await t.pumpAndSettle();
          expect(find.byType(ChannelSettings), findsNothing);

          // Search -> scoped Search page -> Back
          await t.tap(find.byKey(const Key('channel-topbar-search')));
          await t.pumpAndSettle();
          expect(w.section, 'search');
          await t.tap(find.byTooltip('Back').first);
          await t.pumpAndSettle();

          expect(t.takeException(), isNull);
          await _unmount(t);
        }
      }
    },
  );

  testWidgets(
    'unfolded 841x701 Activity DM detail with Tasks open translates to 402x826 keeping Tasks visible',
    (t) async {
      final (w, _) = await _mount(
        t,
        const Size(841, 701),
        section: 'activity',
        platform: TargetPlatform.android,
      );
      try {
        await _openDetailRow(t, 'activity', dm: true);
        await t.tap(find.byKey(const Key('channel-tasks-toggle')));
        await _frames(t, 8);
        expect(
          find.byKey(const Key('channel-side-card-tasks')),
          findsOneWidget,
        );

        t.view.physicalSize = const Size(402, 826);
        await _frames(t, 10);
        expect(w.location.route, RaftRoute.dm);
        expect(w.location.entityId, 'd1');
        expect(find.byKey(const Key('channel-side-overlay')), findsOneWidget);
        expect(
          find.byKey(const Key('channel-side-card-tasks')),
          findsOneWidget,
        );

        await t.tap(find.byKey(const Key('mobile-detail-back')));
        await _frames(t, 8);
        expect(find.byKey(const Key('channel-side-card-tasks')), findsNothing);
        expect(t.takeException(), isNull);
      } finally {
        await _unmount(t);
      }
    },
  );

  testWidgets(
    'compact/narrow split-screen (402x826, 390x844): toggle highlights only rendered card and brings hidden card to front',
    (t) async {
      final semantics = t.ensureSemantics();
      try {
        for (final (size, platform) in [
          (const Size(402, 826), TargetPlatform.android),
          (const Size(390, 844), TargetPlatform.linux),
        ]) {
          final (w, _) = await _mount(
            t,
            size,
            section: 'chat',
            platform: platform,
            openDm: true,
          );
          w.navigation.navigate(
            RaftLocation.at(
              serverSlug: 'demo',
              route: RaftRoute.dm,
              entityId: 'd1',
            ),
          );
          w.notifyListeners();
          await _frames(t, 8);

          final tasksToggle = find.byKey(const Key('channel-tasks-toggle'));
          final filesToggle = find.byKey(const Key('channel-files-toggle'));
          expect(_toggled(t, tasksToggle), Tristate.isFalse);
          expect(_toggled(t, filesToggle), Tristate.isFalse);

          // Open Tasks: only Tasks lights up.
          await t.tap(tasksToggle);
          await _frames(t, 8);
          expect(
            find.byKey(const Key('channel-side-card-tasks')).hitTestable(),
            findsOneWidget,
          );
          expect(_toggled(t, tasksToggle), Tristate.isTrue);
          expect(_toggled(t, filesToggle), Tristate.isFalse);

          // Open Files: overlay switches to Files; Tasks is hidden behind the
          // switch so its toggle turns off while Files lights up.
          await t.tap(filesToggle);
          await _frames(t, 8);
          expect(
            find.byKey(const Key('channel-side-card-files')).hitTestable(),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('channel-side-card-tasks')).hitTestable(),
            findsNothing,
          );
          expect(_toggled(t, filesToggle), Tristate.isTrue);
          expect(_toggled(t, tasksToggle), Tristate.isFalse);

          // Tap Tasks while hidden: brings Tasks back to the front instead of closing it.
          await t.tap(tasksToggle);
          await _frames(t, 8);
          expect(
            find.byKey(const Key('channel-side-card-tasks')).hitTestable(),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('channel-side-card-files')).hitTestable(),
            findsNothing,
          );
          expect(_toggled(t, tasksToggle), Tristate.isTrue);
          expect(_toggled(t, filesToggle), Tristate.isFalse);

          // Tap Tasks while shown: closes Tasks cleanly and switches to Files.
          await t.tap(tasksToggle);
          await _frames(t, 8);
          expect(
            find.byKey(const Key('channel-side-card-tasks')),
            findsNothing,
          );
          expect(_toggled(t, tasksToggle), Tristate.isFalse);
          expect(_toggled(t, filesToggle), Tristate.isTrue);

          await t.tap(filesToggle);
          await _frames(t, 8);
          expect(find.byKey(const Key('channel-side-overlay')), findsNothing);
          expect(_toggled(t, filesToggle), Tristate.isFalse);
          expect(t.takeException(), isNull);
          await _unmount(t);
        }
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'wide desktop (1100x800): stacked-behind Tasks unlights toggle and tapping brings Tasks forward',
    (t) async {
      final semantics = t.ensureSemantics();
      try {
        await _mount(
          t,
          const Size(1100, 800),
          section: 'chat',
          platform: TargetPlatform.linux,
          openDm: false,
        );
        final tasksToggle = find.byKey(const Key('channel-tasks-toggle'));
        expect(_toggled(t, tasksToggle), Tristate.isFalse);

        // Open Tasks beside chat.
        await t.tap(tasksToggle);
        await _frames(t, 8);
        expect(
          find.byKey(const Key('channel-side-card-tasks')).hitTestable(),
          findsOneWidget,
        );
        expect(_toggled(t, tasksToggle), Tristate.isTrue);

        // Open Details: Details takes the single wide side slot and pushes Tasks
        // behind the stack -> Tasks is no longer rendered, so its toggle unlights.
        await t.tap(find.byKey(const Key('channel-overflow-trigger')));
        await _frames(t, 8);
        expect(
          find.byKey(const Key('channel-details')).hitTestable(),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('channel-side-card-tasks')).hitTestable(),
          findsNothing,
        );
        expect(_toggled(t, tasksToggle), Tristate.isFalse);

        // Tapping Tasks while unlit brings Tasks forward into view.
        await t.tap(tasksToggle);
        await _frames(t, 8);
        expect(
          find.byKey(const Key('channel-side-card-tasks')).hitTestable(),
          findsOneWidget,
        );
        expect(_toggled(t, tasksToggle), Tristate.isTrue);
        expect(t.takeException(), isNull);
      } finally {
        semantics.dispose();
        await _unmount(t);
      }
    },
  );
}
