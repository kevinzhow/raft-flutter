import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/task_surface.dart';

import 'app_global_server_selector_test.dart' show RootFixture;
import 'message_context_transition_test.dart' show row;
import 'task_content_slot_test.dart' show v2Task;

const _discussion = 'task-conv';

Map<String, dynamic> _reply(String id, int seq, String content) => {
  ...row(id, _discussion, seq),
  'seq': seq,
  'content': content,
  'senderId': 'bob',
  'senderType': 'user',
  'senderName': 'Bob',
  'createdAt': '2026-11-18T12:00:${seq.toString().padLeft(2, '0')}Z',
  'conversationContext': {
    'channelType': 'task',
    'taskId': 'task-1',
    'parentChannelId': 'ca',
  },
};

Future<void> _setLifecycle(WidgetTester t, AppLifecycleState state) =>
    t.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.lifecycle.name,
      const StringCodec().encodeMessage(state.toString()),
      null,
    );

void main() {
  for (final viaReplay in [true, false]) {
    testWidgets(
      viaReplay
          ? 'Activity task card recovers a late replay and resumes live'
          : 'Activity task card catches up from its local gap without replay',
      (t) async {
        final f = RootFixture();
        final task = {
          ...v2Task,
          'channelId': 'ca',
          'conversationReplyCount': 1,
        };
        final existing = _reply('existing', 14, 'Existing discussion reply');
        final missedBody = viaReplay
            ? 'Reply recovered by replay'
            : 'Reply recovered by local gap';
        final missed = _reply('missed', viaReplay ? 12 : 15, missedBody);
        f.overrides.addAll({
          'GET /channels/inbox': (_) => {
            'items': [
              {
                'kind': 'task',
                'threadChannelId': _discussion,
                'parentChannelId': 'ca',
                'parentChannelName': 'general-a',
                'parentChannelType': 'channel',
                'parentMessageId': null,
                'taskId': 'task-1',
                'taskTitle': task['title'],
                'taskNumber': 8,
                'taskStatus': 'todo',
                'latestActivityPreview': 'Task row preview',
                'latestActivityMessageId': 'existing',
                'latestActivitySeq': '14',
                'lastActivityAt': existing['createdAt'],
                'replyCount': 1,
                'unreadCount': 0,
                'isFollowing': true,
              },
            ],
            'totalCount': 1,
            'totalUnreadCount': 0,
            'hasMore': false,
          },
          'GET /tasks/task-1': (_) => {'task': task},
          'GET /tasks/channel/ca': (_) => {
            'tasks': [task],
          },
          'GET /tasks/channel/ca/number/8': (_) => {'task': task},
          'GET /tasks/task-1/history': (_) => {'events': []},
          'GET /channels/ca': (_) => {
            'id': 'ca',
            'name': 'general-a',
            'type': 'channel',
            'serverId': 'a',
            'joined': true,
            'latestSeq': '1',
          },
          'GET /channels/$_discussion': (_) => {
            'id': _discussion,
            'type': 'task',
            'serverId': 'a',
            'taskId': 'task-1',
            'parentChannelId': 'ca',
          },
          'GET /messages/channel/$_discussion': (_) => {
            'messages': [existing],
            'hasMore': false,
            'hasNewer': false,
          },
          'GET /messages/sync': (r) =>
              !viaReplay &&
                  r.queryParameters['channel_id'] == _discussion &&
                  r.queryParameters['since_seq'] == '14'
              ? [missed]
              : [],
          'POST /channels/$_discussion/read': (_) => {},
          'POST /channels/$_discussion/read-all': (_) => {},
          'POST /feature-flags/evaluate': (_) => {'evaluations': []},
          'GET /announcements/active': (_) => {'announcements': []},
        });
        await f.mount(t, 'light', 1440, uri: Uri.parse('/s/alpha/activity'));
        try {
          final activityRow = find.byKey(
            const ValueKey('activity-thread-$_discussion'),
          );
          expect(activityRow.hitTestable(), findsOneWidget);
          await t.tap(activityRow, kind: PointerDeviceKind.mouse);
          await f.flush(t);

          final card = find.byType(SourceTaskSurface);
          final timeline = find.descendant(
            of: card,
            matching: find.byType(RaftChatView),
          );
          Finder reply(String text) => find.descendant(
            of: timeline,
            matching: find.text(text, findRichText: true),
          );
          expect(card, findsOneWidget);
          expect(reply('Existing discussion reply'), findsOneWidget);
          expect(reply(missedBody), findsNothing);
          final mountedTimeline = identityHashCode(t.element(timeline));
          f.client.event('message:updated', {
            ...existing,
            'content': 'Live edit of existing reply',
          });
          await f.flush(t);
          expect(reply('Live edit of existing reply'), findsOneWidget);

          await _setLifecycle(t, AppLifecycleState.paused);
          f.client.event('disconnected', null);
          await f.flush(t);
          expect(f.workspace(t).foreground, isFalse);
          f.client.joinedChannels.clear();
          await _setLifecycle(t, AppLifecycleState.resumed);
          f.client.event('connected', null);
          f.client.event('rooms:joined', null);
          await f.flush(t);
          expect(f.workspace(t).foreground, isTrue);
          expect(card, findsOneWidget);
          expect(timeline, findsOneWidget);
          expect(identityHashCode(t.element(timeline)), mountedTimeline);
          expect(reply('Live edit of existing reply'), findsOneWidget);

          void replay() => f.client.injectedEvents.add(
            RaftEvent.fromSocket('sync:resume:response', {
              'currentSeq': 16,
              'hasMore': false,
              'messages': [
                missed,
                existing,
                {
                  ...row('unrelated', 'ca', 16),
                  'seq': 16,
                  'content': 'Reply from another scope',
                },
              ],
            }),
          );
          if (viaReplay) {
            expect(reply(missedBody), findsNothing);
            replay();
            await f.flush(t);
          }
          expect(reply(missedBody), findsOneWidget);
          expect(identityHashCode(t.element(timeline)), mountedTimeline);
          expect(reply('Live edit of existing reply'), findsOneWidget);
          expect(reply('Existing discussion reply'), findsNothing);
          expect(reply('Reply from another scope'), findsNothing);
          if (viaReplay) {
            replay();
            await f.flush(t);
            expect(reply(missedBody), findsOneWidget);
          }

          expect(f.client.joinedChannels, [_discussion]);
          f.client.event(
            'message:new',
            _reply('live-after-reconnect', 17, 'Live reply after reconnect'),
          );
          await f.flush(t);
          expect(reply('Live reply after reconnect'), findsOneWidget);
        } finally {
          await f.close(t);
        }
      },
    );
  }
}
