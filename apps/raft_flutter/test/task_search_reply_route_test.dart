import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/raft_navigation_history.dart';
import 'package:raft_flutter/features/quick_switcher.dart';

import 'message_context_transition_test.dart' show row;
import 'task_content_slot_test.dart' show v2Task;
import 'task_surface_test.dart' show taskRoutes;
import 'workspace_source_location_contract_test.dart'
    show frames, mountPage, pageFixture, waitForPainted;

const _searchHit = {
  'id': 'matched-reply',
  'seq': 7,
  'channelId': 'task-conv',
  'channelName': 'task-task-1',
  'channelType': 'task',
  'channelArchivedAt': null,
  'threadId': null,
  'parentMessageId': null,
  'parentMessageContent': null,
  'parentChannelId': 'c1',
  'parentChannelName': 'test',
  'parentChannelType': 'channel',
  'parentChannelArchivedAt': null,
  'taskId': 'task-1',
  'taskNumber': 8,
  'taskTitle': 'Scoped actual task',
  'senderType': 'user',
  'senderId': 'alice',
  'senderName': 'Alice',
  'senderAvatarUrl': null,
  'externalMessage': null,
  'content': 'needle in the task',
  'snippet': 'needle in the task',
  'createdAt': '2026-11-18T01:00:00Z',
};

void main() {
  testWidgets('Search shows the task title from the result', (t) async {
    final (w, api) = await pageFixture(t, section: 'search');
    w.navigation.navigate(
      RaftLocation.parse('/s/demo/search?q=needle'),
      kind: RaftNavigationKind.replace,
    );
    api.routes['GET /messages/search'] = (_) => {
      'results': [_searchHit],
      'hasMore': false,
    };
    await mountPage(t, w, false);
    await frames(t, () {});
    final hit = find.byKey(const ValueKey('search-message:matched-reply'));
    expect(
      find.descendant(
        of: hit,
        matching: find.textContaining('Scoped actual task'),
      ),
      findsOneWidget,
    );
  });

  for (final (platform, size) in [
    (TargetPlatform.linux, const Size(390, 844)),
    (TargetPlatform.android, const Size(856, 944)),
    (TargetPlatform.android, const Size(944, 856)),
  ]) {
    testWidgets('Search task reply opens in context on $platform $size', (
      t,
    ) async {
      final (w, api) = await pageFixture(t, section: 'search');
      w.navigation.navigate(
        RaftLocation.parse('/s/demo/search?q=needle'),
        kind: RaftNavigationKind.replace,
      );
      api.routes['GET /messages/search'] = (_) => {
        'results': [_searchHit],
        'hasMore': false,
      };
      taskRoutes(api, v2Task);
      api.routes['GET /tasks/channel/c1'] = (_) => {
        'tasks': [v2Task],
      };
      api.routes['GET /messages/channel/task-conv'] = (_) => {
        'messages': [row('latest-reply', 'task-conv', 8)],
      };
      api.routes['GET /messages/context/matched-reply'] = (_) => {
        'messages': [row('matched-reply', 'task-conv', 7)],
      };
      await mountPage(
        t,
        w,
        false,
        width: size.width,
        height: size.height,
        platform: platform,
      );
      await frames(t, () {});
      final hit = find.byKey(const ValueKey('search-message:matched-reply'));
      await t.tap(hit);
      await waitForPainted(t, 'matched-reply');
      expect(w.location.query('task'), 'c1:task:task-1');
      final context = api.calls.singleWhere(
        (call) => call.path == '/messages/context/matched-reply',
      );
      expect(context.queryParameters['channelId'], 'task-conv');
    });
  }

  testWidgets('Quick Search opens the task reply over the current chat', (
    t,
  ) async {
    final (w, api) = await pageFixture(t, section: 'chat');
    api.routes['GET /messages/search'] = (_) => {
      'results': [_searchHit],
    };
    taskRoutes(api, v2Task);
    api.routes['GET /tasks/channel/c1'] = (_) => {
      'tasks': [v2Task],
    };
    api.routes['GET /messages/channel/c1'] = (_) => {'messages': []};
    api.routes['GET /messages/channel/task-conv'] = (_) => {'messages': []};
    api.routes['GET /messages/context/matched-reply'] = (_) => {
      'messages': [row('matched-reply', 'task-conv', 7)],
    };
    await mountPage(t, w, false, platform: TargetPlatform.linux);
    await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.keyK);
    await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await t.pumpAndSettle();
    expect(find.byType(QuickSwitcher), findsOneWidget);
    await t.enterText(find.byType(TextField).last, 'needle');
    await t.pump(const Duration(milliseconds: 300));
    await frames(t, () {});
    await t.tap(
      find.byKey(const ValueKey('quick-switcher-message:matched-reply')),
    );
    expect(w.location.query('task'), 'c1:task:task-1');
    await waitForPainted(t, 'matched-reply');
    expect(w.channel?.id, 'c1');
  });
}
