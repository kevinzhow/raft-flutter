import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'channel_activity_chat_test.dart' show activityRow;
import 'message_presentation_test.dart' show fixture;

void main() {
  for (final (platform, size) in [
    (TargetPlatform.android, const Size(856, 944)),
    (TargetPlatform.android, const Size(944, 856)),
    (TargetPlatform.linux, const Size(390, 844)),
  ]) {
    testWidgets(
      'activity-only row selection, copy and inline thread $platform $size',
      (t) async {
        final (w, api) = (await t.runAsync(() => fixture('owner')))!;
        addTearDown(w.dispose);
        addTearDown(() => t.pumpWidget(const SizedBox()));
        await t.binding.setSurfaceSize(size);
        addTearDown(() => t.binding.setSurfaceSize(null));
        w.channel = RaftChannel({
          'id': 'c1',
          'type': 'channel',
          'joined': true,
          'threadSort': 'activity',
        });
        w.channels = [w.channel!];
        api.routes['POST /feature-flags/evaluate'] = (_) => {
          'evaluations': [
            {'key': 'channel_thread_sort_v0', 'enabled': true},
          ],
        };
        api.routes['GET /messages/channel/c1/by-activity'] = (_) => {
          'messages': [activityRow('paged', 1, '2026-11-01T00:00:00Z')],
          'threadSummariesByParentMessageId': {
            'paged': {
              'threadChannelId': 'thread',
              'replyCount': 1,
              'latestReplies': [
                {
                  'messageId': 'reply',
                  'senderType': 'user',
                  'senderName': 'Bob',
                  'preview': 'Activity reply',
                },
              ],
            },
          },
        };
        api.routes['GET /channels/c1/threads/paged'] = (_) => {
          'threadChannelId': 'thread',
        };
        api.routes['GET /messages/channel/thread'] = (_) => {'messages': []};
        final writes = <String>[];
        t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              writes.add((call.arguments as Map)['text'] as String);
            }
            return null;
          },
        );
        addTearDown(
          () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme().copyWith(platform: platform),
            home: Scaffold(body: RaftChatView(controller: w)),
          ),
        );
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await t.pumpAndSettle();
        expect(w.messageDomain.messages, isEmpty);
        final target = find.byKey(const ValueKey('message-paged'));
        expect(target, findsOneWidget);
        if (platform == TargetPlatform.linux) {
          await t.tapAt(
            t.getCenter(target),
            kind: PointerDeviceKind.mouse,
            buttons: kSecondaryMouseButton,
          );
        } else {
          final rect = t.getRect(target);
          await t.longPressAt(Offset(rect.left + 2, rect.center.dy));
        }
        await t.pumpAndSettle();
        await t.tap(find.text('Select message'));
        await t.pumpAndSettle();
        expect(find.text('1 selected'), findsOneWidget);
        await t.tap(find.byTooltip('More'));
        await t.pumpAndSettle();
        await t.tap(find.text('Copy MD'));
        await t.pumpAndSettle();
        expect(writes.single, contains('Forum paged'));
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await t.pumpAndSettle();
        expect(find.byType(RaftSelectionToolbar), findsNothing);
        await t.tap(find.byKey(const ValueKey('inline-thread-paged')));
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await t.pumpAndSettle();
        expect(w.messageDomain.state.threadParent?.id, 'paged');
        expect(w.threadChannelId, 'thread');
        expect(
          api.calls.where((c) => c.path == '/messages/context/paged'),
          isEmpty,
        );
        expect(w.messageDomain.messages, isEmpty);
      },
    );
  }
}
