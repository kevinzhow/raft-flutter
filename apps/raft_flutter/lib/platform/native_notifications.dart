import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'android_permissions.dart';
import 'background_inbox.dart';
import 'background_notifications.dart'
    show
        notificationInitialization,
        messageChannelDescription,
        messageChannelId,
        messageChannelName,
        quietChannelDescription,
        quietChannelId,
        quietChannelName;
import 'content_target.dart';
import 'linux_activation_token.dart';
import 'linux_desktop_identity.dart';
import 'windows_notifications.dart';

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
    TargetPlatform? platform,
    WindowsNotifications? windows,
    this.linuxDetails,
    LinuxActivationTokens? activationTokens,
    this.androidPermissions = const AndroidPermissions(),
  }) : // Only the production plugin listens on the member's real session bus.
       _activationTokens =
           activationTokens ??
           (plugin == null ? LinuxActivationTokens() : null),
       _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _platform = platform ?? defaultTargetPlatform,
       _preferences = preferences ?? NotificationPreferenceStore(),
       _windows = windows ?? WindowsNotifications();
  final WindowsNotifications _windows;

  /// Android runtime-permission facts (whether a system prompt can still show).
  final AndroidPermissions androidPermissions;

  final LinuxActivationTokens? _activationTokens;

  /// The desktop's focus token for the notification click being handled.
  Future<String?> takeActivationToken() async =>
      await _activationTokens?.take();

  /// Linux alert presentation; defaults to the app icon and launcher id.
  final LinuxNotificationDetails Function()? linuxDetails;

  /// Whether the Linux notification server renders `<b>`, `<a>` and `<img>` in
  /// the body. Read once after initialization; message text is escaped when so.
  bool _bodyMarkup = false;
  final TargetPlatform _platform;
  final FlutterLocalNotificationsPlugin _plugin;
  final NotificationPreferenceStore _preferences;
  Future<void> _preferenceTail = Future.value();
  int _preferenceRevision = 0;
  Future<void>? _initializing;
  Future<bool>? _permissionRequest;
  bool activationAsked = false, activationDismissed = false;
  bool _activationHistoryReady = false;
  Future<void> _tail = Future.value();
  String? _scope, _detachedAccount;
  int _epoch = 0, _id = 0;

  /// The conversations that have a live system notification, by Activity
  /// scope id (a thread's own channel for a thread). One notification per
  /// conversation: a later message replaces it in place.
  final Map<String, LiveNotice> _live = {};

  /// Completes when every queued delivery and removal has reached the OS.
  Future<void> get idle async {
    Future<void> tail;
    do {
      tail = _tail;
      await tail;
    } while (!identical(tail, _tail));
  }

  /// Unread count shown on each live conversation notification.
  Map<String, int> get liveUnread => {
    for (final e in _live.entries) e.key: e.value.unread,
  };

  /// Localizes the few fixed words the system notifications carry (the
  /// unread count). Identity until the app installs its display language.
  String Function(String source) localize = (source) => source;
  bool enabled = false, permitted = false, available = false;

  /// Set once [initialize] has finished; before that [available] is unknown.
  bool initialized = false;
  bool _wanted = false;
  // ignore: raft_lints/avoid_imperative_notice_state -- error clears when the principal changes (bind), on the next successful permission check/enable/delivery; backgroundError is set by its owner via setBackgroundError(null).
  String? error, backgroundError;

  /// The device-level failure of [initialize]; every other [error] belongs to
  /// the principal ([bind]) whose preference or permission it describes.
  static const _unavailable =
      'System notifications are unavailable on this device.';
  void setBackgroundError(String? value) {
    if (backgroundError == value) return;
    backgroundError = value;
    notifyListeners();
  }

  void Function(String)? onTap;

  /// Rechecked at the final OS send for queued foreground arrivals.
  bool Function()? deliveryAllowed;
  TargetPlatform get platform => _platform;

  /// True once the latest permission request could not put a prompt on screen:
  /// the OS no longer asks (Android after two refusals or before Android 13,
  /// or while the message channel is blocked; iOS after the first refusal), so
  /// the only way forward is the system notification settings. Android knows
  /// this exactly (see [_promptBlocked]); iOS/macOS infer it from a denial that
  /// came back too fast for a person to have answered.
  bool permissionPromptSkipped = false;
  bool get receivesMessages =>
      _platform == TargetPlatform.android ||
      _platform == TargetPlatform.iOS ||
      _platform == TargetPlatform.macOS ||
      _platform == TargetPlatform.linux;
  bool get canOpenSettings =>
      _platform == TargetPlatform.android ||
      _platform == TargetPlatform.iOS ||
      _platform == TargetPlatform.macOS ||
      _platform == TargetPlatform.windows;

  bool get systemManaged =>
      _platform == TargetPlatform.macOS ||
      _platform == TargetPlatform.windows ||
      _platform == TargetPlatform.linux;

  bool get hasPermissionPrompt => const {
    TargetPlatform.macOS,
    TargetPlatform.iOS,
    TargetPlatform.android,
  }.contains(_platform);

  // Desktop has no app-owned opt-in; the system notification switch owns it
  // (on Linux the notification daemon: Do Not Disturb, per-app settings).
  void _updateEnabled() {
    enabled =
        _scope != null && available && permitted && (systemManaged || _wanted);
  }

  Future<bool> _permission({bool request = false}) async {
    // Windows has no app-owned permission prompt. Read the notifier's actual
    // setting on every delivery, including OS/user/group-policy restrictions.
    if (_platform == TargetPlatform.windows) return _windows.permitted();
    if (_platform == TargetPlatform.iOS) {
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (request) {
        return await ios?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
      return (await ios?.checkPermissions())?.isEnabled ?? false;
    }
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
    final allowed =
        (request
            ? await android?.requestNotificationsPermission()
            : await android?.areNotificationsEnabled()) ??
        false;
    return allowed && !await _messageChannelBlocked(android);
  }

  /// The person blocked the alert channel in the system's per-app settings:
  /// the app-level switch stays on, yet every message alert is dropped. The
  /// channel exists once the first alert was posted.
  Future<bool> _messageChannelBlocked(
    AndroidFlutterLocalNotificationsPlugin? android,
  ) async {
    try {
      final channels = await android?.getNotificationChannels();
      return channels?.any(
            (c) => c.id == messageChannelId && c.importance == Importance.none,
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Android: a request would show nothing, so asking is pointless and the
  /// system settings are the only way on. Exact, not timed: before Android 13
  /// there is no prompt at all; from 13 the platform stops asking after the
  /// second refusal, which [AndroidPermissionStatus.canPrompt] reads together
  /// with this app's record that it asked. A granted permission with a blocked
  /// channel is settings-only as well. Unknown (no bridge) means "ask".
  Future<bool> _promptBlocked() async {
    if (_platform != TargetPlatform.android) return false;
    if (await _permission()) return false;
    final status = await androidPermissions.status(
      AndroidPermissions.postNotifications,
    );
    if (status == null) return false;
    if (status.sdk < 33 || status.granted) return true;
    return !status.canPrompt(
      asked: await _preferences.read(_permissionKey) == true,
    );
  }

  Future<void> initialize() => _initializing ??= _initialize();
  Future<void> _initialize() async {
    try {
      if (_platform == TargetPlatform.windows) {
        _windows.onTap = (payload) => onTap?.call(payload);
        await _windows.initialize();
        available = true;
        permitted = await _permission();
      } else {
        final result = await _plugin.initialize(
          settings: notificationInitialization,
          onDidReceiveNotificationResponse: (response) {
            if (response.payload != null) onTap?.call(response.payload!);
          },
        );
        // Darwin returns the authorization result, including false when all
        // permission requests are deferred. It still initialized successfully.
        available =
            _platform == TargetPlatform.macOS || _platform == TargetPlatform.iOS
            ? result != null
            : result == true;
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
          if (available && _platform == TargetPlatform.linux) {
            _activationTokens?.start();
            await _readLinuxCapabilities();
          }
        }
      }
    } catch (_) {
      error = _unavailable;
    }
    initialized = true;
    // Drop previous-process OS alerts before restoring any principal. The
    // launch target above has already been captured in memory for fresh checks.
    if (available) {
      try {
        await _cancelAll();
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> _readLinuxCapabilities() async {
    try {
      final linux = _plugin
          .resolvePlatformSpecificImplementation<
            LinuxFlutterLocalNotificationsPlugin
          >();
      _bodyMarkup = (await linux?.getCapabilities())?.bodyMarkup ?? false;
    } catch (_) {
      // Daemon offline or without GetCapabilities: assume plain text, which
      // is also what a server without markup support displays verbatim.
      _bodyMarkup = false;
    }
  }

  Future<void> bind(String? scope) async {
    _detachedAccount = null;
    if (_scope == scope) return;
    _scope = scope;
    _activationHistoryReady = false;
    final epoch = ++_epoch;
    final revision = ++_preferenceRevision;
    enabled = false;
    _wanted = false;
    // A failure to load or save the previous principal's preference is not
    // the next one's.
    if (error != _unavailable) error = null;
    _tail = _tail.then((_) async {
      await initialize();
      if (available) {
        try {
          await _cancelAll();
        } catch (_) {
          /* Daemon may be offline. */
        }
      }
    });
    await _tail;
    if (scope != null && !systemManaged) {
      try {
        await _preferenceTail;
        final wanted =
            await _preferences.read(_key(scope)) ?? hasPermissionPrompt;
        if (epoch != _epoch || revision != _preferenceRevision) return;
        _wanted = wanted;
      } catch (_) {
        if (epoch != _epoch || revision != _preferenceRevision) return;
        _wanted = false;
        error = 'Notification settings could not be loaded on this device.';
      }
    }
    _updateEnabled();
    notifyListeners();
  }

  bool _belongsToAccount(String account) {
    final fields = _scope?.split('\n');
    return fields?.length == 3 && fields!.take(2).join('\n') == account;
  }

  /// Hiding navigation retains only already-authorized Android notices. The
  /// old delivery scope is a notice receipt, not a retained workspace owner.
  Future<void> detachWorkspace(String? account) async {
    if (_platform != TargetPlatform.android ||
        account == null ||
        !_belongsToAccount(account)) {
      await bindAuthenticatedWorkspace(null);
      return;
    }
    _detachedAccount = account;
  }

  /// Existing quiet residuals can follow a proven account total on the chooser.
  /// Never invent a notice or discard a still-unread real conversation card.
  Future<void> maintainAccountUnread({
    required String account,
    required int total,
    required Set<String> members,
    required String residualKey,
    required String residualPayload,
  }) async {
    final epoch = _epoch, scope = _scope;
    bool current() =>
        epoch == _epoch &&
        scope == _scope &&
        _detachedAccount == account &&
        _belongsToAccount(account);
    _tail = _tail
        .then((_) async {
          if (!current()) return;
          final server = _scope!.split('\n').last;
          if (total == 0 || !members.contains(server)) {
            await _cancelAll();
            if (!current()) return;
            return;
          }
          final residual = _live[residualKey];
          if (residual == null) return;
          final accounted = _live.entries
              .where((entry) => entry.key != residualKey)
              .fold<int>(0, (sum, entry) => sum + entry.value.unread);
          final wanted = total > accounted ? total - accounted : 0;
          if (wanted == residual.unread) return;
          if (wanted == 0) {
            await _cancel(residual.id);
            if (!current()) return;
            _live.remove(residualKey);
          } else {
            await refreshPermission();
            if (!current() || !enabled || !permitted || !available) return;
            final body = localize('{count} unread')
                .replaceAll('{count}', '$wanted');
            await _show(
              id: residual.id,
              title: residual.title,
              body: body,
              payload: residualPayload,
              unread: wanted,
              quiet: true,
              update: true,
            );
            if (!current()) return;
            _live[residualKey] = LiveNotice(
              id: residual.id,
              unread: wanted,
              quiet: true,
              title: residual.title,
              body: body,
            );
          }
          if (!current()) return;
          await _syncSummary();
        })
        .catchError((Object _) {
          // Optional maintenance retries on a later accepted account refresh.
        });
    await _tail;
  }

  /// Restores the device prompt history without requesting OS permission.
  Future<void> bindAuthenticatedWorkspace(String? scope) async {
    await bind(scope);
    if (_scope != scope || scope == null || !hasPermissionPrompt) return;
    final epoch = _epoch;
    try {
      final asked = await _preferences.read(_permissionKey) == true;
      if (epoch != _epoch) return;
      activationAsked = asked;
      _activationHistoryReady = true;
    } catch (_) {
      if (epoch != _epoch) return;
      // Unknown history must not silently offer another first-time prompt.
      activationAsked = true;
      _activationHistoryReady = true;
      error = 'Notification settings could not be loaded on this device.';
    }
    await refreshPermission();
  }

  String get _permissionKey =>
      'raft.notifications.initial-permission.${_platform.name}.v1';

  bool get showActivation =>
      initialized &&
      available &&
      _activationHistoryReady &&
      _scope != null &&
      hasPermissionPrompt &&
      !permitted &&
      !activationAsked &&
      !activationDismissed;

  void dismissActivation() {
    activationDismissed = true;
    notifyListeners();
  }

  Future<bool> _askPermission(String scope, int epoch) async {
    if (!await _preferences.write(_permissionKey, true)) {
      throw StateError('Permission request marker could not be saved.');
    }
    if (_scope != scope || epoch != _epoch) {
      await _preferences.write(_permissionKey, false);
      activationAsked = false;
      notifyListeners();
      return false;
    }
    try {
      final granted = await _permission(request: true);
      activationAsked = true;
      notifyListeners();
      return granted;
    } catch (_) {
      // A failed native call is retryable by an explicit action; it is not an
      // answered system prompt. Denials, in contrast, keep the device marker.
      await _preferences.write(_permissionKey, false);
      rethrow;
    }
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
    if (value && available && canOpenSettings) {
      try {
        final asked = Stopwatch()..start();
        final blocked = await _promptBlocked();
        final request = blocked
            ? Future.value(false)
            : hasPermissionPrompt
            ? (_permissionRequest ??= _askPermission(scope, epoch))
            : _permission(request: true);
        final bool permission;
        try {
          permission = await request;
        } finally {
          if (identical(_permissionRequest, request)) _permissionRequest = null;
        }
        if (!current()) return;
        permitted = permission;
        // A person cannot answer a system prompt within this window.
        permissionPromptSkipped =
            !permission &&
            (_platform == TargetPlatform.android
                ? blocked
                : asked.elapsed < const Duration(milliseconds: 400));
      } catch (_) {
        if (!current()) return;
        permitted = false;
        enabled = false;
        _permissionRequest = null;
        _wanted = false;
        error = 'Notification settings could not be saved on this device.';
        notifyListeners();
        return;
      }
    }
    if (!current()) return;
    if (systemManaged) {
      _updateEnabled();
      error = value && !permitted
          ? 'Allow notifications in system settings to receive alerts.'
          : null;
      notifyListeners();
      return;
    }
    enabled = value && available && permitted;
    _wanted = hasPermissionPrompt ? value : enabled;
    error = value && !enabled
        ? 'Allow notifications in system settings to receive alerts.'
        : null;
    final savedValue = _wanted;
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
            await _cancelAll();
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
      _updateEnabled();
      if ((_wanted || systemManaged) && !permitted) {
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

  /// Posts the system notification of one conversation (taken from [payload]
  /// unless [conversation] names a pseudo-conversation). [unread] is the
  /// server's Activity count for it (the number a launcher sums into the app
  /// icon badge). A [quiet] post never alerts: it restores or refreshes a
  /// notification (backlog, a changed count) and is allowed while the app is
  /// in the foreground.
  Future<void> show({
    required String title,
    required String body,
    required String payload,
    int? unread,
    bool quiet = false,
    String? conversation,
  }) async {
    final epoch = _epoch;
    _tail = _tail.then((_) async {
      await refreshPermission();
      if (epoch != _epoch ||
          !enabled ||
          _detachedAccount != null ||
          !permitted ||
          !available ||
          (!quiet && deliveryAllowed?.call() == false)) {
        return;
      }
      try {
        error = null;
        final key = conversation ?? _conversationOf(payload);
        final id = _notificationId(payload, key);
        final previous = key == null ? null : _live[key];
        final count = (unread ?? 0) > 0 ? unread! : (previous?.unread ?? 0) + 1;
        // A count refresh keeps the notification where it is (an alert that
        // already popped up stays on the messages channel) and never alerts.
        final asQuiet = quiet && (previous == null || previous.quiet);
        await _show(
          id: id,
          title: title,
          body: body,
          payload: payload,
          unread: count,
          quiet: asQuiet,
          update: previous != null && quiet,
        );
        if (key != null) {
          _live[key] = LiveNotice(
            id: id,
            unread: count,
            quiet: asQuiet,
            title: title,
            body: body,
          );
          await _syncSummary();
        }
      } catch (_) {
        error = 'The system notification could not be delivered.';
        notifyListeners();
      }
    });
    await _tail;
  }

  /// Removes the notifications of [conversations] (each as soon as it is read,
  /// here or elsewhere). Unknown ones are ignored.
  Future<void> cancelConversations(Iterable<String> conversations) async {
    final epoch = _epoch;
    final wanted = conversations.where(_live.containsKey).toList();
    if (wanted.isEmpty) return;
    _tail = _tail.then((_) async {
      if (epoch != _epoch || !available) return;
      for (final conversation in wanted) {
        final live = _live.remove(conversation);
        if (live == null) continue;
        try {
          await _cancel(live.id);
        } catch (_) {
          /* The OS may be offline; the entry is already forgotten. */
        }
      }
      try {
        await _syncSummary();
      } catch (_) {}
    });
    await _tail;
  }

  /// The scope id (Activity row identity) of a notification payload.
  String? _conversationOf(String payload) {
    try {
      final p = jsonDecode(payload);
      final target = ContentTarget.parse(
        Uri.parse(p['uri'] as String),
        origin: Uri(),
      );
      return target == null ? null : target.threadId ?? target.channelId;
    } catch (_) {
      return null;
    }
  }

  int _notificationId(String payload, String? conversation) {
    if (conversation != null) {
      return conversationNotificationId(_scope!, conversation);
    }
    try {
      final p = jsonDecode(payload);
      final uri = Uri.parse(p['uri'] as String);
      final message = uri.queryParameters['messageId'] ?? uri.pathSegments.last;
      return messageNotificationId(_scope!, message);
    } catch (_) {
      return ++_id;
    }
  }

  /// Android: one summary per server, so the shade shows a group with a
  /// count. Launchers do not count a group summary, so the badge is the sum of
  /// the conversation notifications' numbers.
  Future<void> _syncSummary() async {
    if (_platform != TargetPlatform.android || _scope == null) return;
    final id = conversationNotificationId(_scope!, 'summary');
    if (_live.isEmpty) {
      await _cancel(id);
      return;
    }
    final total = _live.values.fold<int>(0, (sum, live) => sum + live.unread);
    final label = localize('{count} unread').replaceAll('{count}', '$total');
    await _plugin.show(
      id: id,
      title: 'Raft',
      body: label,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          quietChannelId,
          quietChannelName,
          channelDescription: quietChannelDescription,
          icon: 'ic_notification',
          importance: Importance.low,
          priority: Priority.low,
          groupKey: _groupKey,
          setAsGroupSummary: true,
          groupAlertBehavior: GroupAlertBehavior.children,
          onlyAlertOnce: true,
          visibility: NotificationVisibility.private,
          styleInformation: InboxStyleInformation(
            [
              for (final live in _live.values.take(7))
                '${live.title}: ${live.body}',
            ],
            contentTitle: 'Raft',
            summaryText: label,
          ),
        ),
      ),
    );
  }

  // The Android group of the signed-in server's notifications.
  String get _groupKey => 'raft.messages.${_scope!.split('\n').last}';

  /// Posts one test notification and reports whether the system accepted it.
  /// It does not depend on the member's opt-in: desktop notifications are owned
  /// by the system, and a phone only needs the permission to be granted.
  Future<bool> test({
    String title = 'Test notification',
    String body = 'System notifications are enabled. Click to return to Raft.',
  }) async {
    await initialize();
    if (!available) return false;
    try {
      if (canOpenSettings) {
        // macOS asks the first time; phones re-check what the person changed
        // in system settings.
        permitted = await _permission() || await _permission(request: true);
        if (systemManaged) {
          _updateEnabled();
          notifyListeners();
        }
        if (!permitted) {
          enabled = false;
          notifyListeners();
          return false;
        }
      }
      await _show(
        id: ++_id,
        title: title,
        body: body,
        payload: 'raft-notification-test',
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> openSettings() async {
    if (_platform == TargetPlatform.windows) {
      if (!await launchUrl(Uri.parse('ms-settings:notifications'))) {
        throw StateError('Windows notification settings could not be opened.');
      }
      return;
    }
    if (_platform == TargetPlatform.iOS) {
      await launchUrl(Uri.parse('app-settings:'));
      return;
    }
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

  Future<void> presentWindow() async {
    if (_platform == TargetPlatform.windows) await _windows.present();
  }

  Future<void> _cancelAll() {
    _live.clear();
    return _platform == TargetPlatform.windows
        ? _windows.cancelAll()
        : _plugin.cancelAll();
  }

  /// Windows toasts are replaced by id but have no per-id removal yet.
  Future<void> _cancel(int id) => _platform == TargetPlatform.windows
      ? Future.value()
      : _plugin.cancel(id: id);

  Future<void> _show({
    required int id,
    required String title,
    required String body,
    required String payload,
    int? unread,
    bool quiet = false,
    bool update = false,
  }) => _platform == TargetPlatform.windows
      ? _windows.show(id: id, title: title, body: body, payload: payload)
      : _plugin.show(
          id: id,
          title: title,
          body: _platform == TargetPlatform.linux && _bodyMarkup
              ? linuxEscapeMarkup(body)
              : body,
          payload: payload,
          notificationDetails: _platform == TargetPlatform.linux
              ? NotificationDetails(
                  linux: (linuxDetails ?? _defaultLinuxDetails)(),
                )
              : _platform == TargetPlatform.android
              ? _androidDetails(
                  unread: unread,
                  quiet: quiet,
                  update: update,
                  group: _scope == null ? null : _groupKey,
                )
              : _darwinDetails(payload),
        );

  NotificationDetails _androidDetails({
    required int? unread,
    required bool quiet,
    required bool update,
    required String? group,
  }) => NotificationDetails(
    android: AndroidNotificationDetails(
      quiet ? quietChannelId : messageChannelId,
      quiet ? quietChannelName : messageChannelName,
      channelDescription: quiet
          ? quietChannelDescription
          : messageChannelDescription,
      icon: 'ic_notification',
      importance: quiet ? Importance.low : Importance.high,
      priority: quiet ? Priority.low : Priority.high,
      visibility: NotificationVisibility.private,
      groupKey: group,
      groupAlertBehavior: GroupAlertBehavior.children,
      // A count that moved, or a restored notification, never alerts again.
      onlyAlertOnce: update || quiet,
      // Launchers sum these numbers into the app icon badge: the number is
      // the conversation's Activity unread count, nothing else.
      number: unread,
      subText: unread != null && unread > 1
          ? localize('{count} unread').replaceAll('{count}', '$unread')
          : null,
    ),
  );

  /// iOS and macOS group a server's alerts in the notification centre.
  NotificationDetails _darwinDetails(String payload) {
    String? thread;
    try {
      thread = (jsonDecode(payload) as Map)['serverId'] as String?;
    } catch (_) {}
    final details = DarwinNotificationDetails(threadIdentifier: thread);
    return NotificationDetails(iOS: details, macOS: details);
  }

  static LinuxNotificationDetails _defaultLinuxDetails() =>
      linuxMessageNotificationDetails(
        iconPath: linuxAppIconPath(),
        desktopEntry: linuxDesktopEntryId(),
      );

  bool receiveWindowsActivation(Uri uri) =>
      _platform == TargetPlatform.windows && _windows.receiveLink(uri);
}

/// One conversation's live system notification.
class LiveNotice {
  const LiveNotice({
    required this.id,
    required this.unread,
    required this.quiet,
    required this.title,
    required this.body,
  });
  final int id, unread;
  final bool quiet;
  final String title, body;
}

/// Notification-spec body markup is a tiny HTML subset; message text must show
/// as written, so the three markup characters are escaped before it is sent.
String linuxEscapeMarkup(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
