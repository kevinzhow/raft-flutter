import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:raft_flutter/platform/native_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationPluginFixture implements FlutterLocalNotificationsPlugin {
  MacOSFlutterLocalNotificationsPlugin? mac;
  IOSFlutterLocalNotificationsPlugin? ios;
  AndroidFlutterLocalNotificationsPlugin? android;
  LinuxFlutterLocalNotificationsPlugin? linux;
  InitializationSettings? settings;
  DidReceiveNotificationResponseCallback? onResponse;
  NotificationAppLaunchDetails launch = const NotificationAppLaunchDetails(
    false,
  );
  @override
  T? resolvePlatformSpecificImplementation<
    T extends FlutterLocalNotificationsPlatform
  >() =>
      (T == AndroidFlutterLocalNotificationsPlugin
              ? android
              : T == IOSFlutterLocalNotificationsPlugin
              ? ios
              : T == LinuxFlutterLocalNotificationsPlugin
              ? linux
              : mac)
          as T?;
  @override
  Future<NotificationAppLaunchDetails?>
  getNotificationAppLaunchDetails() async => launch;
  int cancellations = 0;
  final sent = <String?>[];
  final details = <NotificationDetails?>[];
  final ids = <int>[];
  final bodies = <String?>[];
  final initialized = Completer<bool?>();
  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  }) {
    this.settings = settings;
    onResponse = onDidReceiveNotificationResponse;
    return initialized.future;
  }

  @override
  Future<void> cancelAll() async {
    cancellations++;
    sent.clear();
  }

  @override
  Future<void> show({
    required int id,
    String? title,
    String? body,
    NotificationDetails? notificationDetails,
    String? payload,
  }) async {
    sent.add(payload);
    details.add(notificationDetails);
    ids.add(id);
    bodies.add(body);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Android extends AndroidFlutterLocalNotificationsPlugin {
  @override
  Future<bool?> areNotificationsEnabled() async => true;

  @override
  Future<bool?> requestNotificationsPermission() async => true;
}

class MacPermissionFixture extends MacOSFlutterLocalNotificationsPlugin {
  bool allowed = false;
  int requests = 0;
  Completer<bool?>? prompt;
  @override
  Future<bool?> requestPermissions({
    bool sound = false,
    bool alert = false,
    bool badge = false,
    bool provisional = false,
    bool critical = false,
    bool providesAppNotificationSettings = false,
  }) async {
    requests++;
    allowed = await (prompt?.future ?? Future.value(true)) ?? false;
    return allowed;
  }

  @override
  Future<NotificationsEnabledOptions?> checkPermissions() async =>
      NotificationsEnabledOptions(
        isEnabled: allowed,
        isSoundEnabled: allowed,
        isAlertEnabled: allowed,
        isBadgeEnabled: false,
        isProvisionalEnabled: false,
        isCriticalEnabled: false,
        isProvidesAppNotificationSettingsEnabled: false,
      );
}

class _IOS extends IOSFlutterLocalNotificationsPlugin {
  _IOS(this.permission);
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

(NativeNotificationService, NotificationPluginFixture, MacPermissionFixture)
deferredMacNotifications() {
  final mac = MacPermissionFixture();
  final plugin = NotificationPluginFixture()..mac = mac;
  plugin.initialized.complete(false);
  return (
    NativeNotificationService(plugin: plugin, platform: TargetPlatform.macOS),
    plugin,
    mac,
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final platform in [TargetPlatform.macOS, TargetPlatform.iOS]) {
    test(
      '$platform deferred permission does not mean plugin unavailable',
      () async {
        final permission = MacPermissionFixture();
        final plugin = NotificationPluginFixture()
          ..mac = permission
          ..ios = _IOS(permission);
        plugin.initialized.complete(false);
        final service = NativeNotificationService(
          plugin: plugin,
          platform: platform,
        );
        addTearDown(service.dispose);
        await service.bind('alice');
        expect(service.initialized, true);
        expect(service.available, true);
        expect(service.permitted, false);
        expect(permission.requests, 0);
        await service.requestEnable(true);
        await service.show(title: 'Raft', body: 'new DM', payload: 'target');
        expect(service.enabled, true);
        expect(plugin.sent, ['target']);
      },
    );
    test(
      '$platform missing native implementation remains unavailable',
      () async {
        final plugin = NotificationPluginFixture();
        plugin.initialized.complete(null);
        final service = NativeNotificationService(
          plugin: plugin,
          platform: platform,
        );
        addTearDown(service.dispose);
        await service.initialize();
        expect(service.available, false);
        expect(await service.test(), false);
        expect(plugin.sent, isEmpty);
      },
    );
  }
  test('Android message and test notifications deliver with the monochrome Raft drawable', () async {
    final plugin = NotificationPluginFixture()..android = _Android();
    plugin.initialized.complete(true);
    final service = NativeNotificationService(
      plugin: plugin,
      platform: TargetPlatform.android,
    );
    addTearDown(service.dispose);
    await service.bind('alice');
    expect(plugin.settings!.android!.defaultIcon, 'ic_notification');
    await service.requestEnable(true);
    await service.show(title: 'Raft', body: 'message', payload: 'target');
    expect(await service.test(), true);
    expect(plugin.sent, ['target', 'raft-notification-test']);
    expect(plugin.details, hasLength(2));
    for (final details in plugin.details) {
      expect(details!.android!.icon, 'ic_notification');
    }
  });
  test(
    'macOS asks only on opt-in and stops delivery after OS revocation',
    () async {
      final mac = MacPermissionFixture();
      final plugin = NotificationPluginFixture()..mac = mac;
      plugin.initialized.complete(true);
      final service = NativeNotificationService(
        plugin: plugin,
        platform: TargetPlatform.macOS,
      );
      await service.bind('alice');
      expect(mac.requests, 0);
      expect(plugin.settings!.macOS!.requestAlertPermission, false);
      expect(plugin.settings!.macOS!.requestSoundPermission, false);
      expect(plugin.settings!.macOS!.requestBadgePermission, false);
      expect(service.enabled, false);
      await service.requestEnable(true);
      expect(mac.requests, 1);
      expect(service.enabled, true);
      await service.show(title: 'Raft', body: 'test', payload: 'target');
      expect(plugin.sent, ['target']);
      mac.allowed = false;
      await service.show(title: 'Raft', body: 'blocked', payload: 'revoked');
      expect(service.enabled, false);
      expect(plugin.sent, ['target']);
      mac.allowed = true;
      await service.refreshPermission();
      expect(service.enabled, true);
      expect(mac.requests, 1);
    },
  );
  test('queued background alert rechecks foreground at the OS send', () async {
    final (service, plugin, mac) = deferredMacNotifications();
    mac.allowed = true;
    await service.bind('origin/alice/s');
    var background = true;
    service.deliveryAllowed = () => background;
    final pending = service.show(
      title: 'Raft',
      body: 'message',
      payload: 'queued',
    );
    background = false;
    await pending;
    expect(plugin.sent, isEmpty);
    background = true;
    await service.show(title: 'Raft', body: 'message', payload: 'background');
    expect(plugin.sent, ['background']);
    background = false;
    expect(await service.test(), true);
    expect(plugin.sent, ['background', 'raft-notification-test']);
    service.dispose();
  });

  test('macOS test requests OS permission and enables real delivery; denial posts nothing', () async {
    final mac = MacPermissionFixture();
    final plugin = NotificationPluginFixture()..mac = mac;
    plugin.initialized.complete(true);
    final service = NativeNotificationService(
      plugin: plugin,
      platform: TargetPlatform.macOS,
    );
    await service.bind('alice');
    expect(service.enabled, false);
    mac.prompt = Completer<bool?>()..complete(false);
    expect(await service.test(title: 'Raft Desktop', body: 'x'), false);
    expect(plugin.sent, isEmpty);
    mac.prompt = null;
    expect(await service.test(title: 'Raft Desktop', body: 'x'), true);
    expect(plugin.sent, ['raft-notification-test']);
    expect(service.enabled, true);
  });
  test(
    'a refusal with no time for a prompt means the system stopped asking',
    () async {
      final mac = MacPermissionFixture();
      final plugin = NotificationPluginFixture()..mac = mac;
      plugin.initialized.complete(true);
      final service = NativeNotificationService(
        plugin: plugin,
        platform: TargetPlatform.macOS,
      );
      await service.bind('alice');
      mac.prompt = Completer<bool?>()..complete(false);
      await service.requestEnable(true);
      expect(service.permissionPromptSkipped, true);
      final slow = Completer<bool?>();
      mac.prompt = slow;
      final pending = service.requestEnable(true);
      await Future<void>.delayed(const Duration(milliseconds: 450));
      slow.complete(false);
      await pending;
      expect(service.permissionPromptSkipped, false);
      mac.prompt = null;
      await service.requestEnable(true);
      expect(service.enabled, true);
      expect(service.permissionPromptSkipped, false);
    },
  );
  test('macOS follows a later OS grant without a mobile opt-in', () async {
    final mac = MacPermissionFixture()
      ..prompt = (Completer<bool?>()..complete(false));
    final plugin = NotificationPluginFixture()..mac = mac;
    final store = _Store();
    plugin.initialized.complete(true);
    final service = NativeNotificationService(
      plugin: plugin,
      platform: TargetPlatform.macOS,
      preferences: store,
    );
    await service.bind('alice');
    await service.requestEnable(true);
    expect(service.enabled, false);
    expect(service.permitted, false);
    expect(service.error, contains('system settings'));
    expect(store.values, {
      'raft.notifications.initial-permission.macOS.v1': true,
    });
    mac.allowed = true;
    await service.show(title: 'Raft', body: 'blocked', payload: 'denied');
    expect(service.permitted, true);
    expect(service.enabled, true);
    expect(plugin.sent, ['denied']);
  });
  test('macOS ignores stale app opt-in and follows the OS switch', () async {
    final mac = MacPermissionFixture()..allowed = true;
    final plugin = NotificationPluginFixture()..mac = mac;
    final store = _Store()..failRead = true;
    plugin.initialized.complete(false);
    final service = NativeNotificationService(
      plugin: plugin,
      preferences: store,
      platform: TargetPlatform.macOS,
    );
    addTearDown(service.dispose);
    await service.bind('alice');
    expect(service.enabled, true);
    expect(service.error, isNull);
    expect(store.writes, 0);
    await service.bind(null);
    expect(service.enabled, false);
  });
  test('macOS late permission grant cannot enable a newer account', () async {
    final mac = MacPermissionFixture()..prompt = Completer<bool?>();
    final plugin = NotificationPluginFixture()..mac = mac;
    final store = _Store();
    plugin.initialized.complete(true);
    final service = NativeNotificationService(
      plugin: plugin,
      platform: TargetPlatform.macOS,
      preferences: store,
    );
    await service.bind('alice');
    final enabling = service.requestEnable(true);
    await Future<void>.delayed(Duration.zero);
    await service.bind('bob');
    mac.prompt!.complete(true);
    await enabling;
    expect(service.enabled, false);
    expect(plugin.sent, isEmpty);
    expect(store.values, {
      'raft.notifications.initial-permission.macOS.v1': true,
    });
    await service.refreshPermission();
    expect(service.enabled, true);
    await service.bind('alice');
    expect(service.enabled, true);
  });
  test('opt-in defaults off; preferences are isolated and contain no raw coordinator/principal', () async {
    final plugin = NotificationPluginFixture()..initialized.complete(true);
    final service = NativeNotificationService(
      plugin: plugin,
      platform: TargetPlatform.fuchsia,
    );
    await service.bind('https://example.test\nalice\nserver-a');
    expect(service.enabled, false);
    await service.requestEnable(true);
    expect(service.enabled, true);
    await service.show(
      title: 'Raft',
      body: 'Private preview',
      payload: 'bound-target',
    );
    expect(plugin.sent, ['bound-target']);
    await service.bind('https://example.test\nbob\nserver-a');
    expect(service.enabled, false);
    expect(plugin.sent, isEmpty);
    await service.bind('https://example.test\nalice\nserver-b');
    expect(service.enabled, false);
    await service.bind('https://example.test\nalice\nserver-a');
    expect(service.enabled, true);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys().single, startsWith('raft.notifications.'));
    expect(prefs.getKeys().single, isNot(contains('alice')));
    expect(prefs.getKeys().single, isNot(contains('example.test')));
    await service.bind(null);
    expect(service.enabled, false);
    expect(plugin.sent, isEmpty);
  });
  test(
    'queued alert after scope changes cannot survive initialization',
    () async {
      final plugin = NotificationPluginFixture();
      final service = NativeNotificationService(
        plugin: plugin,
        platform: TargetPlatform.fuchsia,
      );
      final first = service.bind('alice');
      service.enabled = true;
      service.permitted = true;
      service.available = true;
      final alert = service.show(
        title: 'Raft',
        body: 'private',
        payload: 'old-alice',
      );
      final changed = service.bind('bob');
      plugin.initialized.complete(true);
      await Future.wait([first, alert, changed]);
      expect(plugin.sent, isEmpty);
      expect(service.enabled, false);
    },
  );
  test(
    'restart restores only same principal; failed storage stays disabled',
    () async {
      final store = _Store();
      NativeNotificationService make() => NativeNotificationService(
        platform: TargetPlatform.fuchsia,
        plugin: NotificationPluginFixture()..initialized.complete(true),
        preferences: store,
      );
      final first = make();
      await first.bind('api\nalice\nserver');
      await first.requestEnable(true);
      final restarted = make();
      await restarted.bind('api\nalice\nserver');
      expect(restarted.enabled, true);
      await restarted.bind('api\nbob\nserver');
      expect(restarted.enabled, false);
      store.failWrite = true;
      await restarted.requestEnable(true);
      expect(restarted.enabled, false);
      expect(restarted.error, contains('saved'));
      store.failRead = true;
      await restarted.bind('api\ncarol\nserver');
      expect(restarted.enabled, false);
      expect(restarted.error, contains('loaded'));
    },
  );
  test(
    'latest disable is immediate and persists after slow previous write',
    () async {
      final store = _Store();
      final service = NativeNotificationService(
        platform: TargetPlatform.fuchsia,
        plugin: NotificationPluginFixture()..initialized.complete(true),
        preferences: store,
      );
      await service.bind('alice');
      store.delayedWrite = Completer<bool>();
      final enable = service.requestEnable(true);
      await Future<void>.delayed(Duration.zero);
      expect(store.writes, 1);
      final disable = service.requestEnable(false);
      expect(service.enabled, false);
      store.delayedWrite!.complete(true);
      await Future.wait([enable, disable]);
      expect(service.enabled, false);
      expect(store.values.values.single, false);
    },
  );
  test('stale cached read cannot replace a newer user preference', () async {
    final store = _Store()..delayedRead = Completer<bool?>();
    final service = NativeNotificationService(
      platform: TargetPlatform.fuchsia,
      plugin: NotificationPluginFixture()..initialized.complete(true),
      preferences: store,
    );
    final binding = service.bind('alice');
    await Future<void>.delayed(Duration.zero);
    await service.requestEnable(false);
    store.delayedRead!.complete(true);
    await binding;
    expect(service.enabled, false);
    expect(store.values.values.single, false);
  });
}

class _Store extends NotificationPreferenceStore {
  final values = <String, bool>{};
  Completer<bool?>? delayedRead;
  Completer<bool>? delayedWrite;
  bool failWrite = false, failRead = false;
  int writes = 0;
  @override
  Future<bool?> read(String key) async {
    if (failRead) throw StateError('unavailable');
    return delayedRead == null ? values[key] : delayedRead!.future;
  }

  @override
  Future<bool> write(String key, bool value) async {
    writes++;
    if (delayedWrite != null) await delayedWrite!.future;
    if (failWrite) return false;
    values[key] = value;
    return true;
  }
}
