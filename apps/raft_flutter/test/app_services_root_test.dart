import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/features/workspace_settings.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_flutter/main.dart';
import 'package:raft_flutter/platform/app_services.dart';
import 'package:raft_flutter/platform/app_update.dart';

import 'app_global_server_selector_test.dart' show RootFixture;
import 'flutter_test_config.dart' show leakDebt;
import 'support/tracked_app_update.dart';

Future<void> _replaceServices(
  WidgetTester t,
  AppUpdateService service, {
  bool owns = false,
}) async {
  final old = t.widget<RaftApp>(find.byType(RaftApp));
  await t.pumpWidget(
    RaftApp(
      key: old.key,
      services: AppServices.withUpdates(service),
      ownsAppUpdate: owns,
      sessionStore: old.sessionStore,
      initialArguments: old.initialArguments,
      initialLocation: old.initialLocation,
      createClient: old.createClient,
      openWorkspaceCache: old.openWorkspaceCache,
      nativeContent: old.nativeContent,
      nativeSharing: old.nativeSharing,
      nativeSessionOwner: old.nativeSessionOwner,
      onStartupReady: old.onStartupReady,
    ),
  );
}

void _expectRootDependency(WidgetTester t, AppUpdateService update) {
  expect(
    find.byType(AppServicesScope, skipOffstage: false),
    findsOneWidget,
    reason: 'workspace adapters must use the production root scope',
  );
  final bodies = find.byWidgetPredicate(
    (w) => w is WorkspaceView,
    skipOffstage: false,
  );
  expect(bodies, findsWidgets);
  for (final element in bodies.evaluate()) {
    expect(AppServicesScope.of(element).appUpdate, same(update));
  }
}

void main() {
  leakDebt(const ['ValueNotifier<bool>']);
  for (final width in [1280.0, 390.0]) {
    testWidgets(
      'root service reaches retained settings and replacement at $width',
      (t) async {
        final events = <String>[];
        final a = TrackedAppUpdate('a', events),
            b = TrackedAppUpdate('b', events);
        addTearDown(() {
          if (a.disposals == 0) a.dispose();
          if (b.disposals == 0) b.dispose();
        });
        final f = RootFixture();
        await f.mount(
          t,
          'light',
          width,
          uri: Uri.parse('/s/alpha'),
          appUpdate: a,
        );
        final rootState = t.state(find.byType(RaftApp));
        _expectRootDependency(t, a);
        // The fixture borrows by default; production explicitly transfers release
        // responsibility. Updating the root must keep the same app/session state.
        await _replaceServices(t, a, owns: true);
        await t.tap(
          find.byKey(
            Key(width < 768 ? 'mobile-tab-settings' : 'rail-settings'),
          ),
        );
        await f.flush(t);
        final settings = find.byType(WorkspaceSettings, skipOffstage: false);
        expect(settings, findsOneWidget);
        final settingsState = t.state(settings);
        expect(t.widget<WorkspaceSettings>(settings).appUpdate, same(a));
        final w = f.workspace(t);
        w.navigation.navigate(RaftLocation.parse('/s/alpha/channel/ca'));
        w.notifyListeners();
        await f.flush(t);
        expect(t.state(settings), same(settingsState));
        expect(a.listeners, isNotEmpty);

        await _replaceServices(t, b, owns: true);
        await f.flush(t);
        _expectRootDependency(t, b);
        expect(t.state(find.byType(RaftApp)), same(rootState));
        expect(t.state(settings), same(settingsState));
        expect(t.widget<WorkspaceSettings>(settings).appUpdate, same(b));
        expect(
          a.listeners,
          isEmpty,
          reason: 'even a covered Settings page must release the old service',
        );
        expect(a.disposals, 1);
        expect(events, contains('a:dispose:0'));
        expect(
          events.indexOf('a:remove'),
          lessThan(events.indexOf('a:dispose:0')),
        );

        final counts = <String, int>{};
        debugOnRebuildDirtyWidget = (element, _) => counts.update(
          '${element.widget.runtimeType}',
          (n) => n + 1,
          ifAbsent: () => 1,
        );
        try {
          b.publish();
          await t.pump();
        } finally {
          debugOnRebuildDirtyWidget = null;
        }
        for (final type in [
          'WorkspaceView',
          'RaftChatView',
          'RaftMessageTimeline',
          'RaftMessageTile',
          'RaftMessageRow',
        ]) {
          expect(
            counts[type] ?? 0,
            0,
            reason: 'service state widened notifications: $counts',
          );
        }
        w.navigation.navigate(RaftLocation.parse('/s/alpha/settings'));
        w.notifyListeners();
        await f.flush(t);
        expect(t.state(settings), same(settingsState));
        await t.tap(find.byKey(const ValueKey('workspace-settings-nav-about')));
        await f.flush(t);
        expect(
          find.byKey(const ValueKey('settings-about-update')),
          findsOneWidget,
        );
        await f.close(t);
        expect(b.listeners, isEmpty);
        expect([a.disposals, b.disposals], [1, 1]);
        expect(events, contains('b:dispose:0'));
      },
    );
  }

  testWidgets(
    'resize, width class and separating fold still rebuild the shell',
    (t) async {
      final update = TrackedAppUpdate('root', []);
      addTearDown(update.dispose);
      final f = RootFixture();
      await f.mount(
        t,
        'light',
        1280,
        uri: Uri.parse('/s/alpha/channel/ca'),
        appUpdate: update,
      );
      addTearDown(t.view.resetDisplayFeatures);
      final counts = <String, int>{};
      final report = <String>[];
      debugOnRebuildDirtyWidget = (element, _) => counts.update(
        '${element.widget.runtimeType}',
        (n) => n + 1,
        ifAbsent: () => 1,
      );
      try {
        for (final size in [
          const Size(1100, 900),
          const Size(390, 900),
          const Size(600, 900),
        ]) {
          counts.clear();
          t.view.physicalSize = size;
          await f.flush(t);
          expect(
            counts['WorkspaceView'] ?? 0,
            greaterThan(0),
            reason: 'required size layout did not rebuild: $size $counts',
          );
          _expectRootDependency(t, update);
          report.add('$size: $counts');
        }
        counts.clear();
        t.view.displayFeatures = const <ui.DisplayFeature>[
          ui.DisplayFeature(
            bounds: Rect.fromLTWH(0, 0, 12, 900),
            type: ui.DisplayFeatureType.hinge,
            state: ui.DisplayFeatureState.postureHalfOpened,
          ),
        ];
        await f.flush(t);
        expect(
          counts['WorkspaceView'] ?? 0,
          greaterThan(0),
          reason: 'separating fold did not update navigation: $counts',
        );
        _expectRootDependency(t, update);
        report.add('separating fold: $counts');
      } finally {
        debugOnRebuildDirtyWidget = null;
      }
      debugPrint(report.join('\n'));
      await f.close(t);
      expect(update.disposals, 0);
    },
  );
}
