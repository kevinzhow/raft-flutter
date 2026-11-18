import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/platform/content_coordinator.dart';

import 'message_context_transition_test.dart' show row;
import 'task_content_slot_test.dart' show v2Task;
import 'task_surface_test.dart' show taskRoutes;
import 'workspace_source_location_contract_test.dart'
    show LocalNotifications, frames, mountPage, pageFixture, waitForPainted;

const _savedReply = {
  'messageId': 'matched-reply',
  'channelId': 'task-conv',
  'channelName': 'task-task-1',
  'channelType': 'task',
  'parentChannelId': 'c1',
  'parentChannelName': 'test',
  'parentChannelType': 'channel',
  'parentMessageId': null,
  'parentMessagePreview': null,
  'parentMessageSenderType': null,
  'parentMessageSenderId': null,
  'taskId': 'task-1',
  'taskNumber': 8,
  'taskTitle': 'Scoped actual task',
  'senderType': 'user',
  'senderId': 'alice',
  'senderName': 'Alice',
  'senderAvatarUrl': null,
  'content': 'worth keeping in the task',
  'createdAt': '2026-11-18T01:00:00Z',
  'savedAt': '2026-11-18T01:02:00Z',
  'replyCount': 2,
};

const _taskChannel = {
  'id': 'task-conv',
  'serverId': 's1',
  'name': 'task-task-1',
  'type': 'task',
  'parentChannelId': 'c1',
  'taskId': 'task-1',
  'parentMessageId': null,
  'joined': false,
};

void main() {
  testWidgets('Saved task reply copies the actual conversation link', (
    t,
  ) async {
    final (w, api) = await pageFixture(t, section: 'saved');
    final jointTask = {
      ...v2Task,
      'channelType': 'joint',
      'conversationChannelId': 'task-canonical',
      'readOnlyReason': 'historical_joint_task',
    };
    taskRoutes(api, jointTask);
    api.routes['GET /channels/saved'] = (_) => {
      'saved': [
        {..._savedReply, 'parentChannelType': 'joint'},
      ],
      'total': 1,
    };
    api.routes['GET /tasks/channel/c1'] = (_) => {
      'tasks': [jointTask],
    };
    api.routes['GET /servers'] = (_) => [w.server!.json];
    api.routes['GET /channels/c1'] = (_) => {
      ...w.channels.first.json,
      'serverId': 's1',
      'type': 'joint',
    };
    api.routes['GET /channels/task-conv'] = (_) => _taskChannel;
    api.routes['GET /messages/channel/c1'] = (_) => {'messages': []};
    api.routes['GET /messages/context/matched-reply'] = (call) {
      expect(call.queryParameters['channelId'], 'task-conv');
      return {
        'channelId': 'task-conv',
        'targetMessageId': 'matched-reply',
        'messages': [row('matched-reply', 'task-conv', 7)],
        'canonicalTarget': {
          'kind': 'thread',
          'channelId': 'c1',
          'threadChannelId': 'task-conv',
          'threadParentMessageId': null,
          'messageId': 'matched-reply',
        },
      };
    };
    final notifications = LocalNotifications();
    final coordinator = NativeContentCoordinator(
      notifications: notifications,
      appLinks: true,
    )..bindWorkspace(w);
    String? clipboard;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData')
        clipboard = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    try {
      await mountPage(t, w, false, platform: TargetPlatform.linux);
      await frames(t, () {});
      final saved = find.byKey(const ValueKey('saved-matched-reply'));
      await t.tap(
        saved,
        buttons: kSecondaryMouseButton,
        kind: PointerDeviceKind.mouse,
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Copy link'));
      await t.pumpAndSettle();
      expect(
        clipboard,
        'https://example.invalid/s/demo/channel/task-conv?msg=matched-reply',
      );
      coordinator.receiveLink(Uri.parse(clipboard!));
      await waitForPainted(t, 'matched-reply');
      expect(w.location.entityId, 'c1');
      expect(w.location.query('task'), 'c1:task:task-1');
      expect(
        api.calls.where((call) => call.path == '/tasks/task-1/conversation'),
        isEmpty,
      );
    } finally {
      await t.pumpWidget(const SizedBox.shrink());
      await t.runAsync(coordinator.dispose);
      notifications.dispose();
    }
  });

  testWidgets('Saved task reply opens in its task conversation', (t) async {
    final (w, api) = await pageFixture(t, section: 'saved');
    api.routes['GET /channels/saved'] = (_) => {
      'saved': [_savedReply],
      'total': 1,
    };
    taskRoutes(api, v2Task);
    api.routes['GET /channels/task-conv'] = (_) => _taskChannel;
    api.routes['GET /tasks/channel/c1'] = (_) => {
      'tasks': [v2Task],
    };
    api.routes['GET /messages/channel/task-conv'] = (_) => {
      'messages': [row('latest-reply', 'task-conv', 8)],
    };
    api.routes['GET /messages/context/matched-reply'] = (_) => {
      'messages': [row('matched-reply', 'task-conv', 7)],
    };
    try {
      await mountPage(t, w, false);
      await frames(t, () {});
      await t.tap(find.byKey(const ValueKey('saved-matched-reply')));
      await frames(t, () {});
      expect(w.location.query('task'), 'c1:task:task-1');
      await waitForPainted(t, 'matched-reply');
      final context = api.calls.singleWhere(
        (call) => call.path == '/messages/context/matched-reply',
      );
      expect(context.queryParameters['channelId'], 'task-conv');
    } finally {
      await t.pumpWidget(const SizedBox.shrink());
    }
  });
}
