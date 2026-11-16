@Tags(['slow'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_ui/raft_ui.dart';

import 'app_global_server_selector_test.dart' show RootFixture;
import 'support/server_tab.dart';

// Mounted ports of Source MobileTabBar / useMobileNav.selectTab on the actual
// RaftApp at a phone viewport. Taps go through the visible tab bar controls.
const tabBar = Key('workspace-mobile-navigation');

// Mobile details are platform routes: after Back the popped route keeps
// absorbing pointers until its transition ends, so let it finish before the
// next tab tap.
Future<void> settleRoute(WidgetTester t) async {
  for (var i = 0; i < 10; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  for (final theme in ['light']) {
    // tab-bar-sidebar.spec.ts:155–204 [T18] and useMobileNav.ts:89–109: every
    // tab tap, active or inactive, PUSHes that tab's root and drops its
    // previously visited sub-page. Intended difference from Web (owner
    // decision 2026-10-11): Back at a tab root is handed to the system.
    testWidgets(
      '[N19] actual RaftApp $theme tab taps always PUSH the tab root and never restore a sub-page',
      (t) async {
        final f = RootFixture();
        await f.mount(t, theme, 390, uri: Uri.parse('/s/alpha'));
        final w = f.workspace(t);
        expect(w.location.toString(), '/s/alpha');

        Future<void> tapTab(String id) async {
          expect(find.byKey(tabBar), findsOneWidget);
          await t.tap(find.byKey(Key('mobile-tab-$id')));
          await f.flush(t);
        }

        // Home sub-page: an actual channel drill-in hides the tab bar.
        await t.tap(find.byKey(const ValueKey('sidebar-channel-ca')));
        await f.flush(t);
        // The covered tab root is a live page until the push settles.
        await settleRoute(t);
        expect(w.location.route, RaftRoute.channel);
        expect(find.byKey(tabBar), findsNothing);
        await t.tap(find.byKey(const Key('mobile-detail-back')));
        await f.flush(t);
        await settleRoute(t);
        expect(w.location.toString(), '/s/alpha');

        // Settings is pushed from the server tab (v1.24): no bar; Appearance
        // is one more page above it.
        await openServerPage(t, 'settings', flush: f.flush);
        expect(w.location.toString(), '/s/alpha/settings');
        expect(find.byKey(tabBar), findsNothing);
        await t.tap(
          find.byKey(const ValueKey('workspace-settings-nav-appearance')),
        );
        await f.flush(t);
        await settleRoute(t);
        expect(w.location.settingsPath, ['appearance']);
        expect(find.byKey(tabBar), findsNothing);
        await t.tap(find.byKey(const Key('mobile-settings-back')));
        await f.flush(t);
        await settleRoute(t);
        expect(w.location.toString(), '/s/alpha/settings');
        await t.tap(find.byKey(const Key('server-page-mobile-back')));
        await f.flush(t);
        await settleRoute(t);
        expect(w.location.toString(), '/s/alpha');

        // Inactive Tasks tab: PUSH to its root.
        var index = w.navigation.index;
        await tapTab('tasks');
        expect(w.location.toString(), '/s/alpha/tasks');
        expect(w.navigation.index, index + 1);
        expect(w.navigation.entries, hasLength(index + 2));

        // Inactive Home tab lands on Home root, not the visited channel.
        index = w.navigation.index;
        await tapTab('home');
        expect(w.location.toString(), '/s/alpha');
        expect(w.navigation.index, index + 1);
        expect(find.byKey(const Key('workspace-mobile-home')), findsOneWidget);
        expect(find.byType(RaftChannelHeader), findsNothing);
        expect(find.byKey(tabBar), findsOneWidget);

        // Active Home tab (v1.24, reverses v1.21 T18): no navigation, no new
        // history entry.
        index = w.navigation.index;
        await tapTab('home');
        expect(w.location.toString(), '/s/alpha');
        expect(w.navigation.index, index);
        expect(find.byKey(const Key('workspace-mobile-home')), findsOneWidget);

        // Settings from the server tab lands on the Settings list.
        index = w.navigation.index;
        await openServerPage(t, 'settings', flush: f.flush);
        expect(w.location.toString(), '/s/alpha/settings');
        expect(w.location.settingsPath, isEmpty);
        expect(w.navigation.index, index + 1);
        expect(
          find.byKey(const ValueKey('workspace-settings-nav-account')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('mobile-settings-back')), findsNothing);
        expect(find.byKey(tabBar), findsNothing);
        expect(await t.binding.handlePopRoute(), isTrue);
        await f.flush(t);
        await settleRoute(t);
        expect(w.location.toString(), '/s/alpha');

        // OWNER DECISION 2026-10-11 (intended difference from Web): at a
        // mobile tab root system Back is handed to the system (Android moves
        // the app to the background) instead of rewinding the visited tab
        // roots. The app must not consume the pop or move the location.
        final rootIndex = w.navigation.index;
        expect(await t.binding.handlePopRoute(), isFalse);
        await f.flush(t);
        expect(w.location.toString(), '/s/alpha');
        expect(w.navigation.index, rootIndex);
        await f.close(t);
      },
    );
  }

  for (final theme in ['light']) {
    // MainLayout.tsx MobileTabBar (v1.24): the bar shows only on the four tab
    // roots (Home, Activity, Tasks, Search); channel/DM, member details/graph,
    // Members, Settings, Saved, Computers,
    // computer detail, settings sub-pages, release notes, an open thread and an
    // open Search/Activity content slot all hide it; guests have no Members.
    for (final guest in [false, true]) {
      testWidgets(
        '[N21] actual RaftApp $theme ${guest ? 'guest' : 'member'} tab bar only on the four tab roots',
        (t) async {
          final f = RootFixture();
          if (guest) f.servers[0] = {...f.servers[0], 'role': 'guest'};
          final agent = {
            'id': 'agent-1',
            'name': 'agent-one',
            'displayName': 'Agent One',
            'status': 'active',
          };
          f.overrides['GET /agents'] = (_) => [agent];
          f.overrides['GET /agents/agent-1'] = (_) => agent;
          f.overrides['GET /servers/a/members'] = (_) => [
            {'userId': 'alice', 'name': 'alice', 'role': 'owner'},
            {'userId': 'human-1', 'name': 'human-one', 'role': 'member'},
          ];
          await f.mount(t, theme, 390, uri: Uri.parse('/s/alpha'));
          final w = f.workspace(t);

          Future<void> visit(String path) async {
            w.navigation.navigate(RaftLocation.parse(path));
            w.notifyListeners();
            await f.flush(t);
            // Covered pages stay live until the platform transition ends.
            await settleRoute(t);
            final expected = RaftLocation.parse(path);
            expect(w.location.route, expected.route, reason: path);
            expect(w.location.entityId, expected.entityId, reason: path);
            expect(w.location.settingsPath, expected.settingsPath);
            expect(w.location.thread?.itemId, expected.thread?.itemId);
            expect(w.location.content?.id, expected.content?.id, reason: path);
          }

          final roots = {
            '/s/alpha': 'chat',
            '/s/alpha/tasks': 'tasks',
            '/s/alpha/activity': 'activity',
            '/s/alpha/search': 'search',
          };
          for (final MapEntry(key: path, value: tab) in roots.entries) {
            await visit(path);
            expect(find.byKey(tabBar), findsOneWidget, reason: path);
            expect(
              t.widget<RaftMobileNav>(find.byKey(tabBar)).selectedId,
              tab,
              reason: path,
            );
            expect(find.byKey(const Key('mobile-tab-home')), findsOneWidget);
            expect(find.byKey(const Key('mobile-tab-tasks')), findsOneWidget);
            expect(find.byKey(const Key('mobile-tab-server')), findsOneWidget);
            expect(find.byKey(const Key('mobile-tab-members')), findsNothing);
            expect(find.byKey(const Key('mobile-tab-settings')), findsNothing);
          }
          for (final path in [
            '/s/alpha/channel/ca',
            '/s/alpha/dm/dm-peer',
            '/s/alpha/search?q=needle&open=channel:ca&msg=ma',
            '/s/alpha/activity?open=channel:ca&msg=ma',
            // Pushed from the server tab (v1.24), not tab roots.
            '/s/alpha/settings',
            if (!guest) '/s/alpha/members',
            '/s/alpha/saved',
            if (!guest) ...[
              '/s/alpha/agent/agent-1',
              '/s/alpha/human/human-1',
              '/s/alpha/members/graph',
            ],
            '/s/alpha/computers',
            '/s/alpha/computer/machine-1',
            '/s/alpha/settings/appearance',
            '/s/alpha/release-notes',
            '/s/alpha?thread=ca:ma',
            '/s/alpha/tasks?thread=ca:ma',
            '/s/alpha/settings?thread=ca:ma',
          ]) {
            await visit(path);
            expect(find.byKey(tabBar), findsNothing, reason: path);
            expect(
              find.byKey(const Key('mobile-tab-home')),
              findsNothing,
              reason: path,
            );
          }
          // Back on a root shows the bar again (it is not latched hidden).
          await visit('/s/alpha');
          expect(find.byKey(tabBar), findsOneWidget);
          await f.close(t);
        },
      );
    }
  }
}
