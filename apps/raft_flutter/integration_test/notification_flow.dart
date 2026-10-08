import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/main.dart';
import 'package:raft_flutter/platform/content_coordinator.dart';

/// Real other-human DM -> server eligible event -> Android notification manager
/// -> host-driven real notification shade click -> main's fresh context route.
Future<void> verifyNativeNotificationFlow(
  WidgetTester tester,
  WorkspaceController w, {
  required String otherEmail,
  required String otherPassword,
  required String reportFolder,
  required Future<void> Function(String) capture,
}) async {
  if (!Platform.isAndroid) return;
  final dynamic appState = tester.state(find.byType(RaftApp));
  final NativeContentCoordinator content = appState.content;
  final service = content.notifications;
  final enabledBefore = service.enabled;
  final selectedBefore = w.channel;
  final foregroundBefore = w.foreground;
  final server = w.client.serverId!;
  final marker = File('$reportFolder/raft-notification-click.json');
  final sender = RaftClient(
    origin: w.client.origin,
    sessionStore: MemorySessionStore(),
  );
  final prefs = await w.client.get('/servers/$server/notification-settings');
  StreamSubscription<RaftEvent>? subscription;
  Map? event;
  final proof =
      'Native OS notification proof ${DateTime.now().microsecondsSinceEpoch}';
  try {
    await w.client.patch(
      '/servers/$server/notification-settings',
      data: {'serverPushMode': 'all'},
    );
    await sender.login(otherEmail, otherPassword);
    sender.selectServer(server);
    final dm = await sender.post(
      '/channels/dm',
      data: {'userId': w.client.user!.id},
    );
    final channel = RaftChannel(Map<String, dynamic>.from(dm));
    await w.refreshChannels();
    await service.requestEnable(true);
    expect(
      service.enabled,
      true,
      reason: 'Host must pregrant permission for the owned test package.',
    );
    subscription = w.client.events.listen((e) {
      if (e.name == 'notification:push' &&
          e.payload is Map &&
          e.payload['channelId'] == channel.id &&
          e.payload['body'] is String &&
          (e.payload['body'] as String).contains(proof)) {
        event = e.payload as Map;
      }
    });
    w.setForeground(false);
    final message = await sender.send(channel.id, proof);
    for (var i = 0; i < 300 && event == null; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(
      event,
      isNotNull,
      reason: 'A genuine backend eligible notification event is required.',
    );
    expect(event!['messageId'], message.id);
    ActiveNotification? posted;
    for (var i = 0; i < 300 && posted == null; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      final active = await FlutterLocalNotificationsPlugin()
          .getActiveNotifications();
      posted = active
          .where(
            (n) =>
                n.channelId == 'raft_messages_v1' &&
                (n.body?.contains(proof) ?? false),
          )
          .firstOrNull;
    }
    expect(
      posted,
      isNotNull,
      reason: 'Android NotificationManager must contain the real posted notification.',
    );
    await marker.writeAsString(jsonEncode({'body': proof}), flush: true);
    for (
      var i = 0;
      i < 600 &&
          (w.channel?.id != channel.id ||
              w.highlightedMessageId != message.id ||
              w.channelLoading ||
              !w.messages.any((m) => m.id == message.id));
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(
      w.channel?.id,
      channel.id,
      reason: 'Host must click the actual OS shade notification.',
    );
    expect(w.highlightedMessageId, message.id);
    expect(w.messages.any((m) => m.id == message.id), true);
    await capture('linux-notification-message-navigation');
  } finally {
    if (await marker.exists()) await marker.delete();
    await subscription?.cancel();
    await service.requestEnable(enabledBefore);
    w.setForeground(foregroundBefore);
    if (selectedBefore != null) await w.selectChannel(selectedBefore);
    await w.client.patch(
      '/servers/$server/notification-settings',
      data: prefs is Map && prefs['serverPushMode'] is String
          ? {'serverPushMode': prefs['serverPushMode']}
          : {
              'serverPushMuted':
                  prefs is Map && prefs['serverPushMuted'] == true,
            },
    );
    await sender.dispose();
  }
}
