import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:raft_flutter/platform/native_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Plugin implements FlutterLocalNotificationsPlugin {
  MacOSFlutterLocalNotificationsPlugin? mac;
  InitializationSettings? settings;
  @override
  T? resolvePlatformSpecificImplementation<
    T extends FlutterLocalNotificationsPlatform
  >() => mac as T?;
  @override
  Future<NotificationAppLaunchDetails?>
  getNotificationAppLaunchDetails() async =>
      const NotificationAppLaunchDetails(false);
  int cancellations = 0;
  final sent = <String?>[];
  final initialized = Completer<bool?>();
  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  }) {
    this.settings = settings;
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
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Mac extends MacOSFlutterLocalNotificationsPlugin {
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

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'macOS asks only on opt-in and stops delivery after OS revocation',
    () async {
      final mac = _Mac();
      final plugin = _Plugin()..mac = mac;
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
  test(
    'macOS denied permission stays disabled after a later OS grant',
    () async {
      final mac = _Mac()..prompt = (Completer<bool?>()..complete(false));
      final plugin = _Plugin()..mac = mac;
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
      expect(store.values.values.single, false);
      mac.allowed = true;
      await service.show(title: 'Raft', body: 'blocked', payload: 'denied');
      expect(service.permitted, true);
      expect(service.enabled, false);
      expect(plugin.sent, isEmpty);
    },
  );
  test('macOS late permission grant cannot undo a newer disable', () async {
    final mac = _Mac()..prompt = Completer<bool?>();
    final plugin = _Plugin()..mac = mac;
    plugin.initialized.complete(true);
    final service = NativeNotificationService(
      plugin: plugin,
      platform: TargetPlatform.macOS,
    );
    await service.bind('alice');
    final enabling = service.requestEnable(true);
    await Future<void>.delayed(Duration.zero);
    await service.requestEnable(false);
    mac.prompt!.complete(true);
    await enabling;
    expect(service.enabled, false);
    await service.refreshPermission();
    expect(service.enabled, false);
  });
  test('macOS late permission grant cannot enable a newer account', () async {
    final mac = _Mac()..prompt = Completer<bool?>();
    final plugin = _Plugin()..mac = mac;
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
    await service.show(title: 'Raft', body: 'blocked', payload: 'old-account');
    expect(service.enabled, false);
    expect(plugin.sent, isEmpty);
    expect(store.values, isEmpty);
    await service.bind('alice');
    expect(service.enabled, false);
  });
  test('opt-in defaults off; preferences are isolated and contain no raw coordinator/principal', () async {
    final plugin = _Plugin()..initialized.complete(true);
    final service = NativeNotificationService(
      plugin: plugin,
      platform: TargetPlatform.linux,
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
      final plugin = _Plugin();
      final service = NativeNotificationService(
        plugin: plugin,
        platform: TargetPlatform.linux,
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
        platform: TargetPlatform.linux,
        plugin: _Plugin()..initialized.complete(true),
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
        platform: TargetPlatform.linux,
        plugin: _Plugin()..initialized.complete(true),
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
      platform: TargetPlatform.linux,
      plugin: _Plugin()..initialized.complete(true),
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
