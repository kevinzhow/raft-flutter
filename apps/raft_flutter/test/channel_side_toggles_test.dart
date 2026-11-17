// With Task v2 the channel and DM headers carry the Tasks and Files toggles
// between Search and Settings, the chat has no Chat/Tasks/Files tab row, and
// the phone's header Back closes the open cards before the channel.
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/channel_side_flags.dart';
import 'package:raft_flutter/features/channel_side_store.dart';
import 'package:raft_flutter/features/conversation_panel.dart';
import 'package:raft_flutter/features/channel_side_area.dart';
import 'package:raft_flutter/features/message_task_actions.dart';
import 'package:raft_flutter/features/workspace_channel_header.dart';
import 'package:raft_flutter/features/workspace_dm_header.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'flutter_test_config.dart' show leakDebt;
import 'message_presentation_test.dart' show fixture;

Future<WorkspaceController> rig(WidgetTester t, {required bool taskV2}) async {
  DevicePreferences.reset();
  SharedPreferences.setMockInitialValues({});
  await t.runAsync(() async {
    DevicePreferences.adopt(await SharedPreferences.getInstance());
  });
  addTearDown(DevicePreferences.reset);
  final (w, transport) = (await t.runAsync(() => fixture('owner')))!;
  addTearDown(w.dispose);
  transport.routes['GET /agents'] = (_) => [];
  transport.routes['GET /servers/s1/members'] = (_) => [];
  transport.routes['GET /channels/c1/files'] = (_) => {
    'files': [],
    'nextCursor': null,
  };
  transport.routes['GET /tasks/channel/c1'] = (_) => {
    'tasks': [],
    'nextCursor': null,
  };
  // The flags ask the server once as they are made: finish that outside the
  // fake clock.
  await t.runAsync(() async {
    ChannelSideStore.of(w);
    ChannelSideFlags.of(w);
    await Future<void>.delayed(const Duration(milliseconds: 20));
  });
  if (taskV2) TaskV2ConversationsFlag.of(w).markEnabled();
  return w;
}

Future<void> pumpChannelHeader(
  WidgetTester t,
  WorkspaceController w, {
  VoidCallback? onBack,
  String type = 'channel',
}) => t.pumpWidget(
  MaterialApp(
    theme: raftTheme(),
    home: Scaffold(
      body: SizedBox(
        width: 700,
        child: WorkspaceChannelHeader(
          headerKey: const Key('header'),
          controller: w,
          channel: RaftChannel({
            'id': 'c1',
            'name': 'docs',
            'type': type,
            'joined': true,
          }),
          backLabel: 'Back',
          backKey: const Key('back'),
          onBack: onBack,
          onSearch: () {},
          onSettings: () {},
        ),
      ),
    ),
  ),
);

/// The chat's own reads answer outside the fake clock, then their timers fire.
Future<void> drain(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await t.pump(const Duration(milliseconds: 250));
  }
}

double cx(WidgetTester t, Finder f) => t.getCenter(f).dx;

void main() {
  leakDebt(const ['SourceChannelFilesStore']);

  group('the channel header', () {
    testWidgets('flag off: no toggles', (t) async {
      final w = await rig(t, taskV2: false);
      await pumpChannelHeader(t, w);
      expect(find.byKey(const Key('channel-tasks-toggle')), findsNothing);
      expect(find.byKey(const Key('channel-files-toggle')), findsNothing);
    });

    testWidgets(
      'flag on: Tasks and Files between Search and Settings, pressed when open, labelled',
      (t) async {
        final semantics = t.ensureSemantics();
        final w = await rig(t, taskV2: true);
        await pumpChannelHeader(t, w);
        final tasks = find.byKey(const Key('channel-tasks-toggle'));
        final files = find.byKey(const Key('channel-files-toggle'));
        final search = find.byKey(const Key('channel-topbar-search'));
        final settings = find.byKey(const Key('channel-overflow-trigger'));
        expect(cx(t, search), lessThan(cx(t, tasks)));
        expect(cx(t, tasks), lessThan(cx(t, files)));
        expect(cx(t, files), lessThan(cx(t, settings)));
        expect(t.getSemantics(tasks).getSemanticsData().label, 'Open Tasks');
        expect(t.getSemantics(files).getSemanticsData().label, 'Open files');
        expect(
          t.getSemantics(tasks).getSemanticsData().flagsCollection.isToggled,
          Tristate.isFalse,
        );

        await t.tap(tasks);
        await t.pump();
        final store = ChannelSideStore.of(w);
        expect(store.cardOpen(ChannelSideCard.tasks), isTrue);
        expect(store.cardOpen(ChannelSideCard.files), isFalse);
        expect(t.getSemantics(tasks).getSemanticsData().label, 'Close Tasks');
        expect(
          t.getSemantics(tasks).getSemanticsData().flagsCollection.isToggled,
          Tristate.isTrue,
        );

        await t.tap(files);
        await t.pump();
        expect(t.getSemantics(files).getSemanticsData().label, 'Close files');
        await t.tap(files);
        await t.pump();
        expect(store.cardOpen(ChannelSideCard.files), isFalse);
        await t.tap(tasks);
        await t.pump();
        expect(store.cardOpen(ChannelSideCard.tasks), isFalse);
        semantics.dispose();
      },
    );

    testWidgets('a thread gets none', (t) async {
      final w = await rig(t, taskV2: true);
      w.channel = RaftChannel({'id': 'c1', 'name': 't', 'type': 'thread'});
      await pumpChannelHeader(t, w, type: 'thread');
      expect(find.byKey(const Key('channel-tasks-toggle')), findsNothing);
    });

    testWidgets('Back closes the open cards first, then the channel', (
      t,
    ) async {
      final w = await rig(t, taskV2: true);
      var back = 0;
      await pumpChannelHeader(t, w, onBack: () => back++);
      final store = ChannelSideStore.of(w);
      store.setCardOpen(ChannelSideCard.tasks, true);
      store.setCardOpen(ChannelSideCard.files, true);
      await t.pump();
      await t.tap(find.byKey(const Key('back')));
      await t.pump();
      expect(store.cardOpen(ChannelSideCard.tasks), isFalse);
      expect(store.cardOpen(ChannelSideCard.files), isFalse);
      expect(back, 0);
      await t.tap(find.byKey(const Key('back')));
      expect(back, 1);
    });
  });

  testWidgets('the DM header has the toggles too, after the Lounge slot', (
    t,
  ) async {
    final w = await rig(t, taskV2: true);
    final dm = RaftChannel({'id': 'c1', 'name': 'bob', 'type': 'dm'});
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: Scaffold(
          body: SizedBox(
            width: 700,
            child: WorkspaceDmHeader(
              headerKey: const Key('header'),
              controller: w,
              channel: dm,
              agent: false,
              name: 'Bob',
              profile: null,
              avatar: const SizedBox.square(dimension: 36),
              selectionActive: () => false,
              onSearch: () {},
              onSettings: () {},
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('channel-tasks-toggle')), findsOne);
    expect(find.byKey(const Key('channel-files-toggle')), findsOne);
    await t.tap(find.byKey(const Key('channel-files-toggle')));
    await t.pump();
    expect(ChannelSideStore.of(w).cardOpen(ChannelSideCard.files), isTrue);
  });

  group('the chat panel', () {
    Future<void> pumpPanel(
      WidgetTester t,
      WorkspaceController w, {
      bool area = true,
    }) async {
      t.view.physicalSize = const Size(900, 700);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(),
          home: Scaffold(
            body: area
                ? ChannelSideArea(
                    controller: w,
                    child: ConversationPanel(controller: w),
                  )
                : ConversationPanel(controller: w),
          ),
        ),
      );
      await drain(t);
    }

    testWidgets('flag off: the Chat / Tasks / Files tabs stay', (t) async {
      final w = await rig(t, taskV2: false);
      await pumpPanel(t, w);
      expect(find.byKey(const Key('conversation-tabs')), findsOne);
    });

    testWidgets('flag on: no tab row', (t) async {
      final w = await rig(t, taskV2: true);
      await pumpPanel(t, w);
      expect(find.byKey(const Key('conversation-tabs')), findsNothing);
      expect(find.byType(RaftComposer), findsOne);
    });

    testWidgets(
      'flag on outside a side area (Search / Activity detail): tabs stay',
      (t) async {
        final w = await rig(t, taskV2: true);
        await pumpPanel(t, w, area: false);
        expect(find.byKey(const Key('conversation-tabs')), findsOne);
      },
    );

    testWidgets(
      'the flag turning on takes the tab row away without remounting the chat',
      (t) async {
        final w = await rig(t, taskV2: false);
        await pumpPanel(t, w);
        final composer = t.state(find.byType(RaftComposer));
        expect(find.byKey(const Key('conversation-tabs')), findsOne);
        TaskV2ConversationsFlag.of(w).markEnabled();
        await t.pump();
        expect(find.byKey(const Key('conversation-tabs')), findsNothing);
        expect(t.state(find.byType(RaftComposer)), same(composer));
        await drain(t);
      },
    );
  });
}
