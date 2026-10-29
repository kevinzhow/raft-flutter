import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/android_permissions.dart';
import 'package:raft_flutter/platform/native_notifications.dart';
import 'package:raft_flutter/platform/background_inbox.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'native_notifications_test.dart'
    show MacPermissionFixture, NotificationPluginFixture;
import 'notification_settings_view_test.dart' show Service, fixture, host, card;

class IOSPermission extends IOSFlutterLocalNotificationsPlugin {
  IOSPermission(this.permission);
  final MacPermissionFixture permission;
  @override
  Future<NotificationsEnabledOptions?> checkPermissions() =>
      permission.checkPermissions();
  @override
  Future<bool?> requestPermissions({
    bool sound = false,
    bool alert = false,
    bool badge = false,
    bool provisional = false,
    bool critical = false,
    bool carPlay = false,
    bool providesAppNotificationSettings = false,
  }) => permission.requestPermissions(sound: sound, alert: alert, badge: badge);
}

/// The unit tests have no `app.raft/permissions` bridge: "unknown" answers at
/// once, so the service asks as it did before the bridge existed.
class NoPermissionBridge extends AndroidPermissions {
  const NoPermissionBridge();
  @override
  Future<AndroidPermissionStatus?> status(String permission) async => null;
}

class AndroidPermission extends AndroidFlutterLocalNotificationsPlugin {
  AndroidPermission(this.permission);
  final MacPermissionFixture permission;
  @override
  Future<bool?> areNotificationsEnabled() async => permission.allowed;
  @override
  Future<bool?> requestNotificationsPermission() =>
      permission.requestPermissions();
}

void mobilePermissionTests(TargetPlatform platform) {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  (NativeNotificationService, NotificationPluginFixture) make(
    MacPermissionFixture permission,
  ) {
    final plugin = NotificationPluginFixture()
      ..ios = IOSPermission(permission)
      ..android = AndroidPermission(permission);
    plugin.initialized.complete(platform == TargetPlatform.android);
    final service = NativeNotificationService(
      plugin: plugin,
      platform: platform,
      androidPermissions: const NoPermissionBridge(),
    );
    addTearDown(service.dispose);
    return (service, plugin);
  }

  test(
    '$platform requests only after explicit enable, never on workspace entry',
    () async {
      final permission = MacPermissionFixture();
      final (s, _) = make(permission);
      await s.initialize();
      await s.bindAuthenticatedWorkspace(null);
      expect(permission.requests, 0);
      await s.bindAuthenticatedWorkspace('alice');
      expect(permission.requests, 0);
      await s.requestEnable(true);
      expect(permission.requests, 1);
      expect(s.enabled, isTrue);
      await s.bindAuthenticatedWorkspace('alice');
      expect(permission.requests, 1);
    },
  );
  test(
    '$platform denial persists but a later system grant enables delivery and survives restart',
    () async {
      final permission = MacPermissionFixture()
        ..prompt = (Completer<bool?>()..complete(false));
      final (s, _) = make(permission);
      await s.bindAuthenticatedWorkspace('alice');
      expect(permission.requests, 0);
      await s.requestEnable(true);
      expect(permission.requests, 1);
      expect(s.enabled, isFalse);
      await s.bindAuthenticatedWorkspace(null);
      final (reopened, plugin) = make(permission);
      await reopened.bindAuthenticatedWorkspace('alice');
      expect(permission.requests, 1);
      expect(reopened.enabled, isFalse);
      permission.allowed = true;
      await reopened.refreshPermission();
      expect(reopened.enabled, isTrue);
      await reopened.show(
        title: 'Synthetic',
        body: 'new message',
        payload: 'target',
      );
      expect(plugin.sent, ['target']);
      final (again, _) = make(permission);
      await again.bindAuthenticatedWorkspace('alice');
      expect(again.enabled, isTrue);
      expect(permission.requests, 1);
    },
  );
  test(
    '$platform device grant works for a new account without a second prompt',
    () async {
      final permission = MacPermissionFixture();
      final (s, _) = make(permission);
      await s.bindAuthenticatedWorkspace('alice');
      await s.requestEnable(true);
      await s.bindAuthenticatedWorkspace('bob');
      expect(permission.requests, 1);
      expect(s.enabled, isTrue);
      await s.requestEnable(false);
      await s.bindAuthenticatedWorkspace(null);
      await s.bindAuthenticatedWorkspace('bob');
      expect(
        s.enabled,
        isFalse,
        reason: 'An explicit local disable is preserved.',
      );
      expect(permission.requests, 1);
    },
  );
  test(
    '$platform late permission result after logout cannot enable delivery',
    () async {
      final permission = MacPermissionFixture()..prompt = Completer<bool?>();
      final (s, _) = make(permission);
      await s.bindAuthenticatedWorkspace('alice');
      final entering = s.requestEnable(true);
      await Future<void>.delayed(Duration.zero);
      expect(permission.requests, 1);
      await s.bindAuthenticatedWorkspace(null);
      permission.prompt!.complete(true);
      await entering;
      expect(s.enabled, isFalse);
      await s.bindAuthenticatedWorkspace('alice');
      expect(s.enabled, isTrue);
      expect(permission.requests, 1);
    },
  );
  test(
    '$platform upgrading previous preference data asks once and preserves unrelated data',
    () async {
      SharedPreferences.setMockInitialValues({
        notificationPreferenceKey('alice'): false,
        'fixture-draft': 'keep me',
      });
      final permission = MacPermissionFixture();
      final (s, _) = make(permission);
      await s.bindAuthenticatedWorkspace('alice');
      expect(permission.requests, 0);
      await s.requestEnable(true);
      expect(permission.requests, 1);
      expect(s.enabled, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('fixture-draft'), 'keep me');
      expect(prefs.getBool(notificationPreferenceKey('alice')), isTrue);
    },
  );
  testWidgets(
    '$platform denied status has an explicit system-settings action and clears after grant',
    (t) async {
      final (w, _, unused) = (await t.runAsync(fixture))!;
      final s = Service(platform: platform)..initialized = true;
      addTearDown(w.dispose);
      addTearDown(unused.dispose);
      addTearDown(s.dispose);
      addTearDown(() async {
        await t.pumpWidget(const SizedBox());
        await t.pumpAndSettle();
      });
      await t.pumpWidget(host(w, s, locale: const Locale('zh')));
      await t.pumpAndSettle();
      expect(card(t).status, 'Off in system settings');
      expect(find.text('系统里没开'), findsOneWidget);
      final button = find.text('打开通知设置');
      expect(button, findsOneWidget);
      await t.ensureVisible(button);
      await t.tap(button);
      await t.pumpAndSettle();
      expect(s.settings, 1);
      expect(s.enables, 0);
      await s.requestEnable(true);
      await t.pumpAndSettle();
      expect(card(t).status, '已开启');
      expect(find.text('系统里没开'), findsNothing);
      expect(card(t).error, isNull);
    },
  );
}
