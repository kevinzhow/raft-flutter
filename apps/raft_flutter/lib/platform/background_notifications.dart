import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:raft_client/raft_client.dart';
import 'package:workmanager/workmanager.dart';

import 'background_inbox.dart';
import 'content_coordinator.dart';
import 'content_target.dart';
import 'session_store.dart';

bool get mobileBackgroundSupported => Platform.isAndroid || Platform.isIOS;
const _sessionOwnerName = 'raft.native.session-owner.v1';

/// One process-wide owner of rotating credentials across Flutter engines.
/// Workers delegate to a running UI client; UI startup waits for a headless
/// owner's completion before it reads or changes the secure session.
class NativeSessionOwner {
  NativeSessionOwner({this.poll, bool? supported})
    : supported = supported ?? mobileBackgroundSupported;
  final bool supported;
  final Future<bool> Function()? poll;
  ReceivePort? _port;
  Future<bool>? _polling;
  Future<void>? _acquiring;
  Future<void> acquire() =>
      _acquiring ??= _acquire().whenComplete(() => _acquiring = null);
  Future<void> _acquire() async {
    if (!supported || _port != null) return;
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (true) {
      final port = ReceivePort();
      if (IsolateNameServer.registerPortWithName(
        port.sendPort,
        _sessionOwnerName,
      )) {
        _port = port;
        port.listen((message) async {
          if (message is! List ||
              message.length != 2 ||
              message[1] is! SendPort) {
            return;
          }
          final reply = message[1] as SendPort;
          if (message[0] != 'poll' || poll == null) {
            reply.send(false);
            return;
          }
          try {
            reply.send(
              await (_polling ??= poll!().whenComplete(() => _polling = null)),
            );
          } catch (_) {
            reply.send(false);
          }
        });
        return;
      }
      port.close();
      if (DateTime.now().isAfter(deadline)) {
        throw const RaftApiException(
          'Background session recovery is still running. Please retry.',
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  void release() {
    if (_polling != null) {
      unawaited(
        _polling!.then<void>(
          (_) => release(),
          onError: (Object _, StackTrace _) => release(),
        ),
      );
      return;
    }
    final port = _port;
    if (port == null) return;
    if (IsolateNameServer.lookupPortByName(_sessionOwnerName) ==
        port.sendPort) {
      IsolateNameServer.removePortNameMapping(_sessionOwnerName);
    }
    port.close();
    _port = null;
  }
}

@pragma('vm:entry-point')
void backgroundNotificationDispatcher() {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  Workmanager().executeTask((task, _) async {
    if (task != backgroundInboxTask && task != Workmanager.iOSBackgroundTask) {
      return true;
    }
    return runBackgroundInbox();
  });
}

Future<bool> runBackgroundInbox() async {
  final started = DateTime.now();
  final mode = IsolateNameServer.lookupPortByName(_sessionOwnerName) == null
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

Future<bool> _runBackgroundInbox() async {
  final running = IsolateNameServer.lookupPortByName(_sessionOwnerName);
  if (running != null) {
    final reply = ReceivePort();
    try {
      running.send(['poll', reply.sendPort]);
      return await reply.first.timeout(const Duration(seconds: 25)) == true;
    } catch (_) {
      return false;
    } finally {
      reply.close();
    }
  }
  final owner = NativeSessionOwner();
  RaftClient? client;
  Timer? budget;
  try {
    await owner.acquire();
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
    client = RaftClient(
      origin: fields[0],
      sessionStore: SecureSessionStore(),
      clientKind: 'mobile',
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
        client.restoredOffline ||
        client.user?.id != fields[1]) {
      return true;
    }
    client.selectServer(fields[2]);
    return await BackgroundInboxPoller(
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
        if (await store.scope() != selected ||
            !await store.enabled(selected) ||
            !await notificationPermission(plugin)) {
          return false;
        }
        await plugin.show(
          id: messageNotificationId(selected, alert.target.messageId!),
          title: alert.title,
          body: alert.body,
          payload: notificationPayload(client!, alert.target),
          notificationDetails: notificationDetails,
        );
        return true;
      },
    ).run();
  } catch (_) {
    return false;
  } finally {
    budget?.cancel();
    await client?.dispose();
    owner.release();
  }
}

const notificationInitialization = InitializationSettings(
  android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  iOS: DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  ),
  linux: LinuxInitializationSettings(defaultActionName: 'Open Raft'),
);
const notificationDetails = NotificationDetails(
  android: AndroidNotificationDetails(
    'raft_messages_v1',
    'Raft messages',
    channelDescription: 'Direct messages, mentions and followed conversations.',
    importance: Importance.high,
    priority: Priority.high,
    visibility: NotificationVisibility.private,
  ),
  iOS: DarwinNotificationDetails(),
  linux: LinuxNotificationDetails(),
);
Future<bool> notificationPermission(
  FlutterLocalNotificationsPlugin plugin,
) async {
  if (Platform.isAndroid) {
    return await plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.areNotificationsEnabled() ??
        false;
  }
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

class BackgroundNotificationScheduler {
  final store = BackgroundInboxStore();
  Future<void> _tail = Future.value();
  Future<void>? _initializing;
  String? _boundScope;
  bool? _boundEnabled;
  Future<void> initialize() async {
    if (!mobileBackgroundSupported) return;
    await (_initializing ??= Workmanager()
        .initialize(backgroundNotificationDispatcher)
        .catchError((Object e, StackTrace stack) {
          _initializing = null;
          Error.throwWithStackTrace(e, stack);
        }));
  }

  Future<void> get settled => _tail;
  Future<void> bind(String? scope, bool enabled) {
    if (!mobileBackgroundSupported) return Future.value();
    _tail = _tail.catchError((Object _) {}).then((_) async {
      if (_boundScope == scope && _boundEnabled == enabled) return;
      if (!enabled || scope == null) {
        await store.select(null);
        await initialize();
        await Workmanager().cancelByUniqueName(backgroundInboxTask);
        if (scope != null) await store.forget(scope);
        _boundScope = scope;
        _boundEnabled = enabled;
        return;
      }
      await store.activate(scope);
      await store.select(scope);
      await initialize();
      await Workmanager().registerPeriodicTask(
        backgroundInboxTask,
        backgroundInboxTask,
        frequency: const Duration(minutes: 15),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
        constraints: Constraints(networkType: NetworkType.connected),
      );
      _boundScope = scope;
      _boundEnabled = enabled;
    });
    return _tail;
  }
}
