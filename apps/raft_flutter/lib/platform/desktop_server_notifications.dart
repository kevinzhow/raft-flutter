// Source: packages/web/src/notifications/desktopNative/serverNotificationStream.ts,
// notificationGate.ts and desktopNotificationConsumer.ts at v1.24.0-source.1
// (1d689caf).
//
// The ONE source of Raft Desktop's notifications: the server's
// `notification:desktop` stream (DesktopNotificationV1). The server decides
// who is notified, on every server of the account, with its text; the
// desktop only applies device-local gates: a valid payload, staleness,
// membership, nothing while the window is attended (a test notification
// excepted), each id once. An unread count going up never raises one (the
// local inbox path before v1.24 is gone). A delivered alert (posted, or held
// back on purpose) is acked with this socket's id, so the server keeps the
// phone quiet on an ack from the computer in use (contract §1.3); a test
// notification's show result is acked to POST /notifications/test.
import 'dart:async';
import 'dart:convert';

import 'package:raft_client/raft_client.dart';

import '../data/notification_settings_api.dart';
import 'content_target.dart';
import 'native_notifications.dart';
import 'notification_localization.dart';

/// A validated `notification:desktop` payload.
class DesktopNotification {
  const DesktopNotification({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.serverId,
    required this.serverName,
    required this.target,
    required this.createdAt,
    required this.testId,
    required this.silent,
  });
  final String id, title, body, serverId, serverName;
  final String? subtitle, testId;
  final ContentTarget? target;
  final DateTime createdAt;
  final bool silent;

  static const _kinds = {
    'dm',
    'channel',
    'thread',
    'mention',
    'task',
    'agent',
    'reminder',
  };
  static const _events = {
    'message',
    'task_status',
    'task_assigned',
    'agent_action_required',
    'reminder_fired',
    'system_notice',
    'test',
  };

  /// `parseDesktopNotificationV1` (closed) plus the envelope additions; null
  /// for anything malformed or of an unknown version.
  static DesktopNotification? parse(
    Object? value, {
    String Function(String english)? translate,
  }) {
    if (value is! Map || value['v'] != 1) return null;
    String? str(String key) =>
        value[key] is String ? value[key] as String : null;
    final id = str('id'), title = str('title'), body = str('body');
    final serverId = str('serverId'), serverName = str('serverName');
    final createdAt = DateTime.tryParse(str('createdAt') ?? '');
    if (id == null ||
        id.isEmpty ||
        title == null ||
        title.trim().isEmpty ||
        body == null ||
        serverId == null ||
        serverId.isEmpty ||
        serverName == null ||
        str('groupKey') == null ||
        str('url') == null ||
        createdAt == null ||
        !_kinds.contains(value['kind']) ||
        !_events.contains(value['event']) ||
        value['mentioned'] is! bool ||
        value['route'] is! Map) {
      return null;
    }
    final subtitle = str('subtitle');
    final text = localizeNotificationText(
      (title: title, subtitle: subtitle, body: body),
      value['localization'],
      translate ?? (english) => english,
    );
    final testId = str('testId');
    return DesktopNotification(
      id: id,
      title: text.title,
      subtitle: text.subtitle,
      body: text.body,
      serverId: serverId,
      serverName: serverName,
      // A test opens nothing specific; everything else its conversation.
      target: testId != null ? null : _target(value),
      createdAt: createdAt,
      testId: testId,
      silent: value['silent'] == true,
    );
  }
}

/// Where a click lands: the legacy-safe `route` (a task opens its parent
/// channel). An agent route opens the app only.
ContentTarget? _target(Map value) {
  final route = value['route'] as Map;
  final server = route['serverId'];
  if (server is! String) return null;
  final message = route['messageId'] is String
      ? route['messageId'] as String
      : null;
  switch (route['type']) {
    case 'channel' || 'dm':
      final channel = route['channelId'];
      if (channel is! String || channel.isEmpty) return null;
      return ContentTarget(
        serverId: server,
        channelId: channel,
        messageId: message,
        kind: route['type'] as String,
      );
    case 'thread':
      final parentChannel = route['parentChannelId'],
          parent = route['parentMessageId'],
          thread = value['threadId'];
      if (parentChannel is! String || parent is! String) return null;
      return ContentTarget(
        serverId: server,
        channelId: parentChannel,
        messageId: message ?? parent,
        parentMessageId: parent,
        threadId: thread is String ? thread : null,
        kind: 'thread',
      );
  }
  return null;
}

/// What happened to one notification: `posted`, `held` back on purpose (the
/// window is attended, a repeat) or `dropped`. Posted and held are delivered
/// in the server's sense and acked.
enum DesktopDelivery { posted, held, dropped }

class DesktopServerNotifications {
  DesktopServerNotifications({
    required this.notifications,
    DateTime Function()? clock,
    Future<void> Function(RaftClient client, String testId, bool shown)?
    ackTest,
  }) : clock = clock ?? DateTime.now,
       _ackTest =
           ackTest ??
           ((client, testId, shown) =>
               NotificationSettingsApi(client).ackTest(testId, shown));

  final NativeNotificationService notifications;
  final DateTime Function() clock;
  final Future<void> Function(RaftClient client, String testId, bool shown)
  _ackTest;

  /// The client checks staleness tighter than the server's 10 minutes; a
  /// test notification is never stale (the settings card waits for it).
  static const staleAfter = Duration(minutes: 2);

  /// Tests this device delivered but could not confirm (page lifetime).
  static final _unconfirmed = <String>{};
  static bool isUnconfirmedTest(String testId) => _unconfirmed.contains(testId);

  final _recent = <String>{};
  RaftClient? _client;
  StreamSubscription<RaftEvent>? _events;
  bool Function(String serverId) _isMemberOf = (_) => false;

  /// Follows [client]'s events; [isMemberOf] guards a stale socket's other
  /// accounts' servers.
  void bind(RaftClient? client, {bool Function(String serverId)? isMemberOf}) {
    _isMemberOf = isMemberOf ?? (_) => false;
    if (identical(client, _client)) return;
    unawaited(_events?.cancel());
    _client = client;
    _events = client?.events.listen(_event);
  }

  bool _claim(String id) {
    if (_recent.contains(id)) return false;
    _recent.add(id);
    if (_recent.length > 500) _recent.remove(_recent.first);
    return true;
  }

  Future<void> _event(RaftEvent event) async {
    if (event.name != 'notification:desktop') return;
    final client = _client;
    if (client == null) return;
    final result = await deliver(client, event.payload);
    if (result != DesktopDelivery.dropped) {
      event.ack?.call({'received': true, 'socketId': client.socketId});
    }
  }

  /// The gate and the post. Exposed for tests.
  Future<DesktopDelivery> deliver(RaftClient client, Object? payload) async {
    final n = DesktopNotification.parse(
      payload,
      translate: notifications.localize,
    );
    if (n == null) return DesktopDelivery.dropped;
    if (n.testId == null && clock().difference(n.createdAt) > staleAfter) {
      return DesktopDelivery.dropped;
    }
    if (!_isMemberOf(n.serverId)) {
      if (n.testId != null) await _ackTest(client, n.testId!, false);
      return DesktopDelivery.dropped;
    }
    final testId = n.testId;
    if (testId != null) {
      // The person is looking at Settings on purpose: never held back.
      if (!_claim(n.id)) return DesktopDelivery.held;
      final shown = await notifications.test(
        title: n.title,
        body: n.subtitle == null ? n.body : '${n.subtitle}\n${n.body}',
      );
      await _ackTest(client, testId, shown);
      return shown ? DesktopDelivery.posted : DesktopDelivery.dropped;
    }
    // An attended window raises nothing.
    if (notifications.deliveryAllowed?.call() == false) {
      return DesktopDelivery.held;
    }
    if (!_claim(n.id)) return DesktopDelivery.held;
    final principal = client.user?.id;
    // Nothing would reach the screen (system permission off): not delivered,
    // so the server alerts the phone instead.
    if (principal == null || !notifications.enabled) {
      return DesktopDelivery.dropped;
    }
    final target = n.target;
    await notifications.show(
      title: n.subtitle == null ? n.title : '${n.title} · ${n.subtitle}',
      body: n.body,
      payload: jsonEncode({
        'origin': client.origin,
        'principal': principal,
        'serverId': n.serverId,
        'uri':
            target?.nativeUri(n.serverId).toString() ??
            'raft://v1/servers/${n.serverId}',
      }),
      quiet: n.silent,
    );
    return notifications.error == null
        ? DesktopDelivery.posted
        : DesktopDelivery.dropped;
  }

  static void noteUnconfirmed(String testId) {
    _unconfirmed.add(testId);
    if (_unconfirmed.length > 50) _unconfirmed.remove(_unconfirmed.first);
  }

  void dispose() {
    unawaited(_events?.cancel());
    _events = null;
    _client = null;
  }
}
