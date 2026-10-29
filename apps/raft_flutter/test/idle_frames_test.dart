import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/personal_presentation.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/features/workspace_view.dart';
import 'package:raft_flutter/platform/native_notifications.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'flutter_test_config.dart' show leakDebt;

import '../integration_test/desktop_screens_test.dart'
    show DesktopFixtureClient;
import 'support/app_services_fixture.dart';

/// Idle-frame guard. Once a screen has loaded and its transitions finished,
/// nothing may keep asking for frames: no scheduled frame, no running ticker,
/// even after every poll and expiry timer in the app has had time to fire.
/// `tool/idle-cpu/run.sh` measures the same property on a real profile build;
/// this keeps it from regressing in CI.
///
/// A focused text field blinks its caret on purpose, so the search overlay and
/// the thread composer are not part of this list.
void main() {
  // Leak debt (other): see docs/development.md, Leak tracking.
  leakDebt(const ['PersonalPresentationStore']);
  final fixtureText = File('../../tool/desktop-parity/desktop-fixture.json')
      .readAsStringSync();

  Future<(WorkspaceController, DesktopFixtureClient)> boot(
    WidgetTester t,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await t.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final client = DesktopFixtureClient(
      jsonDecode(fixtureText) as Map<String, dynamic>,
    );
    final w = WorkspaceController(client);
    addTearDown(w.dispose);
    // This fixture creates the app-level service; WorkspaceView only borrows
    // it. Unmount consumers before releasing the fixture-owned notifier.
    final notifications = NativeNotificationService();
    addTearDown(() async {
      await t.pumpWidget(const SizedBox());
      notifications.dispose();
    });
    await t.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('en'),
        supportedLocales: const [Locale('en'), Locale('zh', 'CN')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: raftTheme(),
        builder: (context, child) => RaftTooltipProvider(
          delay: const Duration(milliseconds: 600),
          child: child!,
        ),
        home: withAppServices(
          WorkspaceView(
            controller: w,
            presentation: PersonalPresentationStore(desktop: false),
            appearance: const RaftAppearance(mode: ThemeMode.light),
            onAppearance: (_) async {},
            onLogout: () async {},
            notifications: notifications,
          ),
        ),
      ),
    );
    unawaited(w.bootstrap());
    for (var i = 0; i < 200; i++) {
      await t.pump(const Duration(milliseconds: 50));
      if (find
          .byKey(const ValueKey('message-msg-agent-reply'))
          .evaluate()
          .isNotEmpty) {
        break;
      }
    }
    expect(
      find.byKey(const ValueKey('message-msg-agent-reply')),
      findsOneWidget,
    );
    return (w, client);
  }

  Future<void> tapKey(WidgetTester t, Key key) async {
    for (var i = 0; i < 100 && find.byKey(key).evaluate().isEmpty; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    await t.tap(find.byKey(key).first, warnIfMissed: false);
    await t.pump(const Duration(milliseconds: 50));
  }

  /// Settles, then lets every poll/debounce/expiry timer fire for two
  /// minutes of app time. The only wake-ups allowed are the data polls: the
  /// notification bell refreshes once a minute (two in this window) and an
  /// agent activity item expires once ([allowed]). Each wake-up must settle,
  /// and no ticker may keep running between them.
  Future<void> expectQuiet(
    WidgetTester t,
    String what, {
    int allowed = 2,
  }) async {
    await t.pumpAndSettle(const Duration(milliseconds: 100));
    var wakeups = 0;
    for (var s = 0; s < 24; s++) {
      await t.pump(const Duration(seconds: 5));
      if (t.binding.hasScheduledFrame) {
        wakeups++;
        await t.pumpAndSettle(const Duration(milliseconds: 100));
      }
      expect(
        t.binding.transientCallbackCount,
        0,
        reason: '$what keeps a ticker running at ${(s + 1) * 5}s of idle',
      );
    }
    expect(
      wakeups,
      lessThanOrEqualTo(allowed),
      reason: '$what asked for frames on $wakeups of 24 idle intervals',
    );
  }

  final screens = <String, Future<void> Function(WidgetTester)>{
    'channel': (t) async {},
    'activity': (t) => tapKey(t, const ValueKey('rail-activity')),
    'tasks': (t) => tapKey(t, const ValueKey('rail-tasks')),
    'members': (t) => tapKey(t, const ValueKey('rail-members')),
    'computers': (t) => tapKey(t, const ValueKey('rail-computers')),
    'settings': (t) async {
      await tapKey(t, const Key('rail-settings'));
      await tapKey(t, const ValueKey('workspace-settings-nav-appearance'));
    },
  };

  for (final entry in screens.entries) {
    testWidgets('${entry.key} schedules no frames while idle', (t) async {
      await boot(t);
      await entry.value(t);
      await expectQuiet(t, entry.key);
    });
  }

  testWidgets('a working-agents summary adds no frames', (t) async {
    final (w, client) = await boot(t);
    client.stream.add(
      RaftEvent('agent:activity', {
        'agentId': 'agent-cindy',
        'serverId': w.server?.id,
        'activity': 'working',
        'detail': 'Running tests',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      }),
    );
    await t.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('working-agents-summary')), findsOneWidget);
    // One more wake-up: the 90 s safety expiry removes the agent.
    await expectQuiet(t, 'working agents summary', allowed: 3);
  });

  testWidgets('a hidden or paused app does no frame or timer work', (t) async {
    final (_, client) = await boot(t);
    await t.pumpAndSettle(const Duration(milliseconds: 100));
    final served = client.served.length;
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    // 10 minutes: every periodic poll in the app would fire several times.
    for (var s = 0; s < 120; s++) {
      await t.pump(const Duration(seconds: 5));
      expect(t.binding.hasScheduledFrame, isFalse);
    }
    expect(
      client.served.skip(served),
      isEmpty,
      reason: 'Polls (notification bell, setup gate) stop while hidden',
    );
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pumpAndSettle(const Duration(milliseconds: 100));
    // Visible again: the bell polls once a minute.
    await t.pump(const Duration(seconds: 61));
    expect(
      client.served.skip(served).where((r) => r.contains('product-feedback')),
      isNotEmpty,
    );
  });
}
