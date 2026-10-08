import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'background_inbox.dart';
import 'background_notifications.dart'
    show
        notificationInitialization,
        notificationDetails,
        notificationPermission;

class NotificationPreferenceStore {
  Future<bool?> read(String key) async {
    final p = await SharedPreferences.getInstance();
    await p.reload();
    return p.getBool(key);
  }

  Future<bool> write(String key, bool value) async =>
      (await SharedPreferences.getInstance()).setBool(key, value);
}

/// Local OS delivery for authenticated Socket events and scheduled inbox fetch.
class NativeNotificationService extends ChangeNotifier {
  NativeNotificationService({
    FlutterLocalNotificationsPlugin? plugin,
    NotificationPreferenceStore? preferences,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _preferences = preferences ?? NotificationPreferenceStore();
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
  String? error, backgroundError;
  void setBackgroundError(String? value) {
    if (backgroundError == value) return;
    backgroundError = value;
    notifyListeners();
  }

  void Function(String)? onTap;
  bool get receivesMessages => Platform.isAndroid || Platform.isIOS;

  Future<void> initialize() => _initializing ??= _initialize();
  Future<void> _initialize() async {
    try {
      available =
          await _plugin.initialize(
            settings: notificationInitialization,
            onDidReceiveNotificationResponse: (response) {
              if (response.payload != null) onTap?.call(response.payload!);
            },
          ) ??
          false;
      if (Platform.isAndroid || Platform.isIOS) {
        permitted = await notificationPermission(_plugin);
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

  String _key(String scope) => notificationPreferenceKey(scope);

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
    if (value && available && (Platform.isAndroid || Platform.isIOS)) {
      try {
        final permission = Platform.isIOS
            ? await _plugin
                      .resolvePlatformSpecificImplementation<
                        IOSFlutterLocalNotificationsPlugin
                      >()
                      ?.requestPermissions(
                        alert: true,
                        badge: true,
                        sound: true,
                      ) ??
                  false
            : await _plugin
                      .resolvePlatformSpecificImplementation<
                        AndroidFlutterLocalNotificationsPlugin
                      >()
                      ?.requestNotificationsPermission() ??
                  false;
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
    if ((!Platform.isAndroid && !Platform.isIOS) || !available) return;
    final epoch = _epoch, revision = _preferenceRevision;
    try {
      final permission = await notificationPermission(_plugin);
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
        error = null;
        await _plugin.show(
          id: _notificationId(payload),
          title: title,
          body: body,
          payload: payload,
          notificationDetails: notificationDetails,
        );
      } catch (_) {
        error = 'The system notification could not be delivered.';
        notifyListeners();
      }
    });
    await _tail;
  }

  int _notificationId(String payload) {
    try {
      final p = jsonDecode(payload);
      final uri = Uri.parse(p['uri'] as String);
      final message = uri.queryParameters['messageId'] ?? uri.pathSegments.last;
      return messageNotificationId(_scope!, message);
    } catch (_) {
      return ++_id;
    }
  }

  Future<void> test() => show(
    title: 'Raft',
    body: 'System notifications are enabled. Click to return to Raft.',
    payload: 'raft-notification-test',
  );
  Future<void> openSettings() async {
    if (Platform.isIOS) {
      await launchUrl(Uri.parse('app-settings:'));
      return;
    }
    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.openAppNotificationSettings();
    }
  }
}
