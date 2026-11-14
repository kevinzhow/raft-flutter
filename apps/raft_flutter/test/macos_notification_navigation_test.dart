import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/workspace_controller.dart';
import 'package:raft_flutter/platform/background_inbox.dart';
import 'package:raft_flutter/platform/background_notifications.dart';
import 'package:raft_flutter/platform/content_coordinator.dart';
import 'package:raft_flutter/platform/native_notifications.dart';
import 'package:raft_ui/raft_ui.dart';

import 'chat_focus_receipt_test.dart' show paintedMessage;
import 'message_presentation_test.dart' show MessageAdapter;
import 'native_notifications_test.dart'
    show MacPermissionFixture, NotificationPluginFixture;
import 'notification_tap_navigation_test.dart' show notificationRoutes;
import 'workspace_activity_activation_test.dart' show message;
import 'workspace_source_location_contract_test.dart'
    show frames, mountPage, pageFixture;

// Exercises the production macOS inbox -> OS payload -> notification callback
// -> desktop WorkspaceView chain. The OS plugin/HTTP are isolated fixtures;
// these tests do not claim a native macOS banner was clicked.
void _routes(WorkspaceController w, MessageAdapter api) {
  notificationRoutes(w, api);
  final dm = RaftChannel({
    'id': 'd1',
    'serverId': 's1',
    'name': 'Direct fixture',
    'type': 'dm',
    'joined': true,
  });
  w.dms = [dm];
  api.routes['GET /channels/d1'] = (_) => dm.json;
  api.routes['GET /messages/context/direct'] = (_) => {
    'messages': [message('direct', 'd1')],
  };
  api.routes['POST /channels/d1/read'] = (_) => {};
  api.routes['GET /servers/s1/notification-settings'] = (_) => {
    'serverPushMode': 'all',
    'serverPushMuted': false,
  };
}

Map<String, dynamic> _row(String kind) => {
  'kind': kind,
  'unreadCount': 1,
  'hasMention': kind == 'channel',
  'firstMentionMessageId': kind == 'channel' ? 'm2' : null,
  if (kind == 'thread') ...{
    'parentChannelId': 'c2',
    'parentChannelName': 'Thread fixture',
    'parentMessageId': 'parent',
    'threadChannelId': 't1',
    'latestActivityMessageId': 'reply',
    'latestActivityPreview': 'Thread fixture reply',
    'lastActivityAt': DateTime.now().toUtc().toIso8601String(),
    'isFollowing': true,
  } else ...{
    'channelId': kind == 'dm' ? 'd1' : 'c2',
    'channelName': 'Message fixture',
    'lastMessageId': kind == 'dm' ? 'direct' : 'm2',
    'lastMessagePreview': 'Message fixture body',
    'lastMessageAt': DateTime.now().toUtc().toIso8601String(),
  },
};

NotificationResponse _response(String payload) => NotificationResponse(
  id: 1,
  payload: payload,
  notificationResponseType: NotificationResponseType.selectedNotification,
);

Future<void> _until(WidgetTester t, bool Function() ready) async {
  for (var attempt = 0; attempt < 30 && !ready(); attempt++) {
    await frames(t, () {});
  }
  expect(ready(), isTrue);
  await frames(t, () {});
}

void main() {
  // Linux follows the macOS desktop rules through the same inbox chain; only
  // the OS plugin (freedesktop Notify instead of UNUserNotificationCenter)
  // differs, so one body proves both.
  for (final platform in [TargetPlatform.macOS, TargetPlatform.linux]) {
    final name = platform == TargetPlatform.macOS ? 'macOS' : 'Linux';
    for (final kind in ['channel', 'dm', 'thread']) {
      // A freedesktop notification cannot launch a closed app (the daemon
      // only signals a running client), so there is no Linux cold launch.
      for (final cold
          in platform == TargetPlatform.macOS ? [false, true] : [false]) {
        testWidgets(
          '$name ${cold ? 'launch' : 'background inbox'} $kind notification reaches its desktop message with one navigation',
          (t) async {
            final (w, api) = await pageFixture(
              t,
              section: cold ? 'home' : 'computers',
            );
            _routes(w, api);
            final plugin = NotificationPluginFixture()
              ..mac = (MacPermissionFixture()..allowed = true);
            // Darwin reports the authorization result; the freedesktop plugin
            // reports a successful start.
            plugin.initialized.complete(platform == TargetPlatform.linux);
            final notifications = NativeNotificationService(
              plugin: plugin,
              platform: platform,
            );
            final coordinator = NativeContentCoordinator(
              notifications: notifications,
              links: const Stream.empty(),
            );
            final presented = <String>[];
            t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
              const MethodChannel('app.raft/window'),
              (call) async {
                if (call.method == 'isActive') return true;
                presented.add(call.method);
                return null;
              },
            );
            addTearDown(
              () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
                const MethodChannel('app.raft/window'),
                null,
              ),
            );
            final row = _row(kind);
            final alert = BackgroundInboxAlert.fromRow(
              row,
              's1',
              DateTime.utc(2000),
            )!;
            final payload = notificationPayload(w.client, alert.target);
            if (cold) {
              plugin.launch = NotificationAppLaunchDetails(
                true,
                notificationResponse: _response(payload),
              );
            }
            await mountPage(t, w, false);
            if (!cold && kind == 'dm') {
              api.routes['GET /messages/context/old-parent'] = (_) => {
                'messages': [message('old-parent', 'c1')],
              };
              api.routes['GET /messages/context/old-reply'] = (_) => {
                'messages': [message('old-reply', 'old-thread')],
              };
              api.routes['POST /channels/old-thread/read'] = (_) => {};
              w.section = 'chat';
              var opened = false;
              final opening = w
                  .openThreadIdentity(
                    parentChannelId: 'c1',
                    parentMessageId: 'old-parent',
                    focusedMessageId: 'old-reply',
                    initialThreadChannelId: 'old-thread',
                  )
                  .whenComplete(() => opened = true);
              await _until(t, () => opened);
              await opening;
              expect(paintedMessage(t, 'old-reply'), isNotNull);
              expect(find.byType(RaftThreadHeader), findsOneWidget);
            }
            final before = w.location;
            final index = w.navigation.index;
            final observed = <String>[];
            void observe() => observed.add(w.location.toString());
            w.addListener(observe);
            var initialized = false;
            final starting = coordinator.init().whenComplete(
              () => initialized = true,
            );
            await _until(t, () => initialized);
            await starting;
            // initialize captures the cold target before clearing old OS alerts.
            expect(w.location, before);
            expect(plugin.cancellations, 1);
            coordinator.bindWorkspace(w);
            if (!cold) {
              await _until(t, () => notifications.enabled);
              coordinator.didChangeAppLifecycleState(AppLifecycleState.paused);
              w.setForeground(false);
              await frames(t, () {});
              await coordinator.desktop!.prepared;
              w.activityUnread.acceptWindow({
                'items': [_row(kind)],
              }, scope: w.activityUnread.scope);
              await _until(t, () => plugin.sent.isNotEmpty);
              expect(plugin.sent, hasLength(1));
              expect(
                jsonDecode(plugin.sent.single!)['uri'],
                jsonDecode(payload)['uri'],
              );
              coordinator.didChangeAppLifecycleState(AppLifecycleState.resumed);
              w.setForeground(true);
              plugin.onResponse!(_response(plugin.sent.single!));
              // The window is raised after the desktop's focus token (if
              // any) has been awaited.
              await _until(
                t,
                () => platform != TargetPlatform.linux || presented.isNotEmpty,
              );
              // A click raises the window on Linux (the runner presents it);
              // the other desktops activate their app through the OS.
              expect(
                presented,
                platform == TargetPlatform.linux ? ['present'] : isEmpty,
              );
            }
            final id = kind == 'thread'
                ? 'reply'
                : kind == 'dm'
                ? 'direct'
                : 'm2';
            await _until(t, () => paintedMessage(t, id) != null);
            expect(
              w.location.uri.path,
              kind == 'dm' ? '/s/demo/dm/d1' : '/s/demo/channel/c2',
            );
            expect(w.location.messageId, id);
            expect(w.navigation.index, cold ? index : index + 1);
            if (!cold) expect(w.navigation.entries[index], before);
            expect(w.error, isNull);
            if (kind == 'thread') {
              expect(w.location.query('thread'), 'c2:parent');
              expect(w.threadIdentity?.parentMessageId, 'parent');
              expect(find.byType(RaftThreadHeader), findsOneWidget);
              expect(
                observed.where(
                  (uri) => Uri.parse(uri).path == '/s/demo/channel/c2',
                ),
                everyElement(contains('thread=c2%3Aparent')),
                reason:
                    'A notification never publishes an intermediate channel page.',
              );
            } else {
              expect(w.location.thread, isNull);
              expect(find.byType(RaftThreadHeader), findsNothing);
            }
            w.removeListener(observe);
            var closed = false;
            final closing = coordinator.dispose().whenComplete(
              () => closed = true,
            );
            await _until(t, () => closed);
            await closing;
            notifications.dispose();
            await t.pumpWidget(const SizedBox());
            await t.pumpAndSettle();
            expect(t.takeException(), isNull);
          },
        );
      }
    }
  }
}
