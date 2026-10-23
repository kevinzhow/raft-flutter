import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/activity_list_row.dart';
import 'package:raft_flutter/features/activity_rollout_flags.dart';
import 'package:raft_flutter/features/resource_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'activity_incremental_refresh_test.dart'
    show ActivityClient, ActivityWorkspace, activityFixture, channelRow;

Map<String, dynamic> _thread() => {
  'kind': 'thread',
  'threadChannelId': 't1',
  'parentChannelId': 'ch1',
  'parentChannelName': 'Channel 1',
  'parentChannelType': 'channel',
  'parentMessageId': 'pm1',
  'parentMessagePreview': 'Parent text',
  'latestActivityMessageId': 'r1',
  'latestActivityPreview': 'Reply text',
  'latestActivitySenderType': 'user',
  'latestActivitySenderId': 'bob',
  'latestActivitySenderName': 'Bob',
  'lastActivityAt': '2026-10-10T00:00:00Z',
  'latestActivitySeq': '5',
  'unreadCount': 1,
  'replyCount': 2,
  'hasMention': true,
  'isFollowing': true,
};

Map<String, dynamic> _dm() => {
  'kind': 'dm',
  'channelId': 'dm1',
  'channelName': 'Alice',
  'channelType': 'dm',
  'lastMessageId': 'dm-m1',
  'lastMessageAt': '2026-10-10T00:00:00Z',
  'lastMessagePreview': 'Hello from Alice',
  'lastMessageSenderType': 'user',
  'lastMessageSenderId': 'u-alice',
  'lastMessageSenderName': 'Alice',
  'latestActivitySeq': '900',
  'doneFrontierSeq': '900',
  'unreadCount': 0,
  'hasMention': false,
};

/// Web v1.21.23 `activity_conversation_list_v0`: Activity as a conversation
/// list, one avatar row per conversation with its preview and unread count,
/// the sidebar's pinned conversations first.
void main() {
  group('which rows are pinned', () {
    final dms = [
      RaftChannel({
        'id': 'dm1',
        'type': 'dm',
        'peerType': 'user',
        'peerId': 'u-alice',
      }),
      RaftChannel({
        'id': 'dm2',
        'type': 'dm',
        'peerType': 'agent',
        'peerId': 'bot',
      }),
    ];
    final pinned = [
      {'kind': 'channel', 'id': 'ch5'},
      {'kind': 'human', 'id': 'u-alice'},
      {'kind': 'agent', 'id': 'bot'},
    ];
    bool isPinned(Map<String, dynamic> row) =>
        isSidebarPinnedActivityRow(row, pinned, dms);

    test('a channel by its id, a DM by its peer, a thread never', () {
      expect(isPinned(channelRow(5)), isTrue);
      expect(isPinned(channelRow(6)), isFalse);
      expect(isPinned(_dm()), isTrue);
      expect(isPinned({..._dm(), 'channelId': 'dm2'}), isTrue);
      expect(isPinned({..._dm(), 'channelId': 'dm-unknown'}), isFalse);
      expect(isPinned({..._thread(), 'parentChannelId': 'ch5'}), isFalse);
      // A mention action in a DM pins like its DM.
      expect(
        isPinned({
          'kind': 'mention_action',
          'channelType': 'dm',
          'channelId': 'dm1',
        }),
        isTrue,
      );
      expect(isSidebarPinnedActivityRow(channelRow(5), const [], dms), isFalse);
    });
  });

  group('in Activity', () {
    late ActivityClient client;
    late ActivityWorkspace w;

    setUp(() {
      (client, w) = activityFixture();
      w.dms = [
        RaftChannel({
          'id': 'dm1',
          'name': 'Alice',
          'type': 'dm',
          'joined': true,
          'peerType': 'user',
          'peerId': 'u-alice',
          'peerDisplayName': 'Alice',
        }),
      ];
      w.sidebarOrder = {
        'pinned': [
          {'kind': 'channel', 'id': 'ch5'},
          {'kind': 'human', 'id': 'u-alice'},
        ],
      };
      w.inbox = [
        for (var i = 0; i < 8; i++) channelRow(i, unread: i == 3 ? 2 : 0),
        _thread(),
        _dm(),
      ];
    });
    tearDown(() async {
      w.dispose();
      await client.dispose();
    });

    Future<dynamic> mount(
      WidgetTester tester, {
      bool flag = true,
      bool pointer = false,
    }) async {
      if (flag) {
        client.responses['POST /feature-flags/evaluate'] = {
          'evaluations': [
            {'key': 'activity_conversation_list_v0', 'enabled': true},
          ],
        };
      }
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      // The shell asks for the flags as it draws the sidebar; here nothing does.
      ActivityRolloutFlags.of(w);
      await tester.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Scaffold(
            body: RaftInteractionScope(
              interaction: pointer
                  ? RaftInteraction.pointerMode
                  : RaftInteraction.touchMode,
              child: ResourceView(
                controller: w,
                section: 'activity',
                onMessage: (_, _) async {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        for (var i = 0; i < 200; i++) {
          if (ActivityRolloutFlags.peek(w)?.activityConversationList == flag) {
            break;
          }
          await Future<void>.delayed(const Duration(milliseconds: 25));
        }
        await Future<void>.delayed(const Duration(milliseconds: 25));
      });
      await tester.pumpAndSettle();
      return tester.state(find.byType(ResourceView));
    }

    Finder row(String key) => find.byKey(ValueKey(key));

    testWidgets('one avatar row per conversation, pinned first under their '
        'headings', (tester) async {
      await mount(tester);
      expect(find.byType(RaftConversationCard), findsNothing);
      expect(find.byType(RaftConversationListRow), findsWidgets);
      // Pinned: Channel 5 and the DM with Alice, in their loaded order, then
      // everything else.
      expect(find.text('Pinned'), findsOneWidget);
      expect(find.text('All conversations'), findsOneWidget);
      final rows = tester
          .widgetList<RaftConversationListRow>(
            find.byType(RaftConversationListRow),
          )
          .map((r) => (r.key as ValueKey).value)
          .toList();
      expect(rows.take(3), [
        'activity-channel-ch5',
        'activity-dm-dm1',
        'activity-channel-ch0',
      ]);
      // The heading sits above its first row, "All" after the pinned ones.
      final pinnedHeading = tester.getTopLeft(find.text('Pinned')).dy;
      final allHeading = tester.getTopLeft(find.text('All conversations')).dy;
      final first = tester.getTopLeft(row('activity-channel-ch5')).dy;
      final second = tester.getTopLeft(row('activity-dm-dm1')).dy;
      final third = tester.getTopLeft(row('activity-channel-ch0')).dy;
      expect(pinnedHeading, lessThan(first));
      expect(second, greaterThan(first));
      expect(allHeading, greaterThan(second));
      expect(allHeading, lessThan(third));
    });

    testWidgets('a row shows title, sender and preview, the timestamp and the '
        'unread count', (tester) async {
      await mount(tester);
      final unread = row('activity-channel-ch3');
      expect(
        find.descendant(of: unread, matching: find.text('Channel 3')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: unread,
          matching: find.textContaining('Bob: Preview 3', findRichText: true),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: unread,
          matching: find.byKey(const ValueKey('conversation-card-timestamp')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: unread,
          matching: find.byKey(const ValueKey('conversation-card-new-badge')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: unread, matching: find.text('2')),
        findsOneWidget,
      );
      // A read row has no count.
      expect(
        find.descendant(
          of: row('activity-channel-ch4'),
          matching: find.byKey(const ValueKey('conversation-card-new-badge')),
        ),
        findsNothing,
      );
    });

    testWidgets('a thread leads with its parent text and names its channel; '
        'a mention shows the @ sticker', (tester) async {
      await mount(tester);
      final thread = row('activity-thread-t1');
      expect(
        find.descendant(of: thread, matching: find.text('Parent text')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: thread,
          matching: find.textContaining('#Channel 1 ·', findRichText: true),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: thread,
          matching: find.byType(RaftSidebarMentionMarker),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<RaftConversationAvatarTile>(
              find.descendant(
                of: thread,
                matching: find.byType(RaftConversationAvatarTile),
              ),
            )
            .kind,
        RaftConversationAvatarKind.thread,
      );
    });

    testWidgets('a muted channel shows the bell, not a count', (tester) async {
      w.channels = [
        for (final c in w.channels)
          c.id == 'ch3' ? RaftChannel({...c.json, 'activityMuted': true}) : c,
      ];
      await mount(tester);
      final muted = row('activity-channel-ch3');
      expect(
        find.descendant(
          of: muted,
          matching: find.byKey(const ValueKey('conversation-card-muted')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: muted,
          matching: find.byKey(const ValueKey('conversation-card-new-badge')),
        ),
        findsNothing,
      );
    });

    testWidgets('Done shows on hover and marks the conversation done', (
      tester,
    ) async {
      await mount(tester, pointer: true);
      final target = row('activity-channel-ch3');
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(target));
      await tester.pumpAndSettle();
      final done = find.descendant(
        of: target,
        matching: find.byKey(const ValueKey('inbox-row-done')),
      );
      await mouse.moveTo(tester.getCenter(done));
      await tester.pumpAndSettle();
      await mouse.down(tester.getCenter(done));
      await mouse.up();
      await tester.pumpAndSettle();
      expect(
        client.posts.where((p) => p.contains('done')).toList(),
        isNotEmpty,
        reason: 'Done posts',
      );
    });

    testWidgets('a server without the flag keeps the cards in their order', (
      tester,
    ) async {
      await mount(tester, flag: false);
      expect(find.byType(RaftConversationListRow), findsNothing);
      expect(find.byType(RaftConversationCard), findsWidgets);
      expect(find.text('Pinned'), findsNothing);
      expect(row('activity-channel-ch0'), findsOneWidget);
      final dynamic state = tester.state(find.byType(ResourceView));
      expect(
        (state.rows as List).map((dynamic r) => r['kind'] == 'dm').toList()
          ..removeWhere((x) => !x),
        hasLength(1),
      );
      expect(
        tester.getTopLeft(row('activity-channel-ch0')).dy,
        lessThan(tester.getTopLeft(row('activity-channel-ch5')).dy),
        reason: 'no pinned-first reorder',
      );
    });
  });
}
