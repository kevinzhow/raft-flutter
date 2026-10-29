// The Settings catalogue is one list (WorkspaceSettings), but the phone shell
// renders it inside a page stack of mirror controllers whose host hand-copies
// every service. A service dropped on that path removes a destination or a
// card without any error. This mounts the real WorkspaceView with every
// service populated at the desktop and the phone width and compares what the
// user can reach: the destination ids, and a coarse signature of each
// destination's content.
@Tags(['slow'])
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/mobile_tabbar_preferences.dart';
import 'package:raft_flutter/data/personal_presentation.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/search_memory.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_flutter/platform/app_update.dart';
import 'package:raft_flutter/platform/client_release_notes.dart';
import 'package:raft_flutter/platform/native_notifications.dart';
import 'package:raft_ui/raft_ui.dart';

import 'flutter_test_config.dart' show leakDebt;
import 'workspace_source_location_contract_test.dart' show frames, pageFixture;
import 'support/app_services_fixture.dart';

/// Destinations only one layout lists on purpose (Sidebar.tsx mobileInline:
/// the phone has a bottom-bar choice and a Computers row; desktop has a
/// Computers rail mode), or that a platform gates: Desktop is the Linux
/// AppImage URI-scheme registration, so it appears wherever the test host does
/// and never because of the width.
const _phoneOnly = {'bottom-bar', 'computers'};
const _platformGated = {'desktop'};

/// Rows that leave the Settings page instead of showing a panel.
const _actions = {'documentation', 'computers'};

class _Memory implements SearchMemoryStorage {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

class _Notifications extends NativeNotificationService {
  _Notifications() : super(platform: TargetPlatform.android);
}

/// Every service WorkspaceView accepts, populated.
class _Services {
  final notifications = _Notifications();
  final presentation = PersonalPresentationStore(storage: _Memory());
  final mobileTabbar = MobileTabbarStore();
  late final appUpdate = AppUpdateService(
    currentVersion: '0.1.0',
    currentBuild: 20,
    platformKey: 'android-arm64',
    target: TargetPlatform.android,
    storage: _Memory(),
    scheduleTimer: false,
    releaseNotes: ClientReleaseNotes(
      storage: _Memory(),
      fetch: (_) async => jsonEncode({'items': <Object>[], 'nextCursor': null}),
    ),
    fetch: (_) async => jsonEncode([
      {
        'platform': 'android',
        'arch': 'arm64',
        'version': '0.1.0',
        'buildNumber': '37',
        'releaseTag': 'v0.1.0+5',
        'artifact': 'raft-flutter-0.1.0+5-android-arm64.apk',
      },
    ]),
  );
  void dispose() {
    notifications.dispose();
    presentation.dispose();
    mobileTabbar.dispose();
    appUpdate.dispose();
  }
}

bool _phone(double width) => width < 768;

Future<WorkspaceController> _mount(
  WidgetTester t,
  _Services services,
  double width,
) async {
  final (w, api) = await pageFixture(t, section: 'chat');
  api.routes['GET /agents'] = (_) => [];
  api.routes['GET /servers/s1/members'] = (_) => [];
  api.routes['GET /product-feedback/tickets'] = (_) => {
    'items': [],
    'unread_total': 0,
  };
  t.view.physicalSize = Size(width, 800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: raftTheme(),
      home: withAppServices(
        WorkspaceView(
          controller: w,
          appearance: const RaftAppearance(),
          onAppearance: (_) async {},
          onLogout: () async {},
          notifications: services.notifications,
          presentation: services.presentation,
          mobileTabbar: services.mobileTabbar,
        ),
        update: services.appUpdate,
      ),
    ),
  );
  await frames(t, () {});
  await t.pumpAndSettle();
  if (_phone(width)) {
    w.navigation.navigate(RaftLocation.parse('/s/demo/settings'));
    w.notifyListeners();
  } else {
    await t.tap(find.byKey(const Key('rail-settings')));
  }
  await t.pumpAndSettle();
  return w;
}

/// The ids the Settings navigation lists, in order, with their group.
List<String> _listed(WidgetTester t) => [
  for (final g
      in t
          .widget<RaftSettingsSidebarList>(find.byType(RaftSettingsSidebarList))
          .groups)
    for (final i in g.items) '${g.label}/${i.id}',
];

/// Ordered `settings-*` keys and section headers below the open panel.
List<String> _signature(WidgetTester t) {
  final out = <String>[];
  void visit(Element e) {
    final key = e.widget.key;
    if (key is ValueKey<String> && key.value.startsWith('settings-')) {
      out.add('key:${key.value}');
    }
    if (e.widget case final RaftSettingsSectionHeader h) {
      out.add('header:${h.label}');
    }
    e.visitChildren(visit);
  }

  find.byType(RaftSettingsPanelFrame).evaluate().single.visitChildren(visit);
  return out;
}

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 10; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  await t.pumpAndSettle();
}

/// Opens every panel destination in turn and records its signature.
Future<Map<String, List<String>>> _walk(WidgetTester t, double width) async {
  final signatures = <String, List<String>>{};
  final ids = [for (final entry in _listed(t)) entry.split('/').last]
      .where((id) => !_actions.contains(id))
      .toList();
  for (final id in ids) {
    final row = find.byKey(ValueKey('workspace-settings-nav-$id'));
    expect(row, findsOneWidget, reason: '$id row at width $width');
    await t.ensureVisible(row);
    await t.tap(row);
    await _settle(t);
    signatures[id] = _signature(t);
    // The test font is 1em wide, so a nowrap label can overflow a 390 px
    // layout (settings_billing_apps_test mounts Plan & Billing at 600 for the
    // same reason); that is the only error tolerated while walking.
    final thrown = t.takeException();
    if (thrown != null) {
      expect('$thrown', contains('A RenderFlex overflowed'), reason: id);
    }
    if (_phone(width)) {
      await t.pageBack();
      await _settle(t);
      expect(
        find.byType(RaftSettingsSidebarList),
        findsOneWidget,
        reason: 'back to the Settings list after $id',
      );
    }
  }
  return signatures;
}

void main() {
  // Leak debt (other): see docs/development.md, Leak tracking.
  leakDebt(const ['ValueNotifier<bool>']);

  testWidgets(
    'Settings destinations match between the desktop and the phone '
    'shell',
    (t) async {
      final desktopServices = _Services();
      addTearDown(desktopServices.dispose);
      await t.runAsync(desktopServices.appUpdate.start);
      await _mount(t, desktopServices, 1280);
      final desktop = await _walk(t, 1280);
      final desktopIds = _listed(t);
      await t.pumpWidget(const SizedBox());

      final phoneServices = _Services();
      addTearDown(phoneServices.dispose);
      await t.runAsync(phoneServices.appUpdate.start);
      await _mount(t, phoneServices, 390);
      final phone = await _walk(t, 390);
      final phoneIds = _listed(t);
      await t.pumpWidget(const SizedBox());

      String id(String listed) => listed.split('/').last;
      Set<String> ids(List<String> listed) =>
          {for (final e in listed) id(e)}.difference(_platformGated);
      final onlyDesktop = ids(desktopIds).difference(ids(phoneIds));
      final onlyPhone = ids(phoneIds)
          .difference(ids(desktopIds))
          .difference(_phoneOnly);
      expect(
        onlyDesktop,
        isEmpty,
        reason: 'listed on desktop but missing from the phone Settings list',
      );
      expect(
        onlyPhone,
        isEmpty,
        reason:
            'listed on the phone but missing on desktop (allowed: '
            '$_phoneOnly)',
      );
      // The same destinations sit in the same groups, in the same order.
      List<String> shared(List<String> listed) => [
        for (final e in listed)
          if (!_phoneOnly.contains(id(e)) && !_platformGated.contains(id(e))) e,
      ];
      expect(shared(phoneIds), shared(desktopIds));

      for (final dest in desktop.keys) {
        if (!phone.containsKey(dest)) continue;
        expect(
          phone[dest],
          desktop[dest],
          reason: '"$dest" shows different content on the phone',
        );
      }
      // The walk must have seen the destinations the services unlock.
      expect(
        desktop.keys,
        containsAll(['account', 'appearance', 'notifications', 'about']),
      );
      expect(desktop['about'], contains('key:settings-about-update'));
      expect(phone['about'], contains('key:settings-about-update'));
      // About's mobile-app block is gated by the platform, not the width, so it
      // is part of both signatures on the desktop platform and of neither on
      // Android.
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.macOS,
    }),
  );
}
