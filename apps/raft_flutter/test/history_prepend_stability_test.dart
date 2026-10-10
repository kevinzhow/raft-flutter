import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../integration_test/message_scroll_performance_test.dart'
    show longMessage;
import 'chat_focus_receipt_test.dart' show contextRows, paintedMessage;
import 'message_presentation_test.dart' show fixture;

/// Scrolling up into history: when an older page arrives, the rows on screen
/// keep their exact position on every frame; history grows above them.
void main() {
  for (final tall in [false, true]) {
    for (final thread in [false, true]) {
      for (final family in [RaftFamily.brutal, RaftFamily.elegant]) {
        testWidgets(
          '${thread ? 'thread' : 'channel'} $family tall=$tall: older page keeps the reading position',
          (tester) async {
            SharedPreferences.setMockInitialValues({});
            tester.view.physicalSize = const Size(1280, 800);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            final (w, api) = (await tester.runAsync(() => fixture('member')))!;
            addTearDown(w.dispose);
            w.ledger.switchServer('s1');
            final scopeId = thread ? 'th' : 'c1';
            final rows = [
              for (final r in contextRows('h', count: 200))
                {
                  ...r,
                  'channelId': scopeId,
                  'content': tall
                      // Every row taller than the viewport: no row is ever
                      // fully visible.
                      ? List.filled(
                          6,
                          longMessage(
                            int.parse((r['id'] as String).substring(2)),
                          ),
                        ).join('\n\n')
                      : int.parse((r['id'] as String).substring(2)) % 3 == 0
                      ? longMessage(int.parse((r['id'] as String).substring(2)))
                      : r['content'],
                },
            ];
            final older = <Completer<Map<String, dynamic>>>[];
            api.routes['GET /messages/channel/$scopeId'] = (request) {
              final before = int.tryParse(
                '${request.queryParameters['before']}',
              );
              if (before == null) return {'messages': rows.sublist(150)};
              final end = before - 1, start = (end - 50).clamp(0, end);
              final page = Completer<Map<String, dynamic>>();
              older.add(page);
              return page.future.then(
                (_) => {'messages': rows.sublist(start, end)},
              );
            };
            api.routes['GET /messages/context/parent'] = (_) => {
              'messages': [
                {
                  'id': 'parent',
                  'channelId': 'c1',
                  'seq': '1',
                  'senderId': 'bob',
                  'content': 'parent',
                },
              ],
            };
            api.routes['POST /channels/$scopeId/read'] = (_) => {};
            await tester.runAsync(() async {
              if (thread) {
                await w.openThreadIdentity(
                  parentChannelId: 'c1',
                  parentMessageId: 'parent',
                  initialThreadChannelId: 'th',
                  navigate: false,
                );
              } else {
                await w.selectChannel(w.channel!, navigate: false);
              }
            });
            await tester.pumpWidget(
              MaterialApp(
                theme: raftTheme(family),
                home: Scaffold(
                  body: RaftChatView(controller: w, thread: thread),
                ),
              ),
            );
            for (var i = 0; i < 30; i++) {
              await tester.pump(const Duration(milliseconds: 16));
            }
            // Scroll up (towards older) until the older page is requested.
            for (var k = 0; k < 60 && older.isEmpty; k++) {
              await tester.timedDrag(
                find.byType(RaftChatView),
                const Offset(0, 300),
                const Duration(milliseconds: 80),
              );
              await tester.pump(const Duration(milliseconds: 16));
              await tester.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 5)),
              );
            }
            expect(older, isNotEmpty);
            // Let the drag's fling come to rest (history is requested well
            // before the top edge, so the fling is usually still coasting).
            final dynamic chatState = tester.state(find.byType(RaftChatView));
            final ScrollController scroll = chatState.viewport;
            for (
              var i = 0;
              i < 20 || (i < 400 && scroll.position.isScrollingNotifier.value);
              i++
            ) {
              await tester.pump(const Duration(milliseconds: 16));
            }
            // A row currently on screen.
            String? reading;
            Rect? before;
            for (var i = 150; i < 200 && reading == null; i++) {
              final rect = paintedMessage(tester, 'h-$i');
              if (rect != null && (tall || rect.top > 100)) {
                reading = 'h-$i';
                before = rect;
              }
            }
            expect(reading, isNotNull);
            await tester.runAsync(() async {
              // Every older request issued so far lands (the prefetch may
              // have superseded the first); wait until the page is accepted.
              for (final page in older) {
                if (!page.isCompleted) page.complete({});
              }
              for (
                var i = 0;
                i < 200 && w.messages.length + w.replies.length <= 50;
                i++
              ) {
                await Future<void>.delayed(const Duration(milliseconds: 10));
              }
            });
            final log = <String>[];
            var moved = 0;
            for (var i = 0; i < 20; i++) {
              await tester.pump(const Duration(milliseconds: 16));
              final now = paintedMessage(tester, reading!);
              final dynamic st = tester.state(find.byType(RaftChatView));
              final ScrollController vc = st.viewport;
              log.add(
                '$i $reading ${now?.top} (was ${before!.top}) '
                'px=${vc.hasClients ? vc.offset.toStringAsFixed(0) : '-'} '
                'max=${vc.hasClients ? vc.position.maxScrollExtent.toStringAsFixed(0) : '-'} '
                'n=${st.adapter.messages.length} atBottom=${st.atBottom}',
              );
              if (now == null || (now.top - before.top).abs() > .5) moved++;
            }
            expect(w.messages.length + w.replies.length, greaterThan(50));
            expect(moved, 0, reason: log.join('\n'));
            await tester.pumpWidget(const SizedBox());
            await tester.pump(const Duration(seconds: 3));
          },
        );
      }
    }
  }
}
