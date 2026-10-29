import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/mobile_workspace_navigation.dart';
import 'package:raft_flutter/features/workspace_settings.dart';
import 'package:raft_flutter/platform/app_update.dart';
import 'package:raft_ui/raft_ui.dart';

import 'app_global_server_selector_test.dart' show RootFixture;
import 'workspace_source_location_contract_test.dart' show pageFixture;
import 'flutter_test_config.dart' show leakDebt;
import 'support/app_update_fixture.dart';
import 'support/memory_storage.dart';

/// Both layouts of the one real host: the desktop shell and the phone shell
/// (a page stack of mirror controllers, see mobile_workspace_route.dart). A
/// service the phone pages do not receive makes a feature vanish without any
/// error, so every host-level test below runs on both.
const _widths = [1280.0, 390.0];
bool _phone(double width) => width < 768;
String _on(double width) => _phone(width) ? 'phone' : 'desktop';

/// Opens the Settings destination: the rail on desktop, the tab bar on phone.
Future<void> _openSettings(
  WidgetTester t,
  WorkspaceController w,
  double width,
) async {
  if (_phone(width)) {
    // The tab bar only shows on a tab root; start from the Settings root.
    w.navigation.navigate(RaftLocation.parse('/s/demo/settings'));
    w.notifyListeners();
  } else {
    await t.tap(find.byKey(const Key('rail-settings')));
  }
  await t.pumpAndSettle();
}

/// The attention dot on the entry to Settings: the rail icon or the tab.
bool _entryDot(WidgetTester t, double width) => _phone(width)
    ? _tabAttention(t)
    : _railDotIn(find.byKey(const Key('rail-settings'))).evaluate().isNotEmpty;

Future<void> _openDestination(WidgetTester t, String id) async {
  final row = find.byKey(ValueKey('workspace-settings-nav-$id'));
  // Rows are 36px (raft-ui SidebarItem): the last ones sit below the fold, and
  // on the phone the bottom bar overlays the list's lower edge. Scroll the row
  // clear of it, as a user would.
  await t.ensureVisible(row);
  final screen = t.view.physicalSize.height / t.view.devicePixelRatio;
  if (t.getCenter(row).dy > screen - 120) {
    await t.drag(find.byType(RaftSettingsSidebarList), const Offset(0, -400));
    await t.pumpAndSettle();
  }
  await t.tap(row);
  for (var i = 0; i < 10; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  await t.pumpAndSettle();
}

Finder _dotIn(Finder of) =>
    find.descendant(of: of, matching: find.byType(RaftAttentionDot));
Finder _railDotIn(Finder of) =>
    find.descendant(of: of, matching: find.byType(RaftRailAttention));

/// Fills of the decorated boxes painted below [of] (recipe boxes wrap theirs
/// in a layered decoration).
List<Color> _fills(Finder of) => [
  for (final e
      in find
          .descendant(of: of, matching: find.byType(DecoratedBox))
          .evaluate())
    ?switch ((e.widget as DecoratedBox).decoration) {
      final BoxDecoration d => d.color,
      final RaftLayeredDecoration d => d.base.color,
      _ => null,
    },
];

/// The dot below [of] is painted with the theme's `--danger` token, never the
/// regular attention fill.
void _expectDanger(WidgetTester t, Finder of) {
  final tokens = RaftTokens.of(t.element(of.first));
  expect(tokens.colors['danger'], tokens.semantic.danger);
  expect(_fills(of), contains(tokens.semantic.danger));
  expect(_fills(of), isNot(contains(tokens.accentFill)));
}

bool _tabAttention(WidgetTester t) => t
    .widget<RaftMobileNav>(find.byKey(const Key('workspace-mobile-navigation')))
    .items
    .firstWhere((i) => i.id == 'settings')
    .attention;

void main() {
  // Leak debt (other): see docs/development.md, Leak tracking.
  leakDebt(const ['ValueNotifier<bool>']);
  for (final width in _widths) {
    testWidgets(
      '${_on(width)}: dot on Settings and About until About is opened',
      (t) async {
        final update = appUpdateFixture();
        addTearDown(update.dispose);
        await t.runAsync(update.start);
        final w = await mountAppUpdateWorkspace(t, update, width: width);
        if (!_phone(width)) expect(_entryDot(t, width), isTrue);

        await _openSettings(t, w, width);
        expect(_entryDot(t, width), isTrue);
        final about = find.byType(RaftSettingsSidebarList);
        expect(find.text('About'), findsOneWidget);
        expect(_dotIn(about), findsOneWidget);
        _expectDanger(t, _dotIn(about));
        // Opening Settings alone does not mark the release as seen.
        expect(update.hasUnseen, isTrue);

        await _openDestination(t, 'about');
        expect(find.text('New version available: 0.1.0 (37)'), findsOneWidget);
        _expectDanger(
          t,
          _dotIn(find.byKey(const ValueKey('settings-about-update'))),
        );
        expect(
          find.byKey(const ValueKey('settings-about-update-action')),
          findsOneWidget,
        );
        expect(find.text('View Release'), findsOneWidget);
        expect(update.hasUnseen, isFalse);
        if (_phone(width)) {
          // The covered list rebuilds when it comes back to the front.
          await t.pageBack();
          await t.pumpAndSettle();
        }
        expect(_entryDot(t, width), isFalse);
        expect(_dotIn(find.byType(RaftSettingsSidebarList)), findsNothing);
        if (!_phone(width)) {
          // The row stays so the user can still act on it.
          expect(find.text('New version available: 0.1.0 (37)'), findsOne);
        }
        await t.pumpWidget(const SizedBox());
      },
      variant: TargetPlatformVariant({TargetPlatform.macOS}),
    );

    testWidgets('${_on(width)}: Android offers the APK download', (t) async {
      final update = appUpdateFixture(platform: 'android-arm64');
      addTearDown(update.dispose);
      await t.runAsync(update.start);
      final w = await mountAppUpdateWorkspace(t, update, width: width);
      await _openSettings(t, w, width);
      await _openDestination(t, 'about');
      expect(find.text('Download Update'), findsOneWidget);
      expect(find.text('View Release'), findsNothing);
      await t.pumpWidget(const SizedBox());
    }, variant: TargetPlatformVariant({TargetPlatform.android}));

    testWidgets('${_on(width)}: a newer build brings the dot back after it '
        'was seen', (t) async {
      final update = appUpdateFixture();
      addTearDown(update.dispose);
      await t.runAsync(update.start);
      update.markSeen();
      final w = await mountAppUpdateWorkspace(t, update, width: width);
      await _openSettings(t, w, width);
      expect(_entryDot(t, width), isFalse);
      expect(_dotIn(find.byType(RaftSettingsSidebarList)), findsNothing);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('${_on(width)}: no dot and no row when up to date or without '
        'a service', (t) async {
      final current = appUpdateFixture(build: 37);
      addTearDown(current.dispose);
      await t.runAsync(current.start);
      var w = await mountAppUpdateWorkspace(t, current, width: width);
      await _openSettings(t, w, width);
      expect(_entryDot(t, width), isFalse);
      await _openDestination(t, 'about');
      expect(find.textContaining('New version available'), findsNothing);
      // Up to date is still answered: the Updates card never goes away.
      expect(find.text("You're on the latest version"), findsOneWidget);
      expect(
        find.byKey(const ValueKey('settings-about-update-check')),
        findsOne,
      );
      await t.pumpWidget(const SizedBox());

      w = await mountAppUpdateWorkspace(t, null, width: width);
      await _openSettings(t, w, width);
      expect(_entryDot(t, width), isFalse);
      await _openDestination(t, 'about');
      expect(find.byKey(const ValueKey('settings-about-update')), findsNothing);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('${_on(width)}: Release Notes load from the update service '
        'source', (t) async {
      final update = appUpdateFixture(withNotes: true);
      addTearDown(update.dispose);
      await t.runAsync(update.start);
      final w = await mountAppUpdateWorkspace(t, update, width: width);
      await _openSettings(t, w, width);
      await _openDestination(t, 'release-notes');
      expect(find.text('Fork guard notes'), findsOneWidget);
      expect(
        find.text('Release notes are unavailable right now.'),
        findsNothing,
      );
      await t.pumpWidget(const SizedBox());
    });
  }

  for (final width in _widths) {
    for (final (name, dark) in [
      ('elegant light', false),
      ('elegant dark', true),
    ]) {
      testWidgets(
        '${_on(width)}: About row dot is the danger token, the entry keeps '
        'its colour in $name',
        (t) async {
          final update = appUpdateFixture();
          addTearDown(update.dispose);
          await t.runAsync(update.start);
          final w = await mountAppUpdateWorkspace(
            t,
            update,
            width: width,
            dark: dark,
          );
          if (!_phone(width)) {
            final settings = find.byKey(const Key('rail-settings'));
            // The rail keeps the theme's own attention colour, not the red.
            final rail = find.descendant(
              of: settings,
              matching: find.byKey(const ValueKey('rail-attention-indicator')),
            );
            expect(rail, findsOneWidget);
            expect(
              _fills(rail),
              isNot(contains(RaftTokens.of(t.element(rail)).semantic.danger)),
            );
          }
          await _openSettings(t, w, width);
          expect(_entryDot(t, width), isTrue);
          _expectDanger(t, _dotIn(find.byType(RaftSettingsSidebarList)));
          await t.pumpWidget(const SizedBox());
        },
      );
    }
  }

  for (final (name, dark) in [
    ('elegant light', false),
    ('elegant dark', true),
  ]) {
    testWidgets('phone: Settings tab dot keeps the attention colour in $name', (
      t,
    ) async {
      final update = appUpdateFixture();
      addTearDown(update.dispose);
      await t.runAsync(update.start);
      final (w, _) = await pageFixture(t, section: 'chat');
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(dark: dark),
          home: Scaffold(
            body: const SizedBox(),
            bottomNavigationBar: WorkspaceMobileTabBar(
              controller: w,
              selectedId: 'home',
              onSelected: (_) {},
              appUpdate: update,
            ),
          ),
        ),
      );
      expect(_tabAttention(t), isTrue);
      final tokens = RaftTokens.of(
        t.element(find.byType(WorkspaceMobileTabBar)),
      );
      final tab = find.byKey(const Key('mobile-tab-settings'));
      expect(_fills(tab), contains(tokens.accentFill));
      expect(_fills(tab), isNot(contains(tokens.semantic.danger)));
      update.markSeen();
      await t.pumpAndSettle();
      expect(_tabAttention(t), isFalse);
      await t.pumpWidget(const SizedBox());
    });
  }
  // The phone shell renders every page inside _MobileWorkspaceContent, a
  // WorkspaceView sharing the root's AppServicesScope; the update service must
  // reach it or About loses the Updates card and Release Notes loses its
  // source (v0.1.0+7 on Android showed neither).
  group('phone (actual RaftApp, 390 wide, Android)', () {
    AppUpdateService android() => AppUpdateService(
      currentVersion: '0.1.0',
      currentBuild: 41,
      platformKey: 'android-arm64',
      target: TargetPlatform.android,
      storage: MemoryStorage(),
      scheduleTimer: false,
      releaseNotes: appUpdateNotes('Phone notes arrive'),
      fetch: (_) async => jsonEncode([
        {
          'platform': 'android',
          'arch': 'arm64',
          'version': '0.1.0',
          'buildNumber': '42',
          'releaseTag': 'v0.1.0+8',
          'artifact': 'raft-flutter-0.1.0+8-android-arm64.apk',
        },
      ]),
    );

    Future<RootFixture> openSettings(WidgetTester t, AppUpdateService s) async {
      final f = RootFixture();
      await f.mount(t, 'light', 390, uri: Uri.parse('/s/alpha'), appUpdate: s);
      await t.runAsync(s.start);
      await t.tap(find.byKey(const Key('mobile-tab-settings')));
      await f.flush(t);
      return f;
    }

    testWidgets('About shows the Updates card and the red dots', (t) async {
      final update = android();
      addTearDown(update.dispose);
      final f = await openSettings(t, update);
      expect(_tabAttention(t), isTrue);
      await t.tap(find.byKey(const ValueKey('workspace-settings-nav-about')));
      await f.flush(t);
      for (var i = 0; i < 10; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(
        find.byKey(const ValueKey('settings-about-update')),
        findsOneWidget,
      );
      expect(find.text('New version available: 0.1.0 (42)'), findsOneWidget);
      expect(find.text('Download Update'), findsOneWidget);
      expect(find.text('Check for Updates'), findsOneWidget);
      await f.close(t);
    });

    testWidgets('Release Notes load from the update service source', (t) async {
      final update = android();
      addTearDown(update.dispose);
      final f = await openSettings(t, update);
      await t.tap(
        find.byKey(const ValueKey('workspace-settings-nav-release-notes')),
      );
      await f.flush(t);
      for (var i = 0; i < 10; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Phone notes arrive'), findsOneWidget);
      expect(
        find.text('Release notes are unavailable right now.'),
        findsNothing,
      );
      await f.close(t);
    });
  });

  test('About shows the running version with its CI build number', () {
    expect(
      WorkspaceAboutSection.versionLabel(version: '0.1.0', build: '41'),
      '0.1.0 (41)',
    );
    expect(
      WorkspaceAboutSection.versionLabel(version: '0.1.0-dev.abc', build: ''),
      '0.1.0-dev.abc',
    );
    expect(
      WorkspaceAboutSection.versionLabel(version: 'development', build: '0'),
      'development',
    );
  });
}
