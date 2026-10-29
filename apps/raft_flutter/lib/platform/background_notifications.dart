import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:raft_client/raft_client.dart';
import 'package:workmanager/workmanager.dart';

import 'auth_audit_log.dart';
import 'background_inbox.dart';
import 'content_coordinator.dart';
import 'content_target.dart';
import 'session_owner.dart';
import 'system_proxy_bootstrap.dart';
import 'session_store.dart';

export 'session_owner.dart';

/// Only iOS runs a periodic background refresh. Android relies on the live
/// socket (`notification:push`) and on the OS keeping the process alive; the
/// WorkManager task of earlier builds is cancelled, never registered again.
bool get backgroundRefreshSupported => Platform.isIOS;

@pragma('vm:entry-point')
void backgroundNotificationDispatcher() {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  Workmanager().executeTask((task, _) async {
    // A job queued by an earlier Android build may still fire once before
    // the cancel at startup removes it. It must do nothing.
    if (!Platform.isIOS) return true;
    if (task != backgroundInboxTask && task != Workmanager.iOSBackgroundTask) {
      return true;
    }
    return runBackgroundInbox();
  });
}

Future<bool> runBackgroundInbox() async {
  final started = DateTime.now();
  final mode = IsolateNameServer.lookupPortByName(sessionOwnerName) == null
      ? 'headless'
      : 'existing-session-owner';
  var success = false;
  try {
    return success = await _runBackgroundInbox();
  } finally {
    try {
      await BackgroundInboxStore().recordWake(mode, started, success);
    } catch (_) {}
  }
}

/// A worker is a guest of the session. It never waits for, takes from or
/// outlives a foreground: a live owner polls for it, a live guest makes it
/// skip this wake, and it stops at once when preempted.
Future<bool> _runBackgroundInbox({
  Duration busyBudget = const Duration(seconds: 8),
}) async {
  final waitedSince = DateTime.now();
  RaftClient? client;
  Timer? budget;
  var preempted = false;
  GuestSessionStore? guestStore;
  final owner = NativeSessionOwner(
    onPreempt: () async {
      preempted = true;
      // Stop in-flight requests first; then fence and drain credential writes.
      client?.http.close(force: true);
      await guestStore?.preempt();
    },
  );
  try {
    while (true) {
      final (probe, polled) = await NativeSessionOwner.probe();
      if (probe == OwnerProbe.delegated) return polled;
      if (probe == OwnerProbe.none && owner.registerGuest()) break;
      // Another guest is mid-run (or registered between probe and register).
      // This wake is a guest: wait a little for it, then try the next period.
      if (DateTime.now().difference(waitedSince) > busyBudget) return true;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    guestStore = GuestSessionStore(SecureSessionStore());
    if (preempted) return true;
    final store = BackgroundInboxStore(),
        scope = await BackgroundInboxStore().scope();
    if (scope == null || !await store.enabled(scope)) return true;
    final fields = scope.split('\n');
    if (fields.length != 3 ||
        !ContentTarget.validId(fields[1]) ||
        !ContentTarget.validId(fields[2])) {
      return true;
    }
    final origin = Uri.tryParse(fields[0]);
    if (origin == null ||
        !['https', 'http'].contains(origin.scheme) ||
        origin.userInfo.isNotEmpty ||
        origin.host.isEmpty ||
        (origin.path.isNotEmpty && origin.path != '/') ||
        origin.query.isNotEmpty ||
        origin.fragment.isNotEmpty) {
      return true;
    }
    final plugin = FlutterLocalNotificationsPlugin();
    if (await plugin.initialize(settings: notificationInitialization) != true ||
        !await notificationPermission(plugin)) {
      return true;
    }
    if (preempted) return true;
    // This isolate has its own proxy state. The platform bridge is not
    // registered in a worker engine, so the saved manual / direct choice and
    // the environment apply here; the OS proxy is the foreground's.
    await startSystemProxy(origins: [fields[0]]);
    if (preempted) return true;
    client = RaftClient(
      origin: fields[0],
      sessionStore: guestStore,
      clientKind: 'mobile',
      // A guest never signs the account out: if the server rejects the
      // credentials it just stops, and the foreground meets the same
      // rejection with the user in front of it (and the right message).
      allowSessionEnd: false,
      auditSink: AuthAuditLog.shared,
      recoveryBackoff: const [],
    );
    client.http.options.connectTimeout = const Duration(seconds: 3);
    client.http.options.receiveTimeout = const Duration(seconds: 5);
    // BGAppRefresh has a short OS budget. Closing transport stops in-flight
    // requests before ownership is released; no abandoned refresh can persist.
    budget = Timer(
      const Duration(seconds: 20),
      () => client?.http.close(force: true),
    );
    if (!await client.restore() ||
        preempted ||
        client.restoredOffline ||
        client.user?.id != fields[1]) {
      return true;
    }
    client.selectServer(fields[2]);
    late final BackgroundInboxPoller poller;
    poller = BackgroundInboxPoller(
      client: client,
      store: store,
      authorize: (target, valid) async {
        final server = await NativeContentCoordinator.authorizeClient(
          client!,
          target,
          valid,
        );
        if (server.flag('serverPushMuted')) {
          throw const RaftApiException('Notifications are muted.');
        }
      },
      deliver: (alert, selected) async {
        if (preempted ||
            await store.scope() != selected ||
            !await store.enabled(selected) ||
            !await notificationPermission(plugin)) {
          return false;
        }
        await plugin.show(
          // One notification per conversation, like the foreground path.
          id: conversationNotificationId(
            selected,
            alert.target.threadId ?? alert.target.channelId,
          ),
          title: alert.title,
          body: alert.body,
          payload: notificationPayload(client!, alert.target),
          notificationDetails: iosBadgeDetails(
            serverId: alert.target.serverId,
            badge: poller.totalUnread,
          ),
        );
        return true;
      },
    );
    return await poller.run();
  } catch (_) {
    return false;
  } finally {
    budget?.cancel();
    try {
      await client?.dispose();
    } finally {
      owner.release();
    }
  }
}

const notificationInitialization = InitializationSettings(
  android: AndroidInitializationSettings('ic_notification'),
  iOS: DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  ),
  macOS: DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
    defaultPresentBadge: false,
  ),
  linux: LinuxInitializationSettings(defaultActionName: 'Open Raft'),
);
const messageChannelId = 'raft_messages_v1';
const messageChannelName = 'Raft messages';
const messageChannelDescription =
    'Direct messages, mentions and followed conversations.';

/// Restored and refreshed notifications (unread backlog, a changed count):
/// they never sound, vibrate or pop up, but they count toward the launcher's
/// app icon badge exactly like an alert does.
const quietChannelId = 'raft_unread_v1';
const quietChannelName = 'Raft unread';
const quietChannelDescription =
    'Conversations that still have unread messages, shown without an alert.';
const notificationDetails = NotificationDetails(
  android: AndroidNotificationDetails(
    messageChannelId,
    messageChannelName,
    channelDescription: messageChannelDescription,
    icon: 'ic_notification',
    importance: Importance.high,
    priority: Priority.high,
    visibility: NotificationVisibility.private,
  ),
  iOS: DarwinNotificationDetails(),
  macOS: DarwinNotificationDetails(),
  linux: LinuxNotificationDetails(),
  windows: WindowsNotificationDetails(),
);

/// [notificationDetails] for a delivery that also sets the iOS icon badge to
/// the server's Activity unread total ([badge]; null leaves it unchanged) and
/// groups the server's alerts in the notification centre.
NotificationDetails iosBadgeDetails({String? serverId, int? badge}) =>
    NotificationDetails(
      android: notificationDetails.android,
      iOS: DarwinNotificationDetails(
        badgeNumber: badge,
        threadIdentifier: serverId,
      ),
      macOS: notificationDetails.macOS,
      linux: notificationDetails.linux,
      windows: notificationDetails.windows,
    );

Future<bool> notificationPermission(
  FlutterLocalNotificationsPlugin plugin,
) async {
  if (Platform.isIOS) {
    return (await plugin
                .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin
                >()
                ?.checkPermissions())
            ?.isEnabled ??
        false;
  }
  return true;
}

String notificationPayload(RaftClient client, ContentTarget target) =>
    jsonEncode({
      'origin': client.origin,
      'principal': client.user!.id,
      'serverId': target.serverId,
      'uri': target.nativeUri(target.serverId!).toString(),
    });

/// The part of the Workmanager plugin the scheduler uses, so tests can
/// observe registrations without a platform channel.
abstract class BackgroundWork {
  Future<void> initialize(Function callbackDispatcher);
  Future<void> registerPeriodic(String name, Duration frequency);
  Future<void> cancel(String name);
}

class WorkmanagerBackgroundWork implements BackgroundWork {
  @override
  Future<void> initialize(Function callbackDispatcher) =>
      Workmanager().initialize(callbackDispatcher);
  @override
  Future<void> registerPeriodic(String name, Duration frequency) =>
      Workmanager().registerPeriodicTask(
        name,
        name,
        frequency: frequency,
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
        constraints: Constraints(networkType: NetworkType.connected),
      );
  @override
  Future<void> cancel(String name) => Workmanager().cancelByUniqueName(name);
}

/// iOS: registers and cancels the BGAppRefresh task with the notification
/// setting. Android: never registers; once per process it cancels the periodic
/// WorkManager task that builds before this change left behind, so upgraded
/// installs stop running it.
class BackgroundNotificationScheduler {
  BackgroundNotificationScheduler({
    BackgroundWork? work,
    BackgroundInboxStore? store,
    bool? android,
    bool? ios,
  }) : work = work ?? WorkmanagerBackgroundWork(),
       store = store ?? BackgroundInboxStore(),
       android = android ?? Platform.isAndroid,
       ios = ios ?? Platform.isIOS;
  final BackgroundWork work;
  final BackgroundInboxStore store;
  final bool android, ios;
  Future<void> _tail = Future.value();
  Future<void>? _initializing;
  Future<void>? _legacyCancel;
  String? _boundScope;
  bool? _boundEnabled;

  /// iOS: register the background dispatcher. Android: drop the legacy task.
  Future<void> initialize() {
    if (android) return cancelLegacyAndroidTask();
    if (!ios) return Future.value();
    return _initializing ??= work
        .initialize(backgroundNotificationDispatcher)
        .catchError((Object e, StackTrace stack) {
          _initializing = null;
          Error.throwWithStackTrace(e, stack);
        });
  }

  /// Cancels the unique periodic task and the scope it selected. Idempotent
  /// and retried on the next call after a failure.
  Future<void> cancelLegacyAndroidTask() => _legacyCancel ??=
      () async {
        await work.cancel(backgroundInboxTask);
        await store.select(null);
      }().catchError((Object e, StackTrace stack) {
        _legacyCancel = null;
        Error.throwWithStackTrace(e, stack);
      });

  Future<void> get settled => _tail;
  Future<void> bind(String? scope, bool enabled) {
    // Nothing to schedule on Android; a failed cancel is retried next call.
    if (android) return cancelLegacyAndroidTask().catchError((Object _) {});
    if (!ios) return Future.value();
    _tail = _tail.catchError((Object _) {}).then((_) async {
      if (_boundScope == scope && _boundEnabled == enabled) return;
      if (!enabled || scope == null) {
        await store.select(null);
        await initialize();
        await work.cancel(backgroundInboxTask);
        if (scope != null) await store.forget(scope);
        _boundScope = scope;
        _boundEnabled = enabled;
        return;
      }
      await store.activate(scope);
      await store.select(scope);
      await initialize();
      await work.registerPeriodic(
        backgroundInboxTask,
        const Duration(minutes: 15),
      );
      _boundScope = scope;
      _boundEnabled = enabled;
    });
    return _tail;
  }
}
