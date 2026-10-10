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

/// An older page that lands while the finger is still dragging: the rows on
/// screen follow the finger exactly; the inserted history never pushes them.
void main() {
  for (final thread in [false, true]) {
    testWidgets(
      '${thread ? 'thread' : 'channel'}: older page landing mid-drag follows the finger',
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
              'content': int.parse((r['id'] as String).substring(2)) % 3 == 0
                  ? longMessage(int.parse((r['id'] as String).substring(2)))
                  : r['content'],
            },
        ];
        final older = <Completer<void>>[];
        api.routes['GET /messages/channel/$scopeId'] = (request) {
          final before = int.tryParse('${request.queryParameters['before']}');
          if (before == null) return {'messages': rows.sublist(150)};
          final end = before - 1, start = (end - 50).clamp(0, end);
          final page = Completer<void>();
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
            theme: raftTheme(RaftFamily.elegant),
            home: Scaffold(
              body: RaftChatView(controller: w, thread: thread),
            ),
          ),
        );
        for (var i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(RaftChatView)),
        );
        // Drag towards older history until the older page is requested.
        for (var k = 0; k < 400 && older.isEmpty; k++) {
          await gesture.moveBy(const Offset(0, 40));
          await tester.pump(const Duration(milliseconds: 16));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 2)),
          );
        }
        expect(older, isNotEmpty);
        // Keep dragging; pick a row on screen and follow it.
        String? reading;
        for (var i = 150; i < 200 && reading == null; i++) {
          final rect = paintedMessage(tester, 'h-$i');
          if (rect != null && rect.top > 100 && rect.top < 500) {
            reading = 'h-$i';
          }
        }
        expect(reading, isNotNull);
        final log = <String>[];
        var bad = 0;
        double? last = paintedMessage(tester, reading!)?.top;
        for (var step = 0; step < 12; step++) {
          if (step == 3) {
            await tester.runAsync(() async {
              older.first.complete();
              await Future<void>.delayed(const Duration(milliseconds: 20));
            });
          }
          await gesture.moveBy(const Offset(0, 10));
          await tester.pump(const Duration(milliseconds: 16));
          final now = paintedMessage(tester, reading)?.top;
          log.add('$step $reading top=$now last=$last');
          if (now == null || last == null || (now - last - 10).abs() > 1.5) {
            bad++;
          }
          last = now;
        }
        await gesture.up();
        expect(bad, 0, reason: log.join('\n'));
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 3));
      },
    );
  }
}
