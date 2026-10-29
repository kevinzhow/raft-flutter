import 'dart:async';
import 'dart:ui' show ViewFocusEvent, ViewFocusState, ViewFocusDirection;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/notification_activation_banner.dart';
import 'package:raft_flutter/platform/native_notifications.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'native_notifications_test.dart'
    show
        deferredMacNotifications,
        MacPermissionFixture,
        NotificationPluginFixture;
import 'notification_first_workspace_test.dart' show turn;
import 'workspace_source_location_contract_test.dart' show pageFixture;

Widget host(
  Widget child,
  NativeNotificationService s, {
  bool dark = false,
  bool mobile = false,
  bool chinese = false,
}) => MaterialApp(
  locale: chinese ? const Locale('zh') : const Locale('en'),
  supportedLocales: const [Locale('zh'), Locale('en')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  theme: raftTheme(dark: dark),
  home: Scaffold(
    body: RaftDensityScope(
      density: mobile ? RaftDensity.touch : RaftDensity.desktop,
      child: NotificationActivationHost(service: s, child: child),
    ),
  ),
);

class _ObservedNotifications extends NativeNotificationService {
  _ObservedNotifications()
    : super(plugin: _plugin(), platform: TargetPlatform.macOS);

  bool get hasConsumers => hasListeners;

  static NotificationPluginFixture _plugin() {
    final plugin = NotificationPluginFixture()..mac = MacPermissionFixture();
    plugin.initialized.complete(false);
    return plugin;
  }
}

void main() {
  testWidgets(
    'activation consumers release borrowed services on swap and unmount',
    (t) async {
      SharedPreferences.setMockInitialValues({});
      final first = _ObservedNotifications();
      final second = _ObservedNotifications();
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      await first.bindAuthenticatedWorkspace('alice');
      await second.bindAuthenticatedWorkspace('alice');
      Widget tree(NativeNotificationService service) => host(
        NotificationActivationBanner(service: service, onSettings: () {}),
        service,
      );
      await t.pumpWidget(tree(first));
      await turn(t);
      expect(first.hasConsumers, isTrue);
      expect(second.hasConsumers, isFalse);
      await t.pumpWidget(tree(second));
      await turn(t);
      expect(first.hasConsumers, isFalse);
      expect(second.hasConsumers, isTrue);
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
      expect(first.hasConsumers, isFalse);
      expect(second.hasConsumers, isFalse);
      // Pages must leave borrowed app-session services usable by the next page.
      for (final service in [first, second]) {
        var notifications = 0;
        void observe() => notifications++;
        service.addListener(observe);
        service.dismissActivation();
        expect(notifications, 1);
        service.removeListener(observe);
      }
      expect(t.binding.hasScheduledFrame, isFalse);
      expect(t.binding.transientCallbackCount, 0);
    },
  );
  for (final (dark) in [(false), (true)]) {
    for (final (mobile, chinese) in [
      (false, false),
      (true, false),
      (true, true),
    ]) {
      testWidgets(
        'actual composer explicit opt-in survives restart ${dark ? 'dark' : 'light'}/$mobile/$chinese',
        (t) async {
          t.view.physicalSize = Size(mobile ? 390 : 1440, 1000);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          final (w, _) = await pageFixture(t, section: 'chat');
          final (s, _, p) = deferredMacNotifications();
          addTearDown(s.dispose);
          await s.bindAuthenticatedWorkspace('alice');
          expect(p.requests, 0);
          await t.pumpWidget(
            host(
              RaftChatView(controller: w),
              s,
              dark: dark,
              mobile: mobile,
              chinese: chinese,
            ),
          );
          await turn(t);
          final banner = find.byKey(
            const ValueKey('notification-activation-banner'),
          );
          expect(banner, findsOneWidget);
          expect(
            find.text(
              chinese
                  ? '离开后，Agent 仍会继续工作。'
                  : mobile
                  ? 'Agents keep working after you leave.'
                  : 'Your agents keep working after you leave.',
            ),
            findsOneWidget,
          );
          final enable = find.text(chinese ? '开启通知' : 'Enable Notifications');
          await t.ensureVisible(enable);
          await t.tap(enable);
          await turn(t);
          expect(p.requests, 1);
          expect(s.enabled, isTrue);
          expect(banner, findsNothing);
          await t.pumpWidget(const SizedBox());
          await turn(t);
          final (reopened, _, permission) = deferredMacNotifications();
          addTearDown(reopened.dispose);
          await reopened.bindAuthenticatedWorkspace('alice');
          await t.pumpWidget(
            host(
              RaftChatView(controller: w),
              reopened,
              dark: dark,
              mobile: mobile,
            ),
          );
          await turn(t);
          expect(banner, findsNothing);
          expect(permission.requests, 0);
          await t.pumpWidget(const SizedBox());
          await t.pumpAndSettle();
        },
      );
    }
  }
  testWidgets(
    'dismiss confirms for exactly three seconds, settings link works, remount stays dismissed',
    (t) async {
      final (w, _) = await pageFixture(t, section: 'chat');
      final (s, _, p) = deferredMacNotifications();
      addTearDown(s.dispose);
      await s.bindAuthenticatedWorkspace('alice');
      Widget child() => NotificationActivationComposer(
        controller: w,
        thread: false,
        child: const Text('actual composer'),
      );
      await t.pumpWidget(host(child(), s));
      await turn(t);
      await t.tap(find.byType(RaftCloseButton));
      await t.pump();
      expect(
        find.textContaining(
          'Hidden for now — turn on anytime in',
          findRichText: true,
        ),
        findsOneWidget,
      );
      await t.pump(const Duration(milliseconds: 2999));
      expect(
        find.textContaining('Settings › Notifications', findRichText: true),
        findsOneWidget,
      );
      await t.tap(
        find.textContaining('Settings › Notifications', findRichText: true),
      );
      expect(w.section, 'settings');
      expect(w.location.settingsPath, ['notifications']);
      await t.pump(const Duration(milliseconds: 1));
      expect(
        find.textContaining('Settings › Notifications', findRichText: true),
        findsNothing,
      );
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(host(child(), s));
      await turn(t);
      expect(find.byType(RaftBanner), findsNothing);
      expect(p.requests, 0);
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
    },
  );
  testWidgets(
    'denial removes banner across restart, focus and resume reconcile external grant without prompting',
    (t) async {
      final (w, _) = await pageFixture(t);
      final (s, _, p) = deferredMacNotifications();
      addTearDown(s.dispose);
      p.prompt = Completer<bool?>()..complete(false);
      await s.bindAuthenticatedWorkspace('alice');
      Widget child() => NotificationActivationComposer(
        controller: w,
        thread: false,
        child: const SizedBox(),
      );
      await t.pumpWidget(host(child(), s));
      await turn(t);
      await t.tap(find.text('Enable Notifications'));
      await turn(t);
      expect(p.requests, 1);
      expect(s.permitted, isFalse);
      expect(find.byType(RaftBanner), findsNothing);
      await t.pumpWidget(const SizedBox());
      final (next, _, permission) = deferredMacNotifications();
      addTearDown(next.dispose);
      await next.bindAuthenticatedWorkspace('alice');
      await t.pumpWidget(host(child(), next));
      await turn(t);
      expect(find.byType(RaftBanner), findsNothing);
      permission.allowed = true;
      t.binding.handleViewFocusChanged(
        const ViewFocusEvent(
          viewId: 0,
          state: ViewFocusState.focused,
          direction: ViewFocusDirection.undefined,
        ),
      );
      await turn(t);
      expect(next.enabled, isTrue);
      expect(permission.requests, 0);
      permission.allowed = false;
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await turn(t);
      expect(next.enabled, isFalse);
      expect(permission.requests, 0);
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
    },
  );
  testWidgets(
    'eligible joined channel and DM only; threads, read-only, archived and unjoined excluded',
    (t) async {
      final (w, _) = await pageFixture(t);
      final (s, _, _) = deferredMacNotifications();
      addTearDown(s.dispose);
      await s.bindAuthenticatedWorkspace('alice');
      for (final (json, thread, visible)
          in <(Map<String, dynamic>, bool, bool)>[
            ({'joined': true}, false, true),
            ({'type': 'dm'}, false, true),
            ({'joined': true}, true, false),
            ({'joined': true, 'type': 'thread'}, false, false),
            ({'joined': true, 'archivedAt': '2026-01-01'}, false, false),
            ({'joined': false}, false, false),
            ({'joined': true, 'readOnlyReason': 'quota'}, false, false),
            (
              {'joined': true, 'type': 'joint', 'jointBillingLocked': true},
              false,
              false,
            ),
          ]) {
        w.channel = RaftChannel({'id': 'c1', 'name': 'test', ...json});
        await t.pumpWidget(
          host(
            NotificationActivationComposer(
              controller: w,
              thread: thread,
              child: const SizedBox(),
            ),
            s,
          ),
        );
        await turn(t);
        expect(
          find.byType(RaftBanner),
          visible ? findsOneWidget : findsNothing,
          reason: '$json/$thread',
        );
      }
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
    },
  );
  testWidgets(
    'pending request disables the action and single-flights repeated taps',
    (t) async {
      final (w, _) = await pageFixture(t);
      final (s, _, p) = deferredMacNotifications();
      addTearDown(s.dispose);
      p.prompt = Completer<bool?>();
      await s.bindAuthenticatedWorkspace('alice');
      await t.pumpWidget(
        host(
          NotificationActivationComposer(
            controller: w,
            thread: false,
            child: const SizedBox(),
          ),
          s,
        ),
      );
      await turn(t);
      await t.tap(find.text('Enable Notifications'));
      await turn(t);
      expect(find.text('Enabling…'), findsOneWidget);
      expect(p.requests, 1);
      final button = t.widget<RaftButton>(
        find.widgetWithText(RaftButton, 'Enabling…'),
      );
      expect(button.onPressed, isNull);
      p.prompt!.complete(false);
      await turn(t);
      expect(find.byType(RaftBanner), findsNothing);
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
    },
  );
  test('Windows and Linux have no native permission activation prompt', () {
    for (final platform in [TargetPlatform.windows, TargetPlatform.linux]) {
      final s = NativeNotificationService(platform: platform);
      expect(s.hasPermissionPrompt, isFalse);
      expect(s.showActivation, isFalse);
      s.dispose();
    }
  });
  testWidgets(
    'previous release preference upgrades without prompt or data loss',
    (t) async {
      final (w, _) = await pageFixture(t);
      SharedPreferences.setMockInitialValues({
        'fixture-draft': 'keep',
        'raft.notifications.initial-permission.macOS.v1': true,
      });
      final (s, _, p) = deferredMacNotifications();
      addTearDown(s.dispose);
      await s.bindAuthenticatedWorkspace('alice');
      await t.pumpWidget(
        host(
          NotificationActivationComposer(
            controller: w,
            thread: false,
            child: const SizedBox(),
          ),
          s,
        ),
      );
      await turn(t);
      expect(find.byType(RaftBanner), findsNothing);
      expect(p.requests, 0);
      expect(
        (await SharedPreferences.getInstance()).getString('fixture-draft'),
        'keep',
      );
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
    },
  );
}
