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
import 'support/server_tab.dart';

const tabBar = Key('workspace-mobile-navigation');

// Home, Tasks, Activity (Search off) + the server tab: a custom bar.
final fullBar = jsonEncode({
  'order': ['chat', 'tasks', 'activity', 'search'],
  'enabled': ['chat', 'tasks', 'activity'],
});

Future<void> settleRoute(WidgetTester t) async {
  for (var i = 0; i < 10; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

bool Function(String) caps(Set<String> granted) => granted.contains;

void main() {
  group('settings parsing and persistence', () {
    test('default is the Web bar and survives a round trip', () {
      final d = MobileTabbarSettings.defaults;
      expect(d.visible, ['chat', 'activity', 'tasks', 'search']);
      expect(d.isDefault, isTrue);
      expect(MobileTabbarSettings.parse(null), d);
      expect(MobileTabbarSettings.parse(d.encode()), d);
      final custom = MobileTabbarSettings.parse(fullBar);
      expect(custom.visible, ['chat', 'tasks', 'activity']);
      expect(custom.order, ['chat', 'tasks', 'activity', 'search']);
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
      // Tabs the stored order never listed (new since) join while there is room.
      expect(mixed.visible, ['activity', 'chat', 'tasks', 'search']);
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
        '["activity","computers","chat","tasks","members","search"]',
      );
      expect(all.enabled, hasLength(MobileTabs.maxConfigurable));
      expect(all.visible, ['activity', 'chat', 'tasks', 'search']);
    });

    test('the store reads preloaded preferences and writes through', () async {
      SharedPreferences.setMockInitialValues({
        MobileTabbarStore.preferenceKey: fullBar,
      });
      addTearDown(DevicePreferences.reset);
      await DevicePreferences.load();
      final first = MobileTabbarStore();
      expect(first.settings.visible, ['chat', 'tasks', 'activity']);
      var notified = 0;
      first.addListener(() => notified++);
      first.update(
        first.settings.merged(
          MobileTabbarSettings(
            order: ['activity', 'chat', 'tasks', 'search'],
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
      '["chat","tasks","search","activity"]',
    );
    final owner = caps({'viewMembers', 'viewMachines'});
    test('no configurable tab depends on the account', () {
      for (final (guest, can) in [
        (false, owner),
        (true, owner),
        (false, caps({})),
      ]) {
        expect(all.effective(guest: guest, can: can), [
          'chat',
          'tasks',
          'search',
          'activity',
        ]);
      }
    });

    test('a stored choice of removed tabs reads as the default bar', () {
      final removed = MobileTabbarSettings.parse('["members","computers"]');
      expect(removed, MobileTabbarSettings.defaults);
      expect(removed.effective(guest: true, can: caps({})), [
        'chat',
        'activity',
        'tasks',
        'search',
      ]);
    });

    test('merging a filtered edit keeps hidden tabs in place and on', () {
      final stored = MobileTabbarSettings.parse(
        '{"order":["chat","search","tasks","activity"],'
        '"enabled":["chat","search","activity"]}',
      );
      final permitted = {'chat', 'tasks', 'activity'};
      final edited = stored.merged(
        MobileTabbarSettings(
          order: ['activity', 'tasks', 'chat'],
          enabled: {'activity', 'tasks'},
        ),
        permitted,
      );
      expect(edited.order, ['activity', 'search', 'tasks', 'chat']);
      expect(edited.enabled, {'search', 'activity', 'tasks'});
    });
  });

  group('tab roots', () {
    RaftLocation at(RaftRoute route, {String? id}) =>
        RaftLocation.at(serverSlug: 's', route: route, entityId: id);

    test('Activity and Search are roots only while the bar has them', () {
      final n = WorkspaceNavigation();
      expect(n.mobileRootTabOf(at(RaftRoute.search)), isNull);
      expect(n.mobileRootTabOf(at(RaftRoute.activity)), isNull);
      n.mobileTabs = {'search', 'activity'};
      expect(n.mobileRootTabOf(at(RaftRoute.search)), 'search');
      expect(n.mobileRootTabOf(at(RaftRoute.activity)), 'activity');
      // Computers is a pushed page, with the bar or not; so are details.
      expect(n.mobileRootTabOf(at(RaftRoute.computers)), isNull);
      expect(n.mobileRootTabOf(at(RaftRoute.computer, id: 'm')), isNull);
      expect(
        n.mobileRootTabOf(
          RaftLocation.parse('/s/alpha/activity?open=channel:ca&msg=ma'),
        ),
        isNull,
      );
      n.mobileTabs = {'activity'};
      expect(n.mobileRootTabOf(at(RaftRoute.search)), isNull);
    });

    test('a cold computer detail returns to the pushed Computers page', () {
      final n = WorkspaceNavigation()
        ..bind('cold', at(RaftRoute.computer, id: 'm'));
      expect(n.mobileTabHome(n.location).route, RaftRoute.computers);
      final pages = mobilePageEntries(n);
      expect(pages, hasLength(3));
      expect(pages.first, startsWith('root::'));
      expect(pages[1], startsWith('page::'));
      expect(pages[1], contains('computers'));
    });
  });

  for (final theme in ['light']) {
    Future<void> tapTab(RootFixture f, WidgetTester t, String id) async {
      await t.tap(find.byKey(Key('mobile-tab-$id')));
      await f.flush(t);
    }

    // Members, Computers and Settings are pushed from the server tab.
    Future<void> openPage(RootFixture f, WidgetTester t, String page) =>
        openServerPage(t, page, flush: f.flush);

    List<String> barOrder(WidgetTester t) {
      final ids = [
        'home',
        'activity',
        'tasks',
        'search',
        'server',
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

    testWidgets('$theme default bar is the Web bar', (t) async {
      final f = RootFixture();
      await f.mount(t, theme, 390, uri: Uri.parse('/s/alpha'));
      expect(barOrder(t), ['home', 'activity', 'tasks', 'search', 'server']);
      expect(selected(t), 'chat');
      // Settings is a pushed page: Back, no bar. It keeps Computers as a
      // sub-page and has the Bottom bar row.
      await openPage(f, t, 'settings');
      expect(find.byKey(tabBar), findsNothing);
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

    testWidgets('$theme Computers stays a Settings sub-page', (t) async {
      final f = RootFixture();
      await f.mount(t, theme, 390, uri: Uri.parse('/s/alpha'));
      await openPage(f, t, 'settings');
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
      expect(find.byKey(tabBar), findsNothing);
      expect(find.byKey(const Key('server-page-mobile-back')), findsOneWidget);
      await t.tap(find.byKey(const Key('server-page-mobile-back')));
      await f.flush(t);
      await settleRoute(t);
      expect(w.location.route, RaftRoute.home);
      expect(selected(t), 'chat');
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
      expect(seen, {'home,tasks,activity,server'});
      await f.close(t);
    });

    testWidgets('$theme Activity and Search are tab roots', (t) async {
      final f = RootFixture();
      await f.mount(t, theme, 390, uri: Uri.parse('/s/alpha'));
      final w = f.workspace(t);
      for (final tab in ['activity', 'search']) {
        await tapTab(f, t, tab);
        expect(w.location.route, RaftRoute.values.byName(tab), reason: tab);
        expect(selected(t), tab);
        expect(find.byKey(tabBar), findsOneWidget);
        if (tab == 'activity') {
          expect(find.byType(RaftMobileRootHeader), findsOneWidget);
        }
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
        await f.mount(t, theme, 390, uri: Uri.parse('/s/alpha'));
        final w = f.workspace(t);
        for (final (tab, detail) in [
          ('activity', '/s/alpha/activity?open=channel:ca&msg=ma'),
          ('search', '/s/alpha/search?open=channel:ca&msg=ma'),
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

    testWidgets('$theme a computer opens from the pushed Computers page', (
      t,
    ) async {
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
      await f.mount(t, theme, 390, uri: Uri.parse('/s/alpha'));
      final w = f.workspace(t);
      await openPage(f, t, 'computers');
      await settleRoute(t);
      expect(find.byKey(tabBar), findsNothing);
      await t.tap(find.byKey(const ValueKey('fleet-computer-a')));
      await f.flush(t);
      await settleRoute(t);
      expect(w.location.route, RaftRoute.computer);
      expect(find.byKey(tabBar), findsNothing);
      expect(await t.binding.handlePopRoute(), isTrue);
      await f.flush(t);
      await settleRoute(t);
      expect(w.location.route, RaftRoute.computers);
      expect(find.byKey(tabBar), findsNothing);
      expect(await t.binding.handlePopRoute(), isTrue);
      await f.flush(t);
      await settleRoute(t);
      expect(w.location.route, RaftRoute.home);
      expect(selected(t), 'chat');
      expect(find.byKey(tabBar), findsOneWidget);
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
          // The previous release's value: Members and Computers are gone.
          MobileTabbarStore.preferenceKey: jsonEncode({
            'order': ['members', 'computers', 'activity', 'chat', 'tasks'],
            'enabled': ['members', 'computers', 'activity', 'chat'],
          }),
        },
      );
      expect(barOrder(t), ['activity', 'home', 'search', 'server']);
      await openServerPopover(t, flush: f.flush);
      expect(find.byKey(serverPageKey('members')), findsNothing);
      expect(find.byKey(serverPageKey('computers')), findsNothing);
      expect(find.byKey(serverPageKey('settings')), findsOneWidget);
      await t.tap(find.byKey(serverPageKey('settings')));
      await f.flush(t);
      await settleRoute(t);
      // The configuration page does not list them either.
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

    testWidgets('$theme a stored choice of removed tabs is the default', (
      t,
    ) async {
      final f = RootFixture();
      f.servers[0] = {...f.servers[0], 'role': 'guest'};
      await f.mount(
        t,
        theme,
        390,
        uri: Uri.parse('/s/alpha'),
        preferences: {MobileTabbarStore.preferenceKey: '["members"]'},
      );
      expect(barOrder(t), ['home', 'activity', 'tasks', 'search', 'server']);
      await f.close(t);
    });

    testWidgets('$theme the Bottom bar page edits the bar and persists', (
      t,
    ) async {
      final f = RootFixture();
      await f.mount(t, theme, 390, uri: Uri.parse('/s/alpha'));
      final w = f.workspace(t);
      await openPage(f, t, 'settings');
      await t.tap(
        find.byKey(const ValueKey('workspace-settings-nav-bottom-bar')),
      );
      await f.flush(t);
      await settleRoute(t);
      expect(w.location.settingsPath, ['bottom-bar']);
      expect(find.byKey(tabBar), findsNothing);
      expect(find.byKey(const Key('mobile-tabbar-preview')), findsOneWidget);
      for (final id in ['search', 'tasks']) {
        await t.tap(find.byKey(ValueKey('mobile-tabbar-switch-$id')));
        await f.flush(t);
      }
      final stored = MobileTabbarSettings.parse(
        DevicePreferences.current!.getString(MobileTabbarStore.preferenceKey),
      );
      expect(stored.visible, ['chat', 'activity']);
      // Reset restores the default and removes the stored choice.
      await t.tap(find.text('Reset to Default'));
      await f.flush(t);
      expect(
        DevicePreferences.current!.containsKey(MobileTabbarStore.preferenceKey),
        isFalse,
      );
      await t.tap(find.byKey(const ValueKey('mobile-tabbar-switch-search')));
      await f.flush(t);
      await t.tap(find.byKey(const ValueKey('mobile-tabbar-switch-activity')));
      await f.flush(t);
      // System Back leaves the page like any other Settings sub-page, then
      // the pushed Settings page.
      expect(await t.binding.handlePopRoute(), isTrue);
      await f.flush(t);
      await settleRoute(t);
      expect(w.location.settingsPath, isEmpty);
      expect(await t.binding.handlePopRoute(), isTrue);
      await f.flush(t);
      await settleRoute(t);
      expect(find.byKey(tabBar), findsOneWidget);
      expect(barOrder(t), ['home', 'tasks', 'server']);
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
      await tapTab(f, t, 'activity');
      final state = t.state(find.byType(WorkspaceView)) as dynamic;
      final store = state.mobileTabbar as MobileTabbarStore;
      store.update(
        MobileTabbarSettings(
          order: ['chat', 'tasks', 'search', 'activity'],
          enabled: {'chat', 'tasks', 'search'},
        ),
      );
      await f.flush(t);
      await settleRoute(t);
      expect(t.takeException(), isNull);
      expect(w.location.route, RaftRoute.activity);
      // Activity is no tab any more: back arrow, no bar.
      expect(find.byKey(tabBar), findsNothing);
      expect(await t.binding.handlePopRoute(), isTrue);
      await f.flush(t);
      await settleRoute(t);
      expect(find.byKey(tabBar), findsOneWidget);
      await tapTab(f, t, 'home');
      expect(selected(t), 'chat');
      await f.close(t);
    });
  }
}
