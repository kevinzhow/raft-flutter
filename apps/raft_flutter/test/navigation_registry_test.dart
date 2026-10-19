import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/mobile_tabbar_preferences.dart';
import 'package:raft_flutter/data/navigation_registry.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/data/workspace_navigation.dart';
import 'package:raft_flutter/features/create_agent_dialog.dart';
import 'package:raft_flutter/features/create_channel_dialog.dart';
import 'package:raft_flutter/features/create_joint_channel_dialog.dart';
import 'package:raft_flutter/features/desktop_navigation_policy.dart';
import 'package:raft_flutter/features/fleet_views.dart';
import 'package:raft_flutter/features/managed_agent_launcher.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_flutter/features/settings_page.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_flutter/platform/native_notifications.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_presentation_test.dart' show MessageAdapter, fixture;
import 'flutter_test_config.dart' show leakDebt;
import 'support/app_services_fixture.dart';

class _Notifications extends NativeNotificationService {
  _Notifications() {
    enabled = true;
    permitted = true;
    available = true;
  }
  @override
  Future<void> initialize() async {}
  @override
  Future<void> bind(String? scope) async {}
}

/// Navigation entry points must never fall back silently to a default page
/// (the Joint channels "+" opened the personal Account page on a phone). The
/// registry in lib/data/navigation_registry.dart lists every target named by
/// literal; this file walks it on a phone and a wide WorkspaceView and walks
/// the phone sidebar's "+" buttons and menus. docs/navigation-audit.md has
/// the per-entry-point table.
/// Ignores RenderFlex overflow and reports every other framework error as
/// usual. The Ahem test font is 1em wide per glyph, so phone-width cards
/// overflow in tests that fit with the real fonts (see
/// settings_billing_apps_test.dart). Call from a test body before pumping.
void ignoreFontOverflow() {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    if ('${details.exception}'.contains('overflowed')) return;
    previous?.call(details);
  };
  addTearDown(() => FlutterError.onError = previous);
}

/// No framework error is pending (overflow aside, see [ignoreFontOverflow]).
void noException(WidgetTester tester, String reason) {
  final error = tester.takeException();
  if (error != null) fail('$reason: $error');
}

void main() {
  // Leak debt (app root, other): see docs/development.md, Leak tracking.
  leakDebt(const ['ValueNotifier<bool>', '_Notifications']);
  group('registry', () {
    final lib = Directory('lib');
    final sources = [
      for (final file in lib.listSync(recursive: true))
        if (file is File &&
            file.path.endsWith('.dart') &&
            !file.path.contains('/l10n/') &&
            !file.path.endsWith('navigation_registry.dart'))
          (file.path, file.readAsStringSync()),
    ];

    Iterable<(String, String, String)> literals(RegExp pattern) sync* {
      for (final (path, text) in sources) {
        for (final match in pattern.allMatches(text)) {
          yield (path, match.group(1)!, match.group(0)!);
        }
      }
    }

    test('every section literal in lib/ is registered', () {
      final unknown = <String>[];
      for (final pattern in [
        RegExp(r"\bselect\(\s*'([^']+)'"),
        RegExp(r"\bsetSection\(\s*'([^']+)'"),
        RegExp(r"\bselectSection\(\s*'([^']+)'"),
        RegExp(r"\bselectRoute\(\s*'([^']+)'"),
        RegExp(r"\bcanVisitSection\(\s*'([^']+)'"),
        RegExp(r"\bsection = '([^']+)'"),
      ]) {
        for (final (path, value, _) in literals(pattern)) {
          if (!NavigationRegistry.knowsSection(value)) {
            unknown.add('$path: "$value"');
          }
        }
      }
      expect(
        unknown,
        isEmpty,
        reason:
            'Register new section targets in NavigationRegistry.sections '
            '(the walk below then proves they land on a page).',
      );
    });

    test('every settings tab literal in lib/ is registered', () {
      final unknown = <String>[];
      for (final pattern in [
        RegExp(r"\bopenHelpSettings\(\s*'([^']+)'"),
        RegExp(r"settingsPath:\s*(?:const\s*)?\[\s*'([^']+)'"),
      ]) {
        for (final (path, value, _) in literals(pattern)) {
          if (!NavigationRegistry.knowsSettingsTab(value)) {
            unknown.add('$path: "$value"');
          }
        }
      }
      expect(unknown, isEmpty);
      expect(
        NavigationRegistry.settingsPathLiterals.every(
          NavigationRegistry.knowsSettingsTab,
        ),
        isTrue,
      );
    });

    test('unsupported sections are never registered or routable', () {
      for (final id in NavigationRegistry.unsupportedSections.keys) {
        expect(NavigationRegistry.knowsSection(id), isFalse, reason: id);
        expect(
          WorkspaceNavigation.settingsSections,
          isNot(contains(id)),
          reason: id,
        );
      }
    });

    test('settings sections and registry agree', () {
      final sub = {
        for (final s in NavigationRegistry.sections)
          if (s.settingsTab != null) s.id,
      };
      expect(WorkspaceNavigation.settingsSections, sub);
      for (final s in NavigationRegistry.sections) {
        final tab = s.settingsTab;
        if (tab == null) continue;
        expect(NavigationRegistry.knowsSettingsTab(tab), isTrue, reason: tab);
        expect(
          WorkspaceNavigation.settingsTab(
            WorkspaceNavigation.settingsRouteSlug(s.id),
          ),
          tab,
          reason: s.id,
        );
      }
    });

    test('bottom-bar tabs and rail ids resolve to registered sections', () {
      for (final id in [...MobileTabs.configurable, MobileTabs.settings]) {
        final section = id == 'chat' ? 'home' : id;
        expect(NavigationRegistry.knowsSection(section), isTrue, reason: id);
      }
      for (final id in [
        'search',
        'chat',
        'activity',
        'tasks',
        'members',
        'computers',
        'settings',
      ]) {
        expect(NavigationRegistry.knowsSection(id), isTrue, reason: id);
      }
    });

    test('every registered page section has a desktop rail mode', () {
      for (final s in NavigationRegistry.sections) {
        // Settings sub-pages are rendered under the 'settings' rail mode.
        final rail = s.settingsTab == null ? s.id : 'settings';
        expect(() => DesktopNavigationPolicy.forSection(rail), returnsNormally);
      }
      expect(
        () => DesktopNavigationPolicy.forSection('billing'),
        throwsA(isA<FlutterError>()),
      );
    });

    test('every registered section builds its own location', () {
      for (final s in NavigationRegistry.sections) {
        final location = WorkspaceNavigation.locationForSection('s', s.id);
        expect(location.route, s.route, reason: s.id);
        if (s.settingsTab != null) {
          expect(
            WorkspaceNavigation.settingsTab(location.settingsPath.single),
            s.settingsTab,
            reason: s.id,
          );
        }
      }
    });
  });

  group('guard', () {
    test('unknown and unsupported sections fail loudly in debug', () {
      expect(kDebugMode, isTrue);
      for (final id in ['joint-channels', 'sidebar-settings', 'nope']) {
        expect(
          () => WorkspaceNavigation.locationForSection('s', id),
          throwsA(
            isA<FlutterError>().having(
              (e) => e.message,
              'message',
              contains('"$id"'),
            ),
          ),
          reason: id,
        );
      }
    });

    test('the controller refuses an unknown section loudly', () async {
      final made = await fixture('owner');
      addTearDown(made.$1.dispose);
      expect(
        () => made.$1.setSection('joint-channels'),
        throwsA(isA<FlutterError>()),
      );
      expect(made.$1.section, isNot('joint-channels'));
    });

    testWidgets('settings page: unknown tab throws, gated tab falls back', (
      tester,
    ) async {
      Widget page(String tab) => MaterialApp(
        home: Scaffold(
          body: RaftSettingsPage(
            initialTab: tab,
            destinations: [
              RaftSettingsDestination(
                'account',
                'Account',
                RaftGlyph.user,
                (_) => const Text('account page'),
              ),
            ],
          ),
        ),
      );
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      // Known to the registry but not offered here (billing for a member):
      // Web's denied tab shows Account.
      await tester.pumpWidget(page('billing'));
      expect(find.text('account page'), findsOneWidget);
      expect(tester.takeException(), isNull);
      // Not a tab at all: this is the Joint channels bug class.
      await tester.pumpWidget(page('joint-channels'));
      expect(tester.takeException(), isA<FlutterError>());
    });
  });

  for (final layout in const [
    ('phone', Size(390, 844)),
    ('wide', Size(1280, 800)),
  ]) {
    final (name, size) = layout;
    final phone = name == 'phone';

    group('$name WorkspaceView', () {
      late WorkspaceController w;
      late MessageAdapter api;
      final notifications = _Notifications();

      Widget view() => MaterialApp(
        theme: raftTheme(RaftFamily.brutal),
        home: withAppServices(
          WorkspaceView(
            controller: w,
            appearance: RaftAppearance(light: RaftFamily.brutal),
            onAppearance: (_) async {},
            onLogout: () async {},
            notifications: notifications,
          ),
        ),
      );

      Future<void> setup(WidgetTester tester) async {
        ignoreFontOverflow();
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final made = (await tester.runAsync(() => fixture('owner')))!;
        w = made.$1;
        api = made.$2;
        addTearDown(w.dispose);
        w.loading = false;
        w.messageDomain.ledger.switchServer('s1');
        w.channels = [
          RaftChannel({'id': 'c1', 'name': 'general', 'joined': true}),
          RaftChannel({'id': 'c2', 'name': 'random', 'joined': true}),
        ];
        w.dms = [
          RaftChannel({
            'id': 'd1',
            'name': 'Alice',
            'type': 'dm',
            'joined': true,
            'peerType': 'user',
            'peerId': 'u2',
            'peerName': 'alice',
            'peerDisplayName': 'Alice',
          }),
          RaftChannel({
            'id': 'd2',
            'name': 'Cindy',
            'type': 'dm',
            'joined': true,
            'peerType': 'agent',
            'peerId': 'a1',
            'peerName': 'cindy',
            'peerDisplayName': 'Cindy',
          }),
        ];
        w.sidebarOrder = {'sectionsVersion': 3, 'pinnedVersion': 1};
        w.section = 'home';
        api.routes['GET /servers/s1/sidebar-order'] = (_) => w.sidebarOrder;
        api.routes['PATCH /servers/s1/sidebar-order'] = (o) => {
          ...w.sidebarOrder,
          ...Map<String, dynamic>.from(o.data as Map),
        };
        api.routes['POST /channels/c1/read-all'] = (_) => {
          'unreadCount': 0,
          'seq': '5',
          'maxReadSeq': '5',
        };
        api.routes['POST /channels/c1/unread'] = (_) => {
          'unreadCount': 1,
          'seq': '5',
          'maxReadSeq': '5',
        };
        api.routes['POST /channels/d1/read-all'] = (_) => {
          'unreadCount': 0,
          'seq': '5',
          'maxReadSeq': '5',
        };
        api.routes['POST /channels/d2/read-all'] = (_) => {
          'unreadCount': 0,
          'seq': '5',
          'maxReadSeq': '5',
        };
        api.routes['GET /channels/unread'] = (_) => {
          'channels': {'c1': 1},
        };
        api.routes['GET /channels/threads/followed'] = (_) => {'threads': []};
        // Provider connections, IM bridges and Labs follow server flags.
        api.routes['POST /feature-flags/evaluate'] = (_) => {
          'evaluations': [
            for (final key in [
              'slack_bridge_v0',
              'provider_connections_v0',
              'server_labs_ui_v0',
            ])
              {'key': key, 'enabled': true},
          ],
        };
        api.routes['GET /servers/s1/setup-projection'] = (_) => {
          'phase': 'complete',
          'surface': 'complete',
          'blocksChat': false,
        };
        api.routes['GET /agents'] = (_) => {'agents': []};
        api.routes['GET /servers/s1/members'] = (_) => {'members': []};
        api.routes['GET /billing/subscription'] = (_) => {
          'plan': 'free',
          'displayName': 'Free',
          'capacity': {'maxHumans': 1, 'maxAgents': 2, 'maxUniversalSeats': -1},
          'usage': {'humans': 2, 'agents': 2, 'universalSeats': 0},
          'provisioned': {'humans': 1, 'agents': 2, 'proPackQuantity': 0},
          'fileUploadQuota': {
            'limited': true,
            'limitBytes': 524288000,
            'usedBytes': 188743680,
          },
          'price': null,
          'subscription': null,
          'stripeConfigured': true,
          'permissions': {
            'canReadBillingSummary': true,
            'canManageBilling': true,
          },
        };
        api.routes['GET /servers/s1/usage'] = (_) => {
          'agents': 2,
          'machines': 1,
          'channels': 4,
        };
        await tester.pumpWidget(view());
        await tester.pumpAndSettle();
      }

      /// The settings page's destinations (what the user can open).
      List<RaftSettingsDestination> destinations(WidgetTester tester) => tester
          .widget<RaftSettingsPage>(find.byType(RaftSettingsPage))
          .destinations;

      Finder pageOf(String tab) => find.descendant(
        of: find.byType(RaftSettingsPage),
        matching: find.byKey(ValueKey(tab)),
      );

      testWidgets('every registered section lands on its intended page', (
        tester,
      ) async {
        await setup(tester);
        for (final target in NavigationRegistry.sections) {
          // A fresh page per target: no state carried over from the last.
          await tester.pumpWidget(const SizedBox());
          w.setSection('home');
          await tester.pumpWidget(view());
          await tester.pumpAndSettle();
          w.setSection(target.id);
          await tester.pumpAndSettle();
          final reason = '$name: ${target.id}';
          noException(tester, reason);
          final route = w.location.route;
          if (target.id == 'chat') {
            expect({RaftRoute.home, RaftRoute.channel}, contains(route));
          } else {
            expect(route, target.route, reason: reason);
          }
          final settings = find.byType(RaftSettingsPage);
          if (target.settingsTab != null) {
            expect(settings, findsOneWidget, reason: reason);
            expect(
              w.location.settingsPath.single,
              WorkspaceNavigation.settingsRouteSlug(target.id),
              reason: reason,
            );
            // The page of the tab, never the Account fallback.
            expect(pageOf(target.settingsTab!), findsOneWidget, reason: reason);
            expect(pageOf('account'), findsNothing, reason: reason);
          } else if (target.id == 'settings') {
            expect(settings, findsOneWidget, reason: reason);
            expect(w.location.settingsPath, isEmpty, reason: reason);
          } else {
            expect(settings, findsNothing, reason: reason);
          }
          switch (target.id) {
            case 'search' || 'activity' || 'saved':
              expect(find.byType(ResourceView), findsOneWidget, reason: reason);
            case 'computers' when phone:
              expect(find.byType(FleetView), findsOneWidget, reason: reason);
            case 'home' when phone:
              expect(
                find.byKey(const Key('workspace-mobile-home')),
                findsOneWidget,
                reason: reason,
              );
          }
        }
      });

      testWidgets('every settings row opens its own tab or action', (
        tester,
      ) async {
        await setup(tester);
        w.setSection('settings');
        await tester.pumpAndSettle();
        final offered = destinations(tester);
        // Everything the page offers is registered; everything registered is
        // offered on this layout, or declared absent with a reason.
        for (final d in offered) {
          expect(
            NavigationRegistry.knowsSettingsTab(d.id),
            isTrue,
            reason: '${d.id} is offered but not registered',
          );
        }
        final shownIds = {
          for (final d in offered)
            if (phone || !d.mobileOnly) d.id,
        };
        for (final tab in NavigationRegistry.settingsTabs) {
          final supported = phone ? tab.phone : tab.wide;
          expect(
            shownIds.contains(tab.id),
            supported,
            reason:
                '$name: ${tab.id} ${supported ? 'must be offered' : 'is declared unsupported: ${tab.reason}'}',
          );
        }
        for (final d in offered) {
          if (!phone && d.mobileOnly) continue;
          if (d.id == 'documentation') continue; // external launch
          w.setSection('settings');
          await tester.pumpAndSettle();
          final list = find.byType(RaftSettingsSidebarList);
          final row = find.descendant(of: list, matching: find.text(d.label));
          expect(row, findsWidgets, reason: '$name: ${d.id} row');
          await tester.ensureVisible(row.first);
          await tester.tap(row.first);
          await tester.pumpAndSettle();
          noException(tester, '$name: ${d.id}');
          if (d.builder == null) {
            // 'computers' is a Settings row that opens the Computers route.
            expect(d.id, 'computers');
            expect(w.location.route, RaftRoute.computers);
          } else {
            expect(pageOf(d.id), findsOneWidget, reason: '$name: ${d.id}');
          }
        }
      });
    });
  }

  group('phone Home sidebar', () {
    late WorkspaceController w;
    late MessageAdapter api;

    Future<void> setup(WidgetTester tester) async {
      ignoreFontOverflow();
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final made = (await tester.runAsync(() => fixture('owner')))!;
      w = made.$1;
      api = made.$2;
      addTearDown(w.dispose);
      w.loading = false;
      w.messageDomain.ledger.switchServer('s1');
      w.channels = [
        RaftChannel({'id': 'c1', 'name': 'general', 'joined': true}),
        RaftChannel({'id': 'c2', 'name': 'random', 'joined': true}),
      ];
      w.dms = [
        RaftChannel({
          'id': 'd1',
          'name': 'Alice',
          'type': 'dm',
          'joined': true,
          'peerType': 'user',
          'peerId': 'u2',
          'peerName': 'alice',
          'peerDisplayName': 'Alice',
        }),
        RaftChannel({
          'id': 'd2',
          'name': 'Cindy',
          'type': 'dm',
          'joined': true,
          'peerType': 'agent',
          'peerId': 'a1',
          'peerName': 'cindy',
          'peerDisplayName': 'Cindy',
        }),
      ];
      w.sidebarOrder = {'sectionsVersion': 3, 'pinnedVersion': 1};
      w.section = 'home';
      api.routes['GET /servers/s1/sidebar-order'] = (_) => w.sidebarOrder;
      api.routes['PATCH /servers/s1/sidebar-order'] = (o) => {
        ...w.sidebarOrder,
        ...Map<String, dynamic>.from(o.data as Map),
      };
      for (final path in [
        '/channels/c1/read-all',
        '/channels/c1/unread',
        '/channels/d1/read-all',
        '/channels/d2/read-all',
      ]) {
        api.routes['POST $path'] = (_) => {
          'unreadCount': 0,
          'seq': '5',
          'maxReadSeq': '5',
        };
      }
      api.routes['GET /channels/unread'] = (_) => {
        'channels': {'c1': 1},
      };
      api.routes['GET /channels/threads/followed'] = (_) => {'threads': []};
      api.routes['POST /feature-flags/evaluate'] = (_) => {'evaluations': []};
      api.routes['GET /servers/s1/setup-projection'] = (_) => {
        'phase': 'complete',
        'surface': 'complete',
        'blocksChat': false,
      };
      api.routes['GET /agents'] = (_) => {'agents': []};
      api.routes['GET /servers/s1/members'] = (_) => {'members': []};
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.brutal),
          home: withAppServices(
            WorkspaceView(
              controller: w,
              appearance: RaftAppearance(light: RaftFamily.brutal),
              onAppearance: (_) async {},
              onLogout: () async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Finder header(String group) =>
        find.byKey(ValueKey('sidebar-section-system:$group'));
    Finder row(String id) => find.byKey(ValueKey('sidebar-channel-$id'));

    /// Closes every dialog and menu route above the workspace.
    Future<void> dismiss(WidgetTester tester) async {
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      while (navigator.canPop()) {
        navigator.pop();
        await tester.pumpAndSettle();
      }
      // Let a long press that follows start a fresh gesture.
      await tester.pump(const Duration(seconds: 1));
    }

    /// Dialog (or page) each menu item must open, by item label. Every other
    /// item is an in-place action: it must not change the location.
    Finder? opens(String label) => switch (label) {
      'Create Channel' => find.byType(CreateChannelDialog),
      'Create Joint Channel' => find.byType(CreateJointChannelDialog),
      'New section…' || 'Rename / change icon…' => find.byKey(
        const ValueKey('sidebar-section-dialog'),
      ),
      'Archive' ||
      'Delete section' => find.byKey(const ValueKey('shell-dialog')),
      _ => null,
    };

    Future<void> walkMenu(
      WidgetTester tester,
      Future<void> Function() open, {
      required Set<String> expectLabels,
    }) async {
      final before = w.location.uri;
      await open();
      final menu = tester.widget<RaftSidebarContextMenu>(
        find.byType(RaftSidebarContextMenu),
      );
      final items = [
        for (final e in menu.entries)
          if (e is RaftSidebarMenuItem && e.onPressed != null && !e.submenu)
            e.label,
      ];
      expect(items.toSet().containsAll(expectLabels), isTrue, reason: '$items');
      await dismiss(tester);
      for (final label in items) {
        await open();
        final item = find.descendant(
          of: find.byType(RaftSidebarContextMenu),
          matching: find.text(label),
        );
        expect(item, findsWidgets, reason: label);
        await tester.tap(item.first);
        await tester.pumpAndSettle();
        noException(tester, label);
        final target = opens(label);
        if (target != null) {
          expect(target, findsOneWidget, reason: '$label opens its dialog');
        }
        expect(
          w.location.uri,
          before,
          reason: 'menu item "$label" must not navigate',
        );
        expect(w.location.route, RaftRoute.home, reason: label);
        await dismiss(tester);
      }
    }

    testWidgets('+ buttons open the Web dialog in place', (tester) async {
      await setup(tester);
      final before = w.location.uri;
      await tester.tap(find.bySemanticsLabel('Create channel'));
      await tester.pumpAndSettle();
      expect(find.byType(CreateChannelDialog), findsOneWidget);
      expect(w.location.uri, before);
      await dismiss(tester);
      await tester.tap(find.bySemanticsLabel('Create joint channel'));
      await tester.pumpAndSettle();
      expect(find.byType(CreateJointChannelDialog), findsOneWidget);
      expect(w.location.uri, before);
      expect(w.location.settingsPath, isEmpty);
    });

    testWidgets('Channels and Joint section menus', (tester) async {
      await setup(tester);
      await walkMenu(tester, () async {
        await tester.longPressAt(tester.getCenter(header('channels')));
        await tester.pumpAndSettle();
      }, expectLabels: {'Create Channel', 'New section…'});
      await walkMenu(tester, () async {
        await tester.longPressAt(tester.getCenter(header('joint')));
        await tester.pumpAndSettle();
      }, expectLabels: {'Create Joint Channel', 'New section…'});
      await walkMenu(tester, () async {
        await tester.longPressAt(tester.getCenter(header('dms')));
        await tester.pumpAndSettle();
      }, expectLabels: {'New section…'});
    });

    // Each item of the list-surface menu (long press on empty list space) in
    // a fresh page: the menu opens Web's dialogs in place.
    for (final label in const [
      'Create Channel',
      'Create Joint Channel',
      'New section…',
    ]) {
      testWidgets('sidebar surface menu: $label', (tester) async {
        await setup(tester);
        final before = w.location.uri;
        final list = find.byKey(const Key('workspace-sidebar'));
        await tester.longPressAt(
          tester.getBottomLeft(list) + const Offset(120, -30),
        );
        await tester.pumpAndSettle();
        final item = find.descendant(
          of: find.byType(RaftSidebarContextMenu),
          matching: find.text(label),
        );
        expect(item, findsOneWidget);
        await tester.tap(item);
        await tester.pumpAndSettle();
        noException(tester, label);
        expect(opens(label), findsOneWidget, reason: label);
        expect(w.location.uri, before);
      });
    }

    testWidgets('channel, human DM and agent DM row menus stay in place', (
      tester,
    ) async {
      await setup(tester);
      for (final (id, labels) in [
        ('c1', {'Pin', 'Mark as Unread'}),
        ('d1', {'Pin', 'Close Chat'}),
        ('d2', {'Pin', 'Close Chat'}),
      ]) {
        await walkMenu(tester, () async {
          await tester.longPress(row(id));
          await tester.pumpAndSettle();
        }, expectLabels: labels);
      }
    });

    testWidgets('a feedback notice opens Settings > Feedback (Web toSettings)', (
      tester,
    ) async {
      await setup(tester);
      api.routes['GET /product-feedback/tickets'] = (_) => {
        'unread_total': 2,
        'tickets': [],
      };
      api.routes['GET /servers/s1/machines'] = (_) => {'machines': []};
      // The bell reads on mount; rebuild the page so it sees the unread count.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.brutal),
          home: withAppServices(
            WorkspaceView(
              controller: w,
              appearance: RaftAppearance(light: RaftFamily.brutal),
              onAppearance: (_) async {},
              onLogout: () async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(RaftMobileNotificationButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('View feedback'));
      await tester.pumpAndSettle();
      expect(w.location.route, RaftRoute.settings);
      expect(w.location.settingsPath, ['feedback']);
      expect(find.byKey(const ValueKey('feedback')), findsOneWidget);
    });

    testWidgets('Create Agent "Upgrade for more" closes and opens Billing', (
      tester,
    ) async {
      await setup(tester);
      api.routes['GET /servers/s1/machines'] = (_) => {
        'machines': [
          {
            'id': 'm1',
            'name': 'Computer',
            'status': 'online',
            'runtimes': ['codex'],
          },
        ],
      };
      api.routes['GET /billing/subscription'] = (_) => {
        'displayName': 'Free',
        'capacity': {'maxAgents': 2},
        'usage': {'agents': 2},
      };
      final context = tester.element(find.byType(WorkspaceView));
      unawaited(showManagedAgentForm(context, w));
      await tester.pumpAndSettle();
      await tester.tapOnText(find.textRange.ofSubstring('Upgrade for more'));
      await tester.pumpAndSettle();
      expect(find.byType(CreateAgentDialog), findsNothing);
      expect(w.location.route, RaftRoute.settings);
      expect(w.location.settingsPath, ['billing']);
    });

    testWidgets('Search, Activity and Saved entries open their own pages', (
      tester,
    ) async {
      await setup(tester);
      for (final (key, route) in [
        ('nav-search', RaftRoute.search),
        ('nav-activity', RaftRoute.activity),
        ('nav-saved', RaftRoute.saved),
      ]) {
        w.setSection('home');
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(Key(key)));
        await tester.pumpAndSettle();
        expect(w.location.route, route, reason: key);
        expect(find.byType(RaftSettingsPage), findsNothing, reason: key);
      }
    });
  });
}
