import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/native_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Plugin implements FlutterLocalNotificationsPlugin {
  int cancellations = 0;
  final sent = <String?>[];
  final initialized = Completer<bool?>();
  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  }) => initialized.future;
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

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('opt-in defaults off; preferences are isolated and contain no raw coordinator/principal', () async {
    final plugin = _Plugin()..initialized.complete(true);
    final service = NativeNotificationService(plugin: plugin);
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
      final service = NativeNotificationService(plugin: plugin);
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
