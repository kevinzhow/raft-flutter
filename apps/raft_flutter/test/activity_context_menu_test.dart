import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'activity_incremental_refresh_test.dart'
    show activityFixture, channelRow;
import 'activity_follow_ack_test.dart' show thread;

Map<String, dynamic> pendingMention() => {
  'kind': 'mention_action',
  'id': 'pending-mention',
  'channelId': 'ch1',
  'channelName': 'Channel 1',
  'channelType': 'channel',
  'messageId': 'mention-message',
  'messagePreview': 'Pending mention',
  'createdAt': '2026-10-17T00:00:00Z',
  'pendingMentionActions': [],
  'unreadCount': 0,
  'hasMention': false,
};

void main() {
  for (final (dark) in [(false), (true)]) {
    for (final touch in [false, true]) {
      for (final (label, row, labels) in [
        ('unread channel', channelRow(1, unread: 2), ['Mark as Read', 'Done']),
        ('read channel', channelRow(1), ['Mark as Unread', 'Done']),
        (
          'direct message',
          {...channelRow(1), 'kind': 'dm', 'channelType': 'dm'},
          ['Mark as Unread', 'Done'],
        ),
        ('followed thread', thread(), ['Mark as Read', 'Done', 'Unfollow']),
        ('unfollowed thread', thread(following: false), ['Done', 'Follow']),
        ('pending mention', pendingMention(), ['Mark as Unread', 'Done']),
      ]) {
        testWidgets(
          '${dark ? 'dark' : 'light'} ${touch ? 'touch long press' : 'mouse right click'} $label matches Web menu',
          (tester) async {
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = Size(touch ? 390 : 1000, 850);
            addTearDown(tester.view.resetDevicePixelRatio);
            addTearDown(tester.view.resetPhysicalSize);
            final (client, w) = activityFixture();
            addTearDown(() async {
              await tester.pumpWidget(const SizedBox.shrink());
              await tester.pump();
              w.dispose();
              await client.dispose();
            });
            w.inbox = [Map.of(row)];
            var opened = 0;
            await tester.pumpWidget(
              MaterialApp(
                theme: raftTheme(dark: dark),
                home: Scaffold(
                  body: ResourceView(
                    controller: w,
                    section: 'activity',
                    activitySidebarEnabled: true,
                    onMessage: (_, _) async {
                      opened++;
                    },
                    onActivityItem: (_) async {
                      opened++;
                    },
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final before = client.posts.length;
            final card = find.byType(RaftConversationCard);
            expect(card, findsOneWidget);
            if (touch) {
              await tester.longPress(card);
            } else {
              await tester.tap(
                card,
                buttons: kSecondaryMouseButton,
                kind: PointerDeviceKind.mouse,
              );
            }
            await tester.pumpAndSettle();
            expect(find.byType(RaftSidebarContextMenu), findsOneWidget);
            expect(
              tester
                  .widgetList<RaftMenuButtonItem>(
                    find.byType(RaftMenuButtonItem),
                  )
                  .map((item) => item.label),
              labels,
            );
            expect(
              opened,
              0,
              reason: 'opening the menu must not activate the row',
            );
            expect(
              client.posts.length,
              before,
              reason: 'opening sends no mutation',
            );
            final rect = tester.getRect(find.byType(RaftSidebarContextMenu));
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(
              rect.right,
              lessThanOrEqualTo(tester.view.physicalSize.width),
            );
            expect(rect.top, greaterThanOrEqualTo(0));
            expect(
              rect.bottom,
              lessThanOrEqualTo(tester.view.physicalSize.height),
            );
            if (touch) {
              await tester.tapAt(const Offset(2, 2));
            } else {
              await tester.sendKeyEvent(LogicalKeyboardKey.escape);
            }
            await tester.pumpAndSettle();
            expect(find.byType(RaftSidebarContextMenu), findsNothing);
            expect(opened, 0);
            expect(client.posts.length, before);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
