import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/features/channel_side_cards.dart';
import 'package:raft_flutter/features/channel_side_store.dart';
import 'package:raft_flutter/features/message_task_actions.dart';
import 'package:raft_flutter/features/panel_width_store.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_services_fixture.dart';
import 'workspace_source_location_contract_test.dart' show pageFixture;

void main() {
  tearDown(DevicePreferences.reset);

  group('store (Web slock:profilePanelWidth)', () {
    test('400 until saved; under 300 is the default', () async {
      SharedPreferences.setMockInitialValues({});
      DevicePreferences.adopt(await SharedPreferences.getInstance());
      expect(profilePanelWidth.value, 400);
      profilePanelWidth.save(450);
      expect(profilePanelWidth.value, 450);
      // Beside the Members list the column may be wider than 600 (each host
      // clamps it to its room); a width the panel cannot have is never stored,
      // and a stored one from elsewhere that is out of bounds is the default.
      profilePanelWidth.save(900);
      expect(profilePanelWidth.value, 900);
      profilePanelWidth.save(120);
      expect(profilePanelWidth.value, 900);
      SharedPreferences.setMockInitialValues({profilePanelWidth.key: 120.0});
      DevicePreferences.adopt(await SharedPreferences.getInstance());
      expect(profilePanelWidth.value, 400);
    });

    test('the agent file tree: 256 by default, 160 to 600', () async {
      SharedPreferences.setMockInitialValues({});
      DevicePreferences.adopt(await SharedPreferences.getInstance());
      expect(workspaceTreeWidth.value, 256);
      workspaceTreeWidth.save(320);
      expect(workspaceTreeWidth.value, 320);
      workspaceTreeWidth.save(100);
      workspaceTreeWidth.save(700);
      expect(workspaceTreeWidth.value, 320);
      // The two panels keep their own widths.
      expect(profilePanelWidth.value, 400);
    });

    test('without preferences it is the default and saving is harmless', () {
      DevicePreferences.reset();
      expect(profilePanelWidth.value, 400);
      profilePanelWidth.save(500);
      expect(profilePanelWidth.value, 400);
    });
  });

  testWidgets('the workspace docks the profile at the saved width, and a drag '
      'saves the new one', (t) async {
    t.view.physicalSize = const Size(1700, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final (w, api) = await pageFixture(t, section: 'chat');
    final prefs = await t.runAsync(SharedPreferences.getInstance);
    await t.runAsync(() => prefs!.setDouble(profilePanelWidth.key, 500));
    DevicePreferences.adopt(prefs!);
    api.routes['GET /messages/channel/c1'] = (_) => {'messages': []};
    api.routes['GET /channels/c1/available-mentions'] = (_) => {
      'humans': [],
      'agents': [],
    };
    api.routes['GET /agents'] = (_) => [];
    api.routes['GET /servers/s1/members'] = (_) => [];
    api.routes['PATCH /servers/s1/sidebar-order'] = (request) => request.data;
    await t.pumpWidget(
      MaterialApp(
        theme: raftTheme(),
        home: withAppServices(
          WorkspaceView(
            controller: w,
            appearance: RaftAppearance(),
            onAppearance: (_) async {},
            onLogout: () async {},
          ),
        ),
      ),
    );
    for (var i = 0; i < 12; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    w.openProfile(
      RaftProfileKind.external,
      'm1',
      channelId: 'c1',
      externalAuthor: const {
        'displayName': 'Ada Lovelace',
        'provider': 'slack',
        'actorKind': 'human',
        'workspaceName': 'Acme',
      },
    );
    for (var i = 0; i < 12; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    final panel = find.byKey(const Key('workspace-profile-panel'));
    expect(t.getSize(panel).width, 500);
    final handle = find.byKey(const Key('profile-resize-handle'));
    final drag = await t.startGesture(t.getCenter(handle));
    await drag.moveBy(const Offset(-60, 0));
    await drag.up();
    await t.pump();
    expect(t.getSize(panel).width, 560);
    expect(profilePanelWidth.value, 560);

    await t.tap(find.byKey(const Key('channel-profile-expand')));
    await t.pump();
    expect(t.getSize(panel).width, greaterThan(560));
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pump();
    expect(t.getSize(panel).width, 560);

    TaskV2ConversationsFlag.of(w).markEnabled();
    ChannelSideCards.toggle(w, ChannelSideCard.tasks);
    await t.pumpAndSettle();
    final tasks = find.byKey(const Key('channel-side-card-tasks'));
    expect(t.getRect(tasks).right, closeTo(t.getRect(panel).left, 1));
    await t.tap(find.byKey(const Key('channel-profile-move')));
    await t.pumpAndSettle();
    await t.tap(find.text('Move left'));
    await t.pumpAndSettle();
    expect(t.getRect(panel).right, closeTo(t.getRect(tasks).left, 1));
    expect(w.location.profile?.id, 'm1');
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pump();
    expect(panel, findsNothing);

    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 3));
  });
}
