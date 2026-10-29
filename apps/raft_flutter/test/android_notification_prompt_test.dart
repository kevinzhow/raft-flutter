// Android notification permission: when the system will no longer show a
// prompt (found on an API 34 emulator: the denial after "don't ask again"
// takes ~535 ms, so the old 400 ms timing rule sent a person nowhere), and a
// blocked alert channel (status said Enabled while every alert was dropped).
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/android_permissions.dart';
import 'package:raft_flutter/platform/background_notifications.dart'
    show messageChannelId;
import 'package:raft_flutter/platform/native_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'native_notifications_test.dart' show NotificationPluginFixture;

class _System extends AndroidPermissions {
  _System();
  AndroidPermissionStatus? answer;
  int settingsOpened = 0;
  @override
  Future<AndroidPermissionStatus?> status(String permission) async => answer;
  @override
  Future<bool> openAppSettings() async => ++settingsOpened > 0;
}

class _Android extends AndroidFlutterLocalNotificationsPlugin {
  _Android(this.system);
  final _System system;
  bool enabled = false;
  Importance? channel;
  int requests = 0;
  Duration answerAfter = Duration.zero;
  @override
  Future<bool?> areNotificationsEnabled() async => enabled;
  @override
  Future<bool?> requestNotificationsPermission() async {
    requests++;
    await Future<void>.delayed(answerAfter);
    return enabled;
  }

  @override
  Future<List<AndroidNotificationChannel>?> getNotificationChannels() async => [
    if (channel != null)
      AndroidNotificationChannel(
        messageChannelId,
        'Raft messages',
        importance: channel!,
      ),
  ];
}

AndroidPermissionStatus _status({
  int sdk = 34,
  bool granted = false,
  bool rationale = false,
}) => AndroidPermissionStatus(sdk: sdk, granted: granted, rationale: rationale);

void main() {
  late _System system;
  late _Android android;
  late NativeNotificationService service;
  const askedKey = 'raft.notifications.initial-permission.android.v1';

  Future<void> start({bool asked = false}) async {
    SharedPreferences.setMockInitialValues({if (asked) askedKey: true});
    system = _System();
    android = _Android(system);
    final plugin = NotificationPluginFixture()..android = android;
    plugin.initialized.complete(true);
    service = NativeNotificationService(
      plugin: plugin,
      platform: TargetPlatform.android,
      androidPermissions: system,
    );
    addTearDown(service.dispose);
    await service.bindAuthenticatedWorkspace('alice');
  }

  test('never asked: the first Enable shows the system prompt', () async {
    await start();
    system.answer = _status();
    await service.requestEnable(true);
    expect(android.requests, 1);
    expect(service.permissionPromptSkipped, isFalse);
  });

  test('one refusal (rationale true): Enable asks again', () async {
    await start(asked: true);
    system.answer = _status(rationale: true);
    await service.requestEnable(true);
    expect(android.requests, 1);
    expect(service.permissionPromptSkipped, isFalse);
  });

  test('after "don\'t ask again" Enable sends no request and goes to settings, however slow the system is', () async {
    await start(asked: true);
    system.answer = _status();
    android.answerAfter = const Duration(milliseconds: 600);
    await service.requestEnable(true);
    expect(android.requests, 0);
    expect(service.permissionPromptSkipped, isTrue);
    expect(service.enabled, isFalse);
    expect(
      service.error,
      'Allow notifications in system settings to receive alerts.',
    );
  });

  test('before Android 13 there is no prompt: settings only', () async {
    await start();
    system.answer = _status(sdk: 32);
    await service.requestEnable(true);
    expect(android.requests, 0);
    expect(service.permissionPromptSkipped, isTrue);
  });

  test('a prompt that was shown and refused is not "skipped"', () async {
    await start();
    system.answer = _status();
    android.answerAfter = const Duration(milliseconds: 1);
    await service.requestEnable(true);
    expect(android.requests, 1);
    expect(service.permissionPromptSkipped, isFalse);
  });

  test('a blocked alert channel is "off in system settings"', () async {
    await start();
    android.enabled = true;
    android.channel = Importance.none;
    await service.refreshPermission();
    expect(service.permitted, isFalse);
    expect(service.enabled, isFalse);
    system.answer = _status(granted: true);
    await service.requestEnable(true);
    expect(
      service.permissionPromptSkipped,
      isTrue,
      reason: 'the app switch is on: only the channel setting can help',
    );
    expect(android.requests, 0);
    android.channel = Importance.high;
    await service.refreshPermission();
    expect(service.permitted, isTrue);
    expect(service.enabled, isTrue);
    expect(service.error, isNull);
  });

  test('no alert channel yet (nothing posted) is not a block', () async {
    await start();
    android.enabled = true;
    android.channel = null;
    await service.refreshPermission();
    expect(service.permitted, isTrue);
  });
}
