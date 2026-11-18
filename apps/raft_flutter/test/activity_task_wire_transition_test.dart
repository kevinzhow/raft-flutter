import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/data/activity_filter_choice.dart';
import 'package:raft_flutter/data/raft_location.dart';
import 'package:raft_flutter/data/resource_snapshot_cache.dart';
import 'package:raft_flutter/features/message_task_actions.dart';

import 'support/activity_list_harness.dart';

const _scope = 'local-task-conversation';
const _key = 'activity-thread-$_scope';
const _title = 'Task from the next page';

Map<String, dynamic> _servedTask() => {
  'kind': 'task',
  'threadChannelId': _scope,
  'parentMessageId': null,
  'parentChannelId': 'ch1',
  'parentChannelName': 'Channel 1',
  'parentChannelType': 'channel',
  'parentMessagePreview': _title,
  'taskId': 'task-7',
  'taskTitle': _title,
  'taskNumber': 7,
  'taskStatus': 'in_progress',
  'latestActivityMessageId': 'task-reply',
  'latestActivityPreview': 'Existing task reply',
  'latestActivitySeq': '1010',
  'doneFrontierSeq': '1010',
  'lastActivityAt': '2026-10-12T12:05:00Z',
  'lastReplyAt': '2026-10-12T12:05:00Z',
  'firstUnreadMessageId': 'task-reply',
  'unreadCount': 1,
  'replyCount': 1,
  'isFollowing': true,
};

void main() {
  late ActivityClient client;
  late ActivityWorkspace w;
  setUp(() => (client, w) = activityFixture());
  tearDown(() async {
    w.dispose();
    await client.dispose();
  });

  test('the shared inbox projects a read over the local task scope', () async {
    await client.login('fixture', 'fixture');
    client.selectServer('s1');
    w.inbox = [
      {
        ..._servedTask(),
        'readState': {
          'kind': 'present',
          'readStateVersion': 1,
          'maxReadSeq': '1009',
          'latestActivity': {'messageId': 'task-reply', 'seq': '1010'},
        },
      },
    ];
    final store = w.activityUnread;
    await store.refresh();
    expect(store.totalUnreadCount, 1);

    final read = {
      'serverId': 's1',
      'scopeId': _scope,
      'maxReadSeq': 1010,
      'readStateVersion': 2,
      'unreadCount': 0,
    };
    w.readState.consumeUpdate(read, serverId: 's1', principalId: 'alice');
    client.emit('read_state:updated', read);
    expect(store.totalUnreadCount, 0);
    final seed = store.windowSince(0)!;
    final item = (seed['items'] as List).single as Map;
    expect(item['firstUnreadMessageId'], isNull);
  });

  testWidgets(
    'a paged task accepts a local reply and opens as read with task v2 off',
    (t) async {
      client.responses['POST /feature-flags/evaluate'] = {
        'evaluations': [
          {'key': taskV2ConversationsFlag, 'enabled': false},
        ],
      };
      expect(await TaskV2ConversationsFlag.of(w).ensure(), isFalse);
      client.responses['POST /channels/$_scope/read-all'] = {
        'maxReadSeq': 1011,
        'readStateVersion': 1,
      };
      w.navigation.navigate(
        RaftLocation.at(
          serverSlug: w.location.serverSlug,
          route: RaftRoute.activity,
        ),
      );
      w.inbox = [
        for (var i = 0; i < activityPageSize; i++) dayRow(i),
        _servedTask(),
        _servedTask(),
      ];
      final dynamic state = await mountActivity(t, w, desktop);
      await state.load(append: true);
      await t.pumpAndSettle();
      expect(w.inboxQueries.last['offset'], activityPageSize);

      client.emit('message:new', {
        'id': 'new-task-reply',
        'channelId': _scope,
        'conversationContext': {'channelType': 'task'},
        'seq': '1011',
        'content': 'New reply in the local task conversation',
        'senderId': 'bob',
        'senderType': 'user',
        'senderName': 'Bob',
        'createdAt': '2026-10-12T12:06:00Z',
      });
      await t.pump();
      final item = row(_key);
      expect(item, findsOneWidget);
      final loaded = state.rows as List<Map<String, dynamic>>;
      expect(
        loaded.where((row) => row['threadChannelId'] == _scope),
        hasLength(1),
      );
      expect(
        find.descendant(
          of: item,
          matching: find.textContaining(
            'New reply in the local task conversation',
            findRichText: true,
          ),
        ),
        findsOneWidget,
      );
      expect(
        t.getTopLeft(item).dy,
        lessThan(t.getTopLeft(row('activity-channel-ch0')).dy),
      );
      await t.tap(item);
      await t.pumpAndSettle();
      expect(w.location.uri.queryParameters['open'], 'task:task-7');
      expect(w.location.uri.queryParameters['task'], 'ch1:task:task-7');
      expect(client.posts, contains('POST /channels/$_scope/read-all'));
      expect(client.posts, isNot(contains('POST /channels/ch1/read-all')));
    },
  );

  testWidgets(
    'a scoped refresh accepts task facets and restores raw cached windows',
    (t) async {
      w.inbox = [_servedTask()];
      final dynamic state = await mountActivity(t, w, desktop);
      final allView = state.rowsView as String;
      state.chooseActivityFilter(ActivityFilterChoice.pinned);
      await t.pumpAndSettle();
      expect(w.inboxQueries.any((q) => q['scope'] == 'pinned'), isTrue);
      expect(w.inboxQueries.where((q) => q['scope'] == null), hasLength(2));
      final facets = state.acceptedActivityItems as List<Map<String, dynamic>>;
      expect(facets.single['conversationKind'], 'task');

      final identity = state.identityAuthority as String;
      await t.pumpWidget(const SizedBox.shrink());
      final snapshot = w.resourceSnapshots.read<ResourceSnapshot>(
        'activity',
        identity,
      )!;
      w.resourceSnapshots.write(
        'activity',
        snapshot.replaceRows(
          rows: [_servedTask()],
          totalCount: snapshot.totalCount,
          viewWindows: {
            ...snapshot.viewWindows,
            allView: ResourceViewWindow(
              rows: [_servedTask()],
              hasMore: false,
              totalCount: 1,
              totalUnreadCount: 1,
            ),
          },
        ),
      );
      final held = w.hold = Completer<void>();
      final mounting = mountActivity(t, w, desktop);
      try {
        final dynamic restored = await mounting;
        expect(row(_key), findsOneWidget);
        restored.chooseActivityFilter(ActivityFilterChoice.all);
        await t.pump();
        expect(row(_key), findsOneWidget);
      } finally {
        held.complete();
      }
      await t.pumpAndSettle();
    },
  );
}
