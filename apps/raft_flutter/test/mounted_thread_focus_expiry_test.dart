import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_ui/raft_ui.dart';

import 'chat_focus_receipt_test.dart' show contextRows, paintedMessage;
import 'message_context_transition_test.dart' show row;
import 'mounted_message_navigation_test.dart'
    show pageFixture, mountPage, pageFrames;

void main() {
  for (final (family, dark) in [
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ]) {
    for (final surface in ['activity', 'search', 'canonical']) {
      final preview = surface != 'canonical', consumes = surface == 'activity';
      testWidgets(
        '[N24f] $family/$dark actual ${surface == 'activity'
            ? 'Activity consumes msg'
            : surface == 'search'
            ? 'Search retains msg'
            : 'canonical retains msg'} while parent is held',
        (tester) async {
          final (w, api) = await pageFixture(tester);
          w.ledger.ingest([
            row('main', 'c1', 1),
          ], expectedGeneration: w.ledger.generation);
          w.visibleIds['c1'] = {'main'};
          if (preview) w.section = surface;
          w.navigation.navigate(
            w.location.withQuery({
              if (preview) 'open': 'thread:t1',
              'thread': 'c1:parent',
              'msg': 'reply-40',
              'keep': 'value:with space',
            }),
          );
          api.routes['GET /channels/inbox'] = (_) => {'items': []};
          final parent = Completer<Map<String, dynamic>>.sync();
          api.routes['GET /messages/context/parent'] = (_) => parent.future;
          api.routes['GET /messages/context/reply-40'] = (_) => {
            'messages': [
              for (final m in contextRows('reply')) {...m, 'channelId': 't1'},
            ],
            'hasOlder': true,
            'hasNewer': true,
          };
          await tester.runAsync(
            () => w.openThreadIdentity(
              parentChannelId: 'c1',
              parentMessageId: 'parent',
              initialThreadChannelId: 't1',
              focusedMessageId: 'reply-40',
              navigate: false,
            ),
          );
          await mountPage(tester, w, family, dark);
          final rect = paintedMessage(tester, 'reply-40');
          expect(rect, isNotNull);
          final focus = find.byKey(const ValueKey('message-reply-40'));
          expect(tester.widget<RaftMessageTile>(focus).highlighted, true);
          expect(w.threadParentLoading, true);
          expect(w.presentedThreadParent, isNull);
          final revision = w.navigationRevision,
              index = w.navigation.index,
              entries = w.navigation.entries.length;
          final before = Map<String, String>.from(
            w.location.uri.queryParameters,
          );
          await tester.pump(const Duration(milliseconds: 1700));
          expect(w.highlightedMessageId, 'reply-40');
          expect(tester.widget<RaftMessageTile>(focus).highlighted, true);
          expect(w.location.messageId, 'reply-40');
          await tester.pump(const Duration(milliseconds: 400));
          await pageFrames(tester, () {
            expect(w.highlightedMessageId, isNull);
            expect(
              tester
                  .widgetList<RaftMessageTile>(focus)
                  .every((tile) => !tile.highlighted),
              true,
            );
            expect(paintedMessage(tester, 'reply-40'), rect);
            expect(
              w.location.uri.queryParameters,
              consumes
                  ? (Map<String, String>.from(before)..remove('msg'))
                  : before,
            );
            expect(w.navigationRevision, revision);
            expect(w.navigation.index, index);
            expect(w.navigation.entries.length, entries);
            expect(
              w.navigation.entries[index].toString(),
              w.location.toString(),
            );
            expect(w.threadIdentity?.parentMessageId, 'parent');
            expect(w.threadParentLoading, true);
          });
          await tester.runAsync(() async {
            parent.complete({
              'messages': [row('parent', 'c1', 2)],
            });
            for (var i = 0; i < 40 && w.threadParentLoading; i++) {
              await Future<void>.delayed(const Duration(milliseconds: 5));
            }
          });
          await pageFrames(tester, () {
            expect(w.presentedThreadParent?.id, 'parent');
            expect(w.threadParentLoading, false);
            expect(paintedMessage(tester, 'reply-40'), rect);
            expect(
              tester
                  .widgetList<RaftMessageTile>(focus)
                  .every((tile) => !tile.highlighted),
              true,
            );
            expect(w.location.query('keep'), 'value:with space');
            expect(w.location.messageId, consumes ? null : 'reply-40');
          });
          expect(
            api.calls.where((c) => c.path == '/messages/context/reply-40'),
            hasLength(1),
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
