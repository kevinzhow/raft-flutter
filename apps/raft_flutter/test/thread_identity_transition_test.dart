import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chat_focus_receipt_test.dart' show contextRows, paintedMessage;
import 'message_presentation_test.dart' show fixture;

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    testWidgets(
      '$family/$dark canonical identity opens before parent and keeps draft/anchor',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final (w, api) = (await tester.runAsync(() => fixture('member')))!;
        addTearDown(w.dispose);
        w.ledger.switchServer('s1');
        w.threadParent = RaftMessage({
          'id': 'private-stale',
          'channelId': 'c2',
          'content': 'Private cached parent',
        });
        final parentRequest = Completer<void>.sync(),
            resolveRequest = Completer<void>.sync(),
            replyRequest = Completer<void>.sync();
        final parent = Completer<Map<String, dynamic>>.sync(),
            resolution = Completer<Map<String, dynamic>>.sync(),
            replies = Completer<Map<String, dynamic>>.sync();
        api.routes['GET /messages/context/requested'] = (_) => {
          'canonicalTarget': {
            'kind': 'thread',
            'channelId': 'c1',
            'threadParentMessageId': 'parent',
            'messageId': 'reply-40',
          },
        };
        api.routes['GET /channels/c1/threads/parent'] = (_) {
          resolveRequest.complete();
          return resolution.future;
        };
        api.routes['GET /messages/context/parent'] = (_) {
          parentRequest.complete();
          return parent.future;
        };
        api.routes['GET /messages/context/reply-40'] = (_) {
          replyRequest.complete();
          return replies.future;
        };
        api.routes['GET /messages/channel/c1'] = (_) => {
          'messages': <Map<String, dynamic>>[],
        };
        api.routes['POST /channels/thread-1/read'] = (_) => {};
        await tester.runAsync(() async {
          unawaited(w.jumpToMessage('c1', 'requested'));
          for (var i = 0; i < 40 && !parentRequest.isCompleted; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 5));
          }
          expect(resolveRequest.isCompleted, true);
          expect(parentRequest.isCompleted, true);
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: raftTheme(family, dark: dark),
            home: Scaffold(body: RaftChatView(controller: w, thread: true)),
          ),
        );
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(w.location.thread?.itemId, 'parent');
          expect(w.threadIdentity?.parentMessageId, 'parent');
          expect(w.threadParent, isNull);
          expect(find.text('Loading...'), findsOneWidget);
          expect(find.byType(RaftComposer), findsNothing);
          expect(find.text('Private cached parent'), findsNothing);
        }
        await tester.runAsync(() async {
          resolution.complete({'threadChannelId': 'thread-1'});
          for (var i = 0; i < 40 && !replyRequest.isCompleted; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 5));
          }
          expect(replyRequest.isCompleted, true);
        });
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(w.threadParentLoading, true);
          expect(w.presentedThreadParent, isNull);
          expect(
            tester.widget<RaftComposer>(find.byType(RaftComposer)).enabled,
            true,
          );
          expect(find.text('Private cached parent'), findsNothing);
        }
        await tester.enterText(
          find.byType(EditableText),
          'Draft while parent loads',
        );
        await tester.pump();
        expect(w.drafts['thread:parent'], 'Draft while parent loads');
        await tester.runAsync(() async {
          replies.complete({
            'messages': [
              for (final row in contextRows('reply'))
                {...row, 'channelId': 'thread-1'},
            ],
            'hasOlder': true,
            'hasNewer': true,
          });
          for (var i = 0; i < 40 && w.threadLoading; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 5));
          }
          expect(w.threadLoading, false);
        });
        Rect? beforeParent;
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          final rect = paintedMessage(tester, 'reply-40');
          if (rect != null) {
            beforeParent ??= rect;
            expect(
              rect,
              beforeParent,
              reason: 'Every visible reply frame keeps its first accepted coordinates',
            );
            final render = find
                .byKey(const ValueKey('message-reply-40'))
                .evaluate()
                .map((e) => e.findRenderObject())
                .whereType<RenderBox>()
                .firstWhere(
                  (r) =>
                      r.hasSize && r.localToGlobal(Offset.zero).dy == rect.top,
                );
            final viewport =
                RenderAbstractViewport.maybeOf(render) as RenderBox;
            final center =
                viewport.localToGlobal(Offset.zero).dy +
                viewport.size.height / 2;
            expect(rect.center.dy, closeTo(center, .5));
          }
        }
        expect(beforeParent, isNotNull);
        await tester.runAsync(() async {
          parent.complete({
            'messages': [
              {
                'id': 'parent',
                'channelId': 'c1',
                'senderId': 'alice',
                'seq': '1',
                'content': 'Actual parent',
              },
            ],
          });
          for (var i = 0; i < 40 && w.threadParentLoading; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 5));
          }
          expect(w.threadParentLoading, false);
        });
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(
            paintedMessage(tester, 'reply-40'),
            beforeParent,
            reason: 'Async parent height preserves the live reply anchor',
          );
          expect(
            tester
                .widget<EditableText>(find.byType(EditableText))
                .controller
                .text,
            'Draft while parent loads',
          );
          expect(w.presentedThreadParent?.content, 'Actual parent');
          expect(find.text('Private cached parent'), findsNothing);
        }
        expect(w.highlightedMessageId, 'reply-40');
        await tester.pump(const Duration(milliseconds: 2100));
        await tester.pump();
        expect(w.highlightedMessageId, isNull);
        expect(paintedMessage(tester, 'reply-40'), beforeParent);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );
  }
}
