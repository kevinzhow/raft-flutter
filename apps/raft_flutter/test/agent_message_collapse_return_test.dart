import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/agent_message_collapse.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

import 'activity_open_clears_new_test.dart' show activityRow;
import 'app_global_server_selector_test.dart' show RootFixture;
import 'mobile_back_history_test.dart' show finishBackTransition;

Map<String, dynamic> longReply(String channel) => {
  'id': 'm5',
  'channelId': channel,
  'seq': '5',
  'senderType': 'agent',
  'senderId': 'agent-1',
  'senderName': 'Fixture agent',
  'content': List.generate(
    36,
    (i) => 'Paragraph $i. Keep this reply readable.',
  ).join('\n\n'),
};

Finder chatRows(Finder chat) => find.descendant(
  of: chat,
  matching: find.byKey(const ValueKey('message-m5'), skipOffstage: false),
  skipOffstage: false,
);

Finder toggle(Finder chat, bool open) => find.descendant(
  of: chatRows(chat),
  matching: find.text(open ? 'Collapse' : 'Show More', skipOffstage: false),
  skipOffstage: false,
);

void main() {
  for (final theme in raftThemeMatrix(['light', 'dark'])) {
    testWidgets('$theme covered channel keeps its own expansion memory', (
      tester,
    ) async {
      final f = RootFixture();
      f.overrides['GET /channels'] = (_) => [
        for (final id in ['ca', 'cb'])
          {
            'id': id,
            'name': id,
            'joined': true,
            'type': 'channel',
            'serverId': 'a',
          },
      ];
      f.overrides['GET /messages/channel/ca'] = (_) => {
        'messages': [longReply('ca')],
        'hasMore': false,
      };
      f.overrides['GET /messages/channel/cb'] = (_) => {
        'messages': [
          {
            'id': 'm6',
            'channelId': 'cb',
            'seq': '6',
            'senderId': 'bob',
            'content': 'Other channel',
          },
        ],
        'hasMore': false,
      };
      await f.mount(tester, theme, 390, uri: Uri.parse('/s/alpha/channel/ca'));
      final w = f.workspace(tester);
      final chat = find.ancestor(
        of: find.byKey(const ValueKey('message-m5')),
        matching: find.byType(RaftChatView),
      );
      expect(chat, findsOneWidget);
      final owner = tester.state(chat);
      try {
        await tester.ensureVisible(toggle(chat, true));
        await tester.pumpAndSettle();
        await tester.tap(toggle(chat, true));
        await tester.pumpAndSettle();
        expect(toggle(chat, false), findsOneWidget);
        var observed = 0;
        f.onFrame = () {
          if (!owner.mounted || w.channel?.id != 'cb') return;
          expect(toggle(chat, false), findsOneWidget);
          expect(
            agentCollapseOf(owner).startsOpen(
              messageId: 'm5',
              agent: true,
              seq: BigInt.from(5),
              maxReadSeq: BigInt.from(5),
            ),
            isFalse,
            reason: 'Covered channel A must retain its choice while B opens.',
          );
          observed++;
        };
        unawaited(w.selectChannel(w.channels.last));
        await f.flush(tester);
        expect(observed, greaterThan(0));
      } finally {
        f.onFrame = null;
        await finishBackTransition(tester);
        await f.close(tester);
      }
    });
    for (final mode in ['unread', 'read', 'manual collapse', 'manual expand']) {
      testWidgets('$theme Activity thread $mode keeps every Back frame', (
        tester,
      ) async {
        final unread = mode == 'unread' || mode == 'manual collapse';
        final expectedOpen = mode == 'unread' || mode == 'manual expand';
        final f = RootFixture();
        final row = {
          ...activityRow('thread', unread: unread ? 1 : 0),
          'parentChannelId': 'ca',
          'parentChannelName': 'general-a',
          'firstUnreadMessageId': unread ? 'm5' : null,
        };
        f.overrides['GET /channels/inbox'] = (_) => {
          'items': [row],
          'hasMore': false,
          'totalCount': 1,
          'totalUnreadCount': unread ? 1 : 0,
        };
        f.overrides['GET /channels/ca/threads/parent'] = (_) => {
          'threadChannelId': 'thread-1',
        };
        f.overrides['GET /messages/context/parent'] = (_) => {
          'messages': [
            {
              'id': 'parent',
              'channelId': 'ca',
              'seq': '1',
              'senderType': 'user',
              'senderId': 'bob',
              'content': 'Parent message',
            },
          ],
        };
        f.overrides['GET /messages/context/m5'] = (_) => {
          'messages': [longReply('thread-1')],
          'hasOlder': false,
          'hasNewer': false,
        };
        f.overrides['GET /messages/channel/thread-1'] = (_) => {
          'messages': [longReply('thread-1')],
          'hasMore': false,
        };
        f.overrides['GET /channels/thread-1/followers'] = (_) => [];
        for (final endpoint in ['read', 'read-all']) {
          f.overrides['POST /channels/thread-1/$endpoint'] = (_) => {
            'maxReadSeq': 5,
            'readStateVersion': 51,
          };
        }
        await f.mount(tester, theme, 390, uri: Uri.parse('/s/alpha/activity'));
        final w = f.workspace(tester);
        w.readState.consumeUpdate(
          {
            'serverId': 'a',
            'scopeId': 'thread-1',
            'maxReadSeq': unread ? 4 : 5,
            'readStateVersion': 50,
          },
          serverId: 'a',
          principalId: 'alice',
        );
        try {
          await tester.tap(
            find.byKey(const ValueKey('activity-thread-thread-1')),
          );
          await f.flush(tester);
          await finishBackTransition(tester);
          final chat = find.byWidgetPredicate(
            (widget) => widget is RaftChatView && widget.thread,
            skipOffstage: false,
          );
          expect(chat, findsOneWidget);
          final owner = tester.state(chat);
          expect(toggle(chat, unread), findsOneWidget);
          if (mode.startsWith('manual')) {
            await tester.ensureVisible(toggle(chat, unread));
            await tester.pumpAndSettle();
            await tester.tap(toggle(chat, unread));
            await tester.pumpAndSettle();
          }
          expect(toggle(chat, expectedOpen), findsOneWidget);
          expect(w.readState.state('a', 'alice', 'thread-1')?['maxReadSeq'], 5);
          expect(
            agentCollapseOf(owner).startsOpen(
              messageId: 'm5',
              agent: true,
              seq: BigInt.from(5),
              maxReadSeq: BigInt.from(5),
            ),
            expectedOpen,
          );
          final collapse = find.descendant(
            of: chatRows(chat),
            matching: find.byType(RaftCollapsible, skipOffstage: false),
            skipOffstage: false,
          );
          final height = tester.getSize(collapse).height;
          expect(await tester.binding.handlePopRoute(), isTrue);
          await tester.pump();
          expect(w.threadChannelId, isNull);
          var frames = 0;
          var movingFrames = 0;
          while (owner.mounted && frames < 40) {
            final route = ModalRoute.of(owner.context);
            if (route?.animation?.status == AnimationStatus.reverse) {
              movingFrames++;
            }
            expect(
              toggle(chat, expectedOpen),
              findsOneWidget,
              reason: 'Visible choice must not flip in Back frame $frames.',
            );
            expect(
              tester.getSize(collapse).height,
              height,
              reason:
                  'Long reply height must not change in Back frame $frames.',
            );
            expect(
              agentCollapseOf(owner).startsOpen(
                messageId: 'm5',
                agent: true,
                seq: BigInt.from(5),
                maxReadSeq: BigInt.from(5),
              ),
              expectedOpen,
              reason:
                  'A remounted row must retain the same choice in Back frame $frames.',
            );
            expect(tester.takeException(), isNull);
            frames++;
            await tester.pump(const Duration(milliseconds: 16));
          }
          expect(movingFrames, greaterThan(2));
          expect(owner.mounted, isFalse);
          expect(w.location.route.name, 'activity');
        } finally {
          await finishBackTransition(tester);
          await f.close(tester);
        }
      });
    }
  }
}
