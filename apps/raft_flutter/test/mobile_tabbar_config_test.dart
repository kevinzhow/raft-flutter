import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/device_preferences.dart';
import 'package:raft_flutter/data/mobile_tabbar_preferences.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/workspace_navigation.dart';
import 'package:raft_flutter/features/mobile_workspace_pages.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_global_server_selector_test.dart' show RootFixture;

const tabBar = Key('workspace-mobile-navigation');

// Home, Tasks, Activity, Computers + Settings: the widest bar.
final fullBar = jsonEncode({
  'order': ['chat', 'tasks', 'activity', 'computers', 'members'],
  'enabled': ['chat', 'tasks', 'activity', 'computers'],
});

Future<void> settleRoute(WidgetTester t) async {
  for (var i = 0; i < 10; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

bool Function(String) caps(Set<String> granted) => granted.contains;

void main() {
  group('settings parsing and persistence', () {
    test('default is today\'s bar and survives a round trip', () {
      final d = MobileTabbarSettings.defaults;
      expect(d.visible, ['chat', 'tasks', 'members']);
      expect(d.isDefault, isTrue);
      expect(MobileTabbarSettings.parse(null), d);
      expect(MobileTabbarSettings.parse(d.encode()), d);
      final custom = MobileTabbarSettings.parse(fullBar);
      expect(custom.visible, ['chat', 'tasks', 'activity', 'computers']);
      expect(custom.order, [
        'chat',
        'tasks',
        'activity',
        'computers',
        'members',
      ]);
      expect(MobileTabbarSettings.parse(custom.encode()), custom);
      expect(custom.isDefault, isFalse);
    });

    test('invalid data falls back; unknown and removed ids are ignored', () {
      final d = MobileTabbarSettings.defaults;
      for (final raw in [
        '',
        'not json',
        '42',
        '"chat"',
        '{}',
        '{"enabled":"chat"}',
        '[]',
        '["settings"]',
        '["gone","also-gone"]',
        '{"order":["chat"],"enabled":[]}',
      ]) {
        expect(MobileTabbarSettings.parse(raw), d, reason: raw);
      }
      final mixed = MobileTabbarSettings.parse(
        '{"order":["x","activity","chat","activity"],"enabled":["gone","activity",7,"chat"]}',
      );
      expect(mixed.visible, ['activity', 'chat']);
      // Every configurable tab appears exactly once in the order.
      expect(mixed.order.toSet(), MobileTabs.configurable.toSet());
      expect(mixed.order, hasLength(MobileTabs.configurable.length));
    });

    test('a bare list is the ordered enabled ids; the limit is enforced', () {
      expect(MobileTabbarSettings.parse('["activity","chat"]').visible, [
        'activity',
        'chat',
      ]);
      final all = MobileTabbarSettings.parse(
        '["activity","computers","chat","tasks","members"]',
      );
      expect(all.enabled, hasLength(MobileTabs.maxConfigurable));
      expect(all.visible, ['activity', 'computers', 'chat', 'tasks']);
    });

    test('the store reads preloaded preferences and writes through', () async {
      SharedPreferences.setMockInitialValues({
        MobileTabbarStore.preferenceKey: fullBar,
      });
      addTearDown(DevicePreferences.reset);
      await DevicePreferences.load();
      final first = MobileTabbarStore();
      expect(first.settings.visible, [
        'chat',
        'tasks',
        'activity',
        'computers',
      ]);
      var notified = 0;
      first.addListener(() => notified++);
      first.update(
        first.settings.merged(
          MobileTabbarSettings(
            order: ['activity', 'chat', 'tasks', 'computers', 'members'],
            enabled: {'activity', 'chat'},
          ),
          MobileTabs.configurable.toSet(),
        ),
      );
      expect(notified, 1);
      final second = MobileTabbarStore();
      expect(second.settings.visible, ['activity', 'chat']);
      first.update(first.settings);
      expect(notified, 1);
      first.reset();
      expect(MobileTabbarStore().settings, MobileTabbarSettings.defaults);
      expect(
        DevicePreferences.current!.containsKey(MobileTabbarStore.preferenceKey),
        isFalse,
      );
    });

    test('without preloaded preferences the store starts at the default', () {
      DevicePreferences.reset();
      expect(MobileTabbarStore().settings, MobileTabbarSettings.defaults);
    });
  });

  group('permission filtering', () {
    final all = MobileTabbarSettings.parse(
      '["chat","tasks","members","computers","activity"]',
    );
    final owner = caps({'viewMembers', 'viewMachines'});
    test('members and computers follow the existing rules', () {
      expect(all.effective(guest: false, can: owner), [
        'chat',
        'tasks',
        'members',
        'computers',
      ]);
      expect(all.effective(guest: true, can: owner), ['chat', 'tasks']);
      expect(all.effective(guest: false, can: caps({'viewMembers'})), [
        'chat',
        'tasks',
        'members',
      ]);
      expect(all.effective(guest: false, can: caps({'viewMachines'})), [
        'chat',
        'tasks',
        'computers',
      ]);
      expect(all.effective(guest: false, can: caps({})), ['chat', 'tasks']);
    });

    test('hidden tabs do not count toward the limit', () {
      final withActivity = MobileTabbarSettings.parse(
        '["members","computers","activity","chat"]',
      );
      expect(withActivity.effective(guest: true, can: owner), [
        'activity',
        'chat',
      ]);
      expect(withActivity.effective(guest: false, can: owner), [
        'members',
        'computers',
        'activity',
        'chat',
      ]);
    });

    test('only Settings left falls back to Home', () {
      final membersOnly = MobileTabbarSettings.parse('["members"]');
      expect(membersOnly.effective(guest: true, can: owner), ['chat']);
      final computersOnly = MobileTabbarSettings.parse('["computers"]');
      expect(computersOnly.effective(guest: false, can: caps({})), ['chat']);
    });

    test('merging a filtered edit keeps hidden tabs in place and on', () {
      final stored = MobileTabbarSettings.parse(
        '{"order":["chat","members","tasks","computers","activity"],'
        '"enabled":["chat","members","activity"]}',
      );
      final permitted = {'chat', 'tasks', 'activity'};
      final edited = stored.merged(
        MobileTabbarSettings(
          order: ['activity', 'tasks', 'chat'],
          enabled: {'activity', 'tasks'},
        ),
        permitted,
      );
      expect(edited.order, [
        'activity',
        'members',
        'tasks',
        'computers',
        'chat',
      ]);
      expect(edited.enabled, {'members', 'activity', 'tasks'});
    });
  });

  group('tab roots', () {
    RaftLocation at(RaftRoute route, {String? id}) =>
        RaftLocation.at(serverSlug: 's', route: route, entityId: id);

    test('Computers and Activity are roots only while the bar has them', () {
      final n = WorkspaceNavigation();
      expect(n.mobileRootTabOf(at(RaftRoute.computers)), isNull);
      expect(n.mobileRootTabOf(at(RaftRoute.activity)), isNull);
      n.mobileTabs = {'computers', 'activity'};
      expect(n.mobileRootTabOf(at(RaftRoute.computers)), 'computers');
      expect(n.mobileRootTabOf(at(RaftRoute.activity)), 'activity');
      // Details stay pushed pages.
      expect(n.mobileRootTabOf(at(RaftRoute.computer, id: 'm')), isNull);
      expect(
        n.mobileRootTabOf(
          RaftLocation.parse('/s/alpha/activity?open=channel:ca&msg=ma'),
        ),
        isNull,
      );
      n.mobileTabs = {'activity'};
      expect(n.mobileRootTabOf(at(RaftRoute.computers)), isNull);
    });

    test('a cold computer detail returns to the Computers root', () {
      final n = WorkspaceNavigation()
        ..bind('cold', at(RaftRoute.computer, id: 'm'));
      expect(n.mobileTabHome(n.location).route, RaftRoute.settings);
      n.mobileTabs = {'computers'};
      expect(n.mobileTabHome(n.location).route, RaftRoute.computers);
      final pages = mobilePageEntries(n);
      expect(pages, hasLength(2));
      expect(pages.first, startsWith('root::'));
      expect(pages.first, contains('computers'));
    });
  });

  for (final theme in ['light']) {
    Future<void> tapTab(RootFixture f, WidgetTester t, String id) async {
      await t.tap(find.byKey(Key('mobile-tab-$id')));
      await f.flush(t);
    }

    List<String> barOrder(WidgetTester t) {
      final ids = [
        'home',
        'tasks',
        'members',
        'computers',
        'activity',
        'settings',
      ].where((id) => find.byKey(Key('mobile-tab-$id')).evaluate().isNotEmpty);
      return ids.toList()..sort(
        (a, b) => t
            .getTopLeft(find.byKey(Key('mobile-tab-$a')))
            .dx
            .compareTo(t.getTopLeft(find.byKey(Key('mobile-tab-$b'))).dx),
      );
    }

    String selected(WidgetTester t) =>
        t.widget<RaftMobileNav>(find.byKey(tabBar)).selectedId;

    testWidgets('$theme default bar is unchanged', (t) async {
      final f = RootFixture();
      await f.mount(t, theme, 390, uri: Uri.parse('/s/alpha'));
      expect(barOrder(t), ['home', 'tasks', 'members', 'settings']);
      expect(selected(t), 'chat');
      // Settings keeps Computers as a sub-page and has the Bottom bar row.
      await tapTab(f, t, 'settings');
      expect(
        find.byKey(const ValueKey('workspace-settings-nav-bottom-bar')),
        findsOneWidget,
      );
      double top(String id) =>
          t.getTopLeft(find.byKey(ValueKey('workspace-settings-nav-$id'))).dy;
      expect(top('appearance'), lessThan(top('bottom-bar')));
      expect(top('bottom-bar'), lessThan(top('notifications')));
      expect(
        find.byKey(const ValueKey('workspace-settings-nav-computers')),
        findsOneWidget,
      );
      await f.close(t);
    });

    testWidgets('$theme Computers stays a Settings sub-page when off the bar', (
      t,
    ) async {
      final f = RootFixture();
      await f.mount(t, theme, 390, uri: Uri.parse('/s/alpha'));
      await tapTab(f, t, 'settings');
      await t.tap(
        find.byKey(const ValueKey('workspace-settings-nav-computers')),
      );
      await f.flush(t);
      // The covered Settings root stays a live page until the push settles.
      await settleRoute(t);
      final w = f.workspace(t);
      expect(w.location.route, RaftRoute.computers);
      expect(find.byKey(tabBar), findsNothing);
      expect(find.byKey(const Key('mobile-detail-back')), findsOneWidget);
      expect(find.byType(RaftMobileRootHeader), findsNothing);
      await t.tap(find.byKey(const Key('mobile-detail-back')));
      await f.flush(t);
      await settleRoute(t);
      expect(w.location.route, RaftRoute.settings);
      expect(selected(t), 'settings');
      await f.close(t);
    });

    testWidgets('$theme configured bar paints at the first frame, in order', (
      t,
    ) async {
      final f = RootFixture();
      final seen = <String>{};
      f.onFrame = () {
        if (find.byKey(tabBar).evaluate().isNotEmpty) {
          seen.add(barOrder(t).join(','));
        }
      };
      await f.mount(
        t,
        theme,
        390,
        uri: Uri.parse('/s/alpha'),
        preferences: {MobileTabbarStore.preferenceKey: fullBar},
      );
      expect(seen, {'home,tasks,activity,computers,settings'});
      await f.close(t);
    });

    testWidgets('$theme Activity and Computers are tab roots', (t) async {
      final f = RootFixture();
      await f.mount(
        t,
        theme,
        390,
        uri: Uri.parse('/s/alpha'),
        preferences: {MobileTabbarStore.preferenceKey: fullBar},
      );
      final w = f.workspace(t);
      for (final tab in ['activity', 'computers']) {
        await tapTab(f, t, tab);
        expect(w.location.route, RaftRoute.values.byName(tab), reason: tab);
        expect(selected(t), tab);
        expect(find.byKey(tabBar), findsOneWidget);
        expect(find.byType(RaftMobileRootHeader), findsOneWidget, reason: tab);
        expect(
          find.descendant(
            of: find.byType(RaftMobileRootHeader),
            matching: find.text(tab == 'activity' ? 'Activity' : 'Computers'),
          ),
          findsOneWidget,
        );
        expect(find.byKey(const Key('mobile-detail-back')), findsNothing);
        expect(find.byType(RaftBackButton), findsNothing);
        expect(find.byType(RaftPanelBackAction), findsNothing);
        // Back at a tab root is handed to the system, like every other tab.
        final index = w.navigation.index;
        expect(await t.binding.handlePopRoute(), isFalse, reason: tab);
        await f.flush(t);
        expect(w.location.route, RaftRoute.values.byName(tab));
        expect(w.navigation.index, index);
      }
      // Switching away and back keeps working.
      await tapTab(f, t, 'tasks');
      expect(selected(t), 'tasks');
      await tapTab(f, t, 'activity');
      expect(selected(t), 'activity');
      await f.close(t);
    });

    testWidgets(
      '$theme details open as platform routes and return to the root',
      (t) async {
        final f = RootFixture();
        await f.mount(
          t,
          theme,
          390,
          uri: Uri.parse('/s/alpha'),
          preferences: {MobileTabbarStore.preferenceKey: fullBar},
        );
        final w = f.workspace(t);
        for (final (tab, detail) in [
          ('computers', '/s/alpha/computer/machine-1'),
          ('activity', '/s/alpha/activity?open=channel:ca&msg=ma'),
        ]) {
          await tapTab(f, t, tab);
          w.navigation.navigate(RaftLocation.parse(detail));
          w.notifyListeners();
          await f.flush(t);
          await settleRoute(t);
          expect(find.byKey(tabBar), findsNothing, reason: detail);
          expect(await t.binding.handlePopRoute(), isTrue, reason: detail);
          await f.flush(t);
          await settleRoute(t);
          expect(
            w.location.route,
            RaftRoute.values.byName(tab),
            reason: detail,
          );
          expect(selected(t), tab);
          expect(find.byKey(tabBar), findsOneWidget);
        }
        await f.close(t);
      },
    );

    testWidgets(
      '$theme a computer opens from the Computers root as a platform route',
      (t) async {
        final f = RootFixture();
        f.overrides['GET /servers/a/machines'] = (_) => {
          'machines': [
            {
              'id': 'computer-a',
              'name': 'Build Computer',
              'isComputer': true,
              'status': 'online',
              'userId': 'alice',
            },
          ],
        };
        await f.mount(
          t,
          theme,
          390,
          uri: Uri.parse('/s/alpha'),
          preferences: {MobileTabbarStore.preferenceKey: fullBar},
        );
        final w = f.workspace(t);
        await tapTab(f, t, 'computers');
        await settleRoute(t);
        await t.tap(find.byKey(const ValueKey('fleet-computer-a')));
        await f.flush(t);
        await settleRoute(t);
        expect(w.location.route, RaftRoute.computer);
        expect(find.byKey(tabBar), findsNothing);
        expect(await t.binding.handlePopRoute(), isTrue);
        await f.flush(t);
        await settleRoute(t);
        expect(w.location.route, RaftRoute.computers);
        expect(selected(t), 'computers');
        expect(find.byKey(tabBar), findsOneWidget);
        await f.close(t);
      },
    );

    testWidgets('$theme Settings drops its Computers row while it is a tab', (
      t,
    ) async {
      final f = RootFixture();
      await f.mount(
        t,
        theme,
        390,
        uri: Uri.parse('/s/alpha'),
        preferences: {MobileTabbarStore.preferenceKey: fullBar},
      );
      await tapTab(f, t, 'settings');
      expect(
        find.byKey(const ValueKey('workspace-settings-nav-computers')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('workspace-settings-nav-bottom-bar')),
        findsOneWidget,
      );
      await f.close(t);
    });

    testWidgets('$theme a guest gets no Members or Computers', (t) async {
      final f = RootFixture();
      f.servers[0] = {...f.servers[0], 'role': 'guest'};
      await f.mount(
        t,
        theme,
        390,
        uri: Uri.parse('/s/alpha'),
        preferences: {
          MobileTabbarStore.preferenceKey: jsonEncode({
            'order': ['members', 'computers', 'activity', 'chat', 'tasks'],
            'enabled': ['members', 'computers', 'activity', 'chat'],
          }),
        },
      );
      expect(barOrder(t), ['activity', 'home', 'settings']);
      // The configuration page does not list them either.
      await tapTab(f, t, 'settings');
      await t.tap(
        find.byKey(const ValueKey('workspace-settings-nav-bottom-bar')),
      );
      await f.flush(t);
      expect(
        find.byKey(const ValueKey('mobile-tabbar-row-chat')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('mobile-tabbar-row-activity')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('mobile-tabbar-row-members')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('mobile-tabbar-row-computers')),
        findsNothing,
      );
      await f.close(t);
    });

    testWidgets('$theme only Settings left falls back to Home', (t) async {
      final f = RootFixture();
      f.servers[0] = {...f.servers[0], 'role': 'guest'};
      await f.mount(
        t,
        theme,
        390,
        uri: Uri.parse('/s/alpha'),
        preferences: {MobileTabbarStore.preferenceKey: '["members"]'},
      );
      expect(barOrder(t), ['home', 'settings']);
      await f.close(t);
    });

    testWidgets('$theme the Bottom bar page edits the bar and persists', (
      t,
    ) async {
      final f = RootFixture();
      await f.mount(t, theme, 390, uri: Uri.parse('/s/alpha'));
      final w = f.workspace(t);
      await tapTab(f, t, 'settings');
      await t.tap(
        find.byKey(const ValueKey('workspace-settings-nav-bottom-bar')),
      );
      await f.flush(t);
      await settleRoute(t);
      expect(w.location.settingsPath, ['bottom-bar']);
      expect(find.byKey(tabBar), findsNothing);
      expect(find.byKey(const Key('mobile-tabbar-preview')), findsOneWidget);
      for (final id in ['activity', 'computers']) {
        await t.tap(find.byKey(ValueKey('mobile-tabbar-switch-$id')));
        await f.flush(t);
      }
      // Limit reached: Home, Tasks, Members, Activity + Settings.
      expect(find.byKey(const Key('mobile-tabbar-notice')), findsOneWidget);
      final stored = MobileTabbarSettings.parse(
        DevicePreferences.current!.getString(MobileTabbarStore.preferenceKey),
      );
      expect(stored.visible, ['chat', 'tasks', 'members', 'activity']);
      // Reset restores the default and removes the stored choice.
      await t.tap(find.text('Reset to Default'));
      await f.flush(t);
      expect(
        DevicePreferences.current!.containsKey(MobileTabbarStore.preferenceKey),
        isFalse,
      );
      await t.tap(find.byKey(const ValueKey('mobile-tabbar-switch-members')));
      await f.flush(t);
      await t.tap(find.byKey(const ValueKey('mobile-tabbar-switch-activity')));
      await f.flush(t);
      // System Back leaves the page like any other Settings sub-page.
      expect(await t.binding.handlePopRoute(), isTrue);
      await f.flush(t);
      await settleRoute(t);
      expect(w.location.settingsPath, isEmpty);
      expect(find.byKey(tabBar), findsOneWidget);
      expect(barOrder(t), ['home', 'tasks', 'activity', 'settings']);
      await f.close(t);
    });

    testWidgets('$theme removing the selected tab does not break navigation', (
      t,
    ) async {
      final f = RootFixture();
      await f.mount(
        t,
        theme,
        390,
        uri: Uri.parse('/s/alpha'),
        preferences: {MobileTabbarStore.preferenceKey: fullBar},
      );
      final w = f.workspace(t);
      await tapTab(f, t, 'computers');
      final state =
          t.state(find.byType(WorkspaceView)) as dynamic;
      final store = state.mobileTabbar as MobileTabbarStore;
      store.update(MobileTabbarSettings.defaults);
      await f.flush(t);
      await settleRoute(t);
      expect(t.takeException(), isNull);
      expect(w.location.route, RaftRoute.computers);
      // Computers is now the Settings sub-page again: back arrow, no bar.
      expect(find.byKey(tabBar), findsNothing);
      expect(find.byKey(const Key('mobile-detail-back')), findsOneWidget);
      await t.tap(find.byKey(const Key('mobile-detail-back')));
      await f.flush(t);
      await settleRoute(t);
      expect(find.byKey(tabBar), findsOneWidget);
      await tapTab(f, t, 'home');
      expect(selected(t), 'chat');
      await f.close(t);
    });
  }
}
