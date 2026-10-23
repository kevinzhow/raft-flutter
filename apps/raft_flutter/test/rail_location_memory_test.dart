import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/features/rail_location_memory.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_services_fixture.dart';
import 'workspace_source_location_contract_test.dart' show pageFixture;

RaftLocation at(String path) => RaftLocation.parse('/s/demo$path');

void main() {
  tearDown(DevicePreferences.reset);

  test('Search and Activity belong to no memorized mode', () {
    expect(railModeOfLocation(at('/search')), isNull);
    expect(railModeOfLocation(at('/search?q=x')), isNull);
    expect(railModeOfLocation(at('/activity')), isNull);
    expect(railModeOfLocation(at('')), 'chat');
    expect(railModeOfLocation(at('/channel/c1')), 'chat');
    expect(railModeOfLocation(at('/dm/d1')), 'chat');
    expect(railModeOfLocation(at('/saved')), 'chat');
    expect(railModeOfLocation(at('/tasks')), 'tasks');
    expect(railModeOfLocation(at('/members')), 'members');
    expect(railModeOfLocation(at('/agent/a1')), 'members');
    expect(railModeOfLocation(at('/human/u1')), 'members');
    expect(railModeOfLocation(at('/computers')), 'computers');
    expect(railModeOfLocation(at('/computer/m1')), 'computers');
    expect(railModeOfLocation(at('/settings/account')), 'settings');
  });

  testWidgets('each mode returns to where it was left; Search never '
      'overwrites Chat', (t) async {
    final (w, _) = await pageFixture(t, section: 'chat');
    final memory = RailLocationMemory();
    void visit(String path) {
      w.navigation.navigate(at(path));
      memory.record(w);
    }

    visit('/channel/c1?thread=c1%3Aroot');
    visit('/agent/a1');
    visit('/computer/m1');
    visit('/search?q=hello');
    visit('/activity');
    visit('/settings/account');
    expect(
      memory.recall(w, 'chat')?.toString(),
      '/s/demo/channel/c1?thread=c1%3Aroot',
    );
    expect(memory.recall(w, 'members')?.toString(), '/s/demo/agent/a1');
    expect(memory.recall(w, 'computers')?.toString(), '/s/demo/computer/m1');
    expect(
      memory.recall(w, 'settings')?.toString(),
      '/s/demo/settings/account',
    );
    expect(memory.recall(w, 'tasks'), isNull);
    expect(memory.recall(w, 'search'), isNull);
    expect(memory.recall(w, 'activity'), isNull);
  });

  testWidgets('a slot survives a restart and is dropped when it no longer '
      'belongs to its mode or server', (t) async {
    final (w, _) = await pageFixture(t, section: 'chat');
    final prefs = await t.runAsync(SharedPreferences.getInstance);
    DevicePreferences.adopt(prefs!);
    final first = RailLocationMemory();
    w.navigation.navigate(at('/agent/a1'));
    first.record(w);
    await t.runAsync(() => Future<void>.delayed(Duration.zero));
    final restarted = RailLocationMemory();
    expect(restarted.recall(w, 'members')?.toString(), '/s/demo/agent/a1');
    // A slot written by another build or server cannot send the user to a
    // page of the wrong mode or workspace.
    final key = prefs.getKeys().singleWhere((k) => k.endsWith('.demo.members'));
    await t.runAsync(() => prefs.setString(key, '/s/demo/settings/account'));
    expect(RailLocationMemory().recall(w, 'members'), isNull);
    expect(prefs.containsKey(key), isFalse);
    await t.runAsync(() => prefs.setString(key, '/s/other/agent/a1'));
    expect(RailLocationMemory().recall(w, 'members'), isNull);
    expect(prefs.containsKey(key), isFalse);
  });

  testWidgets(
    'the wide rail reopens the last member, and Chat the open conversation',
    (t) async {
      t.view.physicalSize = const Size(1280, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final (w, api) = await pageFixture(t, section: 'chat');
      api.routes['GET /messages/channel/c1'] = (_) => {'messages': []};
      api.routes['GET /channels/c1/available-mentions'] = (_) => {
        'humans': [],
        'agents': [],
      };
      api.routes['GET /agents'] = (_) => [];
      api.routes['GET /servers/s1/members'] = (_) => [];
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: withAppServices(
            WorkspaceView(
              controller: w,
              appearance: RaftAppearance(light: RaftFamily.elegant),
              onAppearance: (_) async {},
              onLogout: () async {},
            ),
          ),
        ),
      );
      for (var i = 0; i < 12; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      Future<void> rail(String id) async {
        await t.tap(find.byKey(Key('rail-$id')));
        for (var i = 0; i < 12; i++) {
          await t.pump(const Duration(milliseconds: 50));
        }
      }

      // Members: the rail opens the list; the person picks one.
      await rail('members');
      expect(w.location.route, RaftRoute.members);
      w.navigation.navigate(at('/agent/a1'));
      w.notifyListeners();
      await t.pump(const Duration(milliseconds: 50));
      // Away to Chat and back: the same person, not the members root.
      await rail('chat');
      expect(w.location.route, isNot(RaftRoute.agent));
      await rail('members');
      expect(w.location.toString(), '/s/demo/agent/a1');
      // Chat comes back on the open conversation.
      await rail('chat');
      expect(w.section, 'chat');
      expect(w.channel?.id, 'c1');
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 3));
    },
  );
}
