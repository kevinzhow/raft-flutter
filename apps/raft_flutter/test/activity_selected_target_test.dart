import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/desktop_navigation_policy.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

import 'activity_incremental_refresh_test.dart'
    show ActivityClient, ActivityWorkspace, activityFixture, channelRow;

/// Which Activity row the open preview target selects: identity is the
/// content id (thread channel / channel), not the focused message.
void main() {
  for (final dark in raftThemeMatrix([false, true])) {
    late ActivityClient client;
    late ActivityWorkspace w;
    setUp(() {
      (client, w) = activityFixture();
      w.inbox = [
        {
          'kind': 'thread',
          'threadChannelId': 't1',
          'parentChannelId': 'ch1',
          'parentChannelName': 'Channel 1',
          'parentMessageId': 'p1',
          'parentMessagePreview': 'Thread one',
          'latestActivityPreview': 'Reply',
          'latestActivityMessageId': 'r1',
          'latestActivitySeq': '900',
          'doneFrontierSeq': '900',
          'unreadCount': 0,
          'replyCount': 2,
        },
        channelRow(1),
        {
          'kind': 'mention_action',
          'channelId': 'ch1',
          'channelName': 'Channel 1',
          'messageId': 'mention-1',
          'messagePreview': 'Mention one',
          'unreadCount': 0,
          'latestActivitySeq': '800',
          'doneFrontierSeq': '800',
        },
        channelRow(2),
      ];
    });
    tearDown(() async {
      w.dispose();
      await client.dispose();
    });

    testWidgets(
      'selected target maps to exactly one row ${dark ? 'dark' : 'light'}',
      (t) async {
        Future<void> mount(DesktopContentTarget? target) => t.pumpWidget(
          MaterialApp(
            theme: raftTheme(dark: dark),
            home: Scaffold(
              body: ResourceView(
                controller: w,
                section: 'activity',
                activitySidebarEnabled: true,
                activitySelectedTarget: target,
                onMessage: (_, _) async {},
              ),
            ),
          ),
        );
        List<String> selected() => [
          for (final card in t.widgetList<RaftConversationCard>(
            find.byType(RaftConversationCard),
          ))
            if (card.selected) (card.key! as ValueKey<String>).value,
        ];
        await mount(null);
        await t.pumpAndSettle();
        expect(find.byType(RaftConversationCard), findsNWidgets(4));
        expect(selected(), isEmpty);

        await mount(
          const DesktopContentTarget(DesktopContentKind.thread, 't1'),
        );
        await t.pump();
        expect(selected(), ['activity-thread-t1']);

        // The focused message moves with unread state; identity does not.
        await mount(
          const DesktopContentTarget(
            DesktopContentKind.channel,
            'ch2',
            channelId: 'ch2',
            messageId: 'whatever-latest',
          ),
        );
        await t.pump();
        expect(selected(), ['activity-channel-ch2']);

        // A mention action needs its own message: an ordinary channel target
        // (other message) never selects it.
        await mount(
          const DesktopContentTarget(
            DesktopContentKind.channel,
            'ch1',
            channelId: 'ch1',
            messageId: 'mention-1',
          ),
        );
        await t.pump();
        expect(selected(), contains('activity-mention_action-ch1'));
        await mount(
          const DesktopContentTarget(
            DesktopContentKind.channel,
            'ch1',
            channelId: 'ch1',
            messageId: 'other',
          ),
        );
        await t.pump();
        expect(selected(), ['activity-channel-ch1']);

        await mount(null);
        await t.pump();
        expect(selected(), isEmpty);
      },
    );
  }
}
