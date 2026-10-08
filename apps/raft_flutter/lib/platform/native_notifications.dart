import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationPreferenceStore {
  Future<bool?> read(String key) async =>
      (await SharedPreferences.getInstance()).getBool(key);
  Future<bool> write(String key, bool value) async =>
      (await SharedPreferences.getInstance()).setBool(key, value);
}

/// Local OS delivery while the app's authenticated Socket connection is alive.
/// Android remote/background push is intentionally not registered here.
class NativeNotificationService extends ChangeNotifier {
  NativeNotificationService({
    FlutterLocalNotificationsPlugin? plugin,
    NotificationPreferenceStore? preferences,
    TargetPlatform? platform,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _platform = platform ?? defaultTargetPlatform,
       _preferences = preferences ?? NotificationPreferenceStore();
  final TargetPlatform _platform;
  final FlutterLocalNotificationsPlugin _plugin;
  final NotificationPreferenceStore _preferences;
  Future<void> _preferenceTail = Future.value();
  int _preferenceRevision = 0;
  Future<void>? _initializing;
  Future<void> _tail = Future.value();
  String? _scope;
  int _epoch = 0, _id = 0;
  bool enabled = false, permitted = false, available = false;
  bool _wanted = false;
  String? error;
  void Function(String)? onTap;
  bool get receivesMessages => _platform == TargetPlatform.android;
  bool get canOpenSettings =>
      _platform == TargetPlatform.android || _platform == TargetPlatform.macOS;

  Future<bool> _permission({bool request = false}) async {
    if (_platform == TargetPlatform.macOS) {
      final mac = _plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >();
      if (request) {
        return await mac?.requestPermissions(alert: true, sound: true) ?? false;
      }
      return (await mac?.checkPermissions())?.isEnabled ?? false;
    }
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return (request
            ? await android?.requestNotificationsPermission()
            : await android?.areNotificationsEnabled()) ??
        false;
  }

  Future<void> initialize() => _initializing ??= _initialize();
  Future<void> _initialize() async {
    try {
      available =
          await _plugin.initialize(
            settings: const InitializationSettings(
              android: AndroidInitializationSettings('@mipmap/ic_launcher'),
              macOS: DarwinInitializationSettings(
                requestAlertPermission: false,
                requestBadgePermission: false,
                requestSoundPermission: false,
                defaultPresentBadge: false,
              ),
              linux: LinuxInitializationSettings(
                defaultActionName: 'Open Raft',
              ),
            ),
            onDidReceiveNotificationResponse: (response) {
              if (response.payload != null) onTap?.call(response.payload!);
            },
          ) ??
          false;
      if (canOpenSettings) {
        permitted = await _permission();
        final launch = await _plugin.getNotificationAppLaunchDetails();
        final payload = launch?.notificationResponse?.payload;
        if (launch?.didNotificationLaunchApp == true && payload != null) {
          onTap?.call(payload);
        }
      } else {
        // Desktop policy is owned by the freedesktop notification daemon.
        permitted = available;
      }
    } catch (_) {
      error = 'System notifications are unavailable on this device.';
    }
    // Drop previous-process OS alerts before restoring any principal. The
    // launch target above has already been captured in memory for fresh checks.
    if (available) {
      try {
        await _plugin.cancelAll();
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> bind(String? scope) async {
    if (_scope == scope) return;
    _scope = scope;
    final epoch = ++_epoch;
    final revision = ++_preferenceRevision;
    enabled = false;
    _wanted = false;
    _tail = _tail.then((_) async {
      await initialize();
      if (available) {
        try {
          await _plugin.cancelAll();
        } catch (_) {
          /* Daemon may be offline. */
        }
      }
    });
    await _tail;
    if (scope != null) {
      try {
        await _preferenceTail;
        final wanted = await _preferences.read(_key(scope)) ?? false;
        if (epoch != _epoch || revision != _preferenceRevision) return;
        _wanted = wanted;
      } catch (_) {
        if (epoch != _epoch || revision != _preferenceRevision) return;
        _wanted = false;
        error = 'Notification settings could not be loaded on this device.';
      }
      enabled = _wanted && available && permitted;
    }
    notifyListeners();
  }

  String _key(String scope) =>
      'raft.notifications.${sha256.convert(utf8.encode(scope))}';

  Future<void> requestEnable(bool value) async {
    final scope = _scope, epoch = _epoch, revision = ++_preferenceRevision;
    if (scope == null) return;
    bool current() =>
        scope == _scope && epoch == _epoch && revision == _preferenceRevision;
    // A disable action takes effect before an older permission prompt returns.
    if (!value) {
      _wanted = false;
      enabled = false;
      notifyListeners();
    }
    await initialize();
    if (value && available && canOpenSettings) {
      try {
        final permission = await _permission(request: true);
        if (!current()) return;
        permitted = permission;
      } catch (_) {
        if (!current()) return;
        permitted = false;
        enabled = false;
        _wanted = false;
        error = 'System notification permission could not be checked.';
        notifyListeners();
        return;
      }
    }
    if (!current()) return;
    enabled = value && available && permitted;
    _wanted = enabled;
    error = value && !enabled
        ? 'Allow notifications in system settings to receive alerts.'
        : null;
    final savedValue = enabled;
    _preferenceTail = _preferenceTail.then((_) async {
      if (!current()) return;
      try {
        if (!await _preferences.write(_key(scope), savedValue)) {
          throw StateError('Preference write failed.');
        }
      } catch (_) {
        if (current()) {
          enabled = false;
          _wanted = false;
          error = 'Notification settings could not be saved on this device.';
        }
      }
    });
    await _preferenceTail;
    if (!current()) return;
    if (!enabled) {
      _tail = _tail.then((_) async {
        if (available) {
          try {
            await _plugin.cancelAll();
          } catch (_) {
            /* Keep the delivery queue usable while the OS is offline. */
          }
        }
      });
      try {
        await _tail;
      } catch (_) {
        /* Stay disabled while the OS is offline. */
      }
    }
    if (current()) notifyListeners();
  }

  Future<void> refreshPermission() async {
    await initialize();
    if (!canOpenSettings || !available) return;
    final epoch = _epoch, revision = _preferenceRevision;
    try {
      final permission = await _permission();
      if (epoch != _epoch || revision != _preferenceRevision) return;
      permitted = permission;
      enabled = _wanted && permitted;
      if (_wanted && !permitted) {
        error = 'Allow notifications in system settings to receive alerts.';
      } else if (permitted) {
        error = null;
      }
      notifyListeners();
    } catch (_) {
      if (epoch != _epoch || revision != _preferenceRevision) return;
      enabled = false;
      permitted = false;
      error = 'System notification permission could not be checked.';
      notifyListeners();
    }
  }

  Future<void> show({
    required String title,
    required String body,
    required String payload,
  }) async {
    final epoch = _epoch;
    _tail = _tail.then((_) async {
      await refreshPermission();
      if (epoch != _epoch || !enabled || !permitted || !available) return;
      try {
        await _plugin.show(
          id: ++_id,
          title: title,
          body: body,
          payload: payload,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'raft_messages_v1',
              'Raft messages',
              channelDescription: 'Direct messages, mentions and followed threads while Raft is connected.',
              importance: Importance.high,
              priority: Priority.high,
              visibility: NotificationVisibility.private,
            ),
            linux: LinuxNotificationDetails(),
            macOS: DarwinNotificationDetails(),
          ),
        );
      } catch (_) {
        error = 'The system notification could not be delivered.';
        notifyListeners();
      }
    });
    await _tail;
  }

  Future<void> test() => show(
    title: 'Raft',
    body: 'System notifications are enabled. Click to return to Raft.',
    payload: 'raft-notification-test',
  );
  Future<void> openSettings() async {
    if (_platform == TargetPlatform.android) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.openAppNotificationSettings();
    } else if (_platform == TargetPlatform.macOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >()
          ?.openAppNotificationSettings();
    }
  }
}
