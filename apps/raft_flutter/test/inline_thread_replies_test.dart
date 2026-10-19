import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'message_presentation_test.dart' show fixture, host;

void main() {
  testWidgets(
    'inline reply opens the parent thread and stale authority callback does not navigate',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final (w, a) = (await tester.runAsync(() => fixture('owner')))!;
      addTearDown(w.dispose);
      w.messageDomain.ledger.switchServer('s1');
      final parent = {
        'id': 'parent',
        'channelId': 'c1',
        'seq': '1',
        'senderId': 'alice',
        'content': 'Parent conversation',
      };
      w.messageDomain.ledger.ingest([
        parent,
      ], expectedGeneration: w.messageDomain.ledger.generation);
      w.messageDomain.visibleIds['c1'] = {'parent'};
      w.messageDomain.threadSummaries['parent'] = {
        'replyCount': 2,
        'latestReplies': [
          {
            'messageId': 'system',
            'senderType': 'system',
            'preview': 'System event',
          },
          {
            'messageId': 'reply',
            'senderType': 'user',
            'senderName': '林',
            'senderDisplayName': '林・日本語',
            'preview': '中文 日本語 reply',
          },
        ],
      };
      a.routes['GET /channels/c1/threads/parent'] = (_) => {
        'threadChannelId': 'thread',
      };
      a.routes['GET /messages/channel/thread'] = (options) {
        return {
          'messages': [
            {
              'id': 'reply',
              'channelId': 'thread',
              'seq': '1',
              'senderId': 'alice',
              'content': '中文 日本語 reply',
            },
          ],
        };
      };
      a.routes['POST /channels/thread/read'] = (_) => {};
      await tester.pumpWidget(host(RaftChatView(controller: w)));
      await tester.pumpAndSettle();
      final row = find.byKey(const ValueKey('inline-thread-parent'));
      expect(row, findsOneWidget);
      expect(find.text('System event'), findsNothing);
      final callback = tester.widget<RaftInlineThreadSurface>(row).onOpen!;
      await tester.runAsync(() async {
        callback();
        for (var i = 0; i < 50 && w.messageDomain.state.threadLoading; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      expect(w.messageDomain.state.threadParent?.id, 'parent');
      expect(w.messageDomain.state.highlightedMessageId, isNull);
      expect(w.replies.any((m) => m.id == 'reply'), isTrue);
      w.closeThread();
      w.server = RaftRecord({'id': 's1', 'role': 'guest'});
      // The captured row still exists before this frame rebuild; no stale navigation.
      callback();
      expect(w.messageDomain.state.threadParent, isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'thread parent and reply tiles do not recursively show previews',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final (w, a) = (await tester.runAsync(() => fixture('owner')))!;
      addTearDown(w.dispose);
      w.messageDomain.ledger.switchServer('s1');
      w.messageDomain.state.threadParent = RaftMessage({
        'id': 'parent',
        'channelId': 'c1',
        'content': 'Parent',
      });
      w.threadChannelId = 'thread';
      final reply = {
        'id': 'reply',
        'channelId': 'thread',
        'seq': '1',
        'content': 'Reply',
        'senderId': 'alice',
      };
      w.messageDomain.ledger.ingest([
        reply,
      ], expectedGeneration: w.messageDomain.ledger.generation);
      w.messageDomain.visibleIds['thread'] = {'reply'};
      for (final id in ['parent', 'reply']) {
        w.messageDomain.threadSummaries[id] = {
          'replyCount': 1,
          'latestReplies': [
            {
              'messageId': 'nested',
              'senderType': 'user',
              'preview': 'Nested preview',
            },
          ],
        };
      }
      a.routes['GET /channels/threads/followed'] = (_) => {'threads': []};
      await tester.pumpWidget(host(RaftChatView(controller: w, thread: true)));
      await tester.pumpAndSettle();
      expect(find.byType(RaftInlineThreadSurface), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    },
  );
}
