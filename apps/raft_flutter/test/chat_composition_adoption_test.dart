import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show fixture;

void main() {
  test('As Task participates in retry identity and only checked sends include the flag', () async {
    final (w, transport) = await fixture('owner');
    addTearDown(w.dispose);
    var failing = true;
    transport.routes['POST /v2/messages'] = (request) {
      if (failing) throw StateError('controlled failure');
      return {
        'message': {
          'id': 'sent',
          'channelId': 'c1',
          'seq': 1,
          'senderId': 'alice',
          'senderType': 'user',
          'content': 'same',
        },
      };
    };
    expect(await w.send('same', asTask: true), false);
    failing = false;
    expect(await w.send('same', asTask: false), true);
    final requests = transport.calls
        .where((r) => r.path == '/v2/messages')
        .toList();
    expect(requests[0].data['asTask'], true);
    expect(requests[1].data.containsKey('asTask'), false);
    expect(requests[0].data['randomId'], isNot(requests[1].data['randomId']));
  });

  testWidgets(
    'a late ordinary-send ACK does not clear a newer As Task choice',
    (t) async {
      final (w, transport) = (await t.runAsync(() => fixture('owner')))!;
      addTearDown(w.dispose);
      w.ledger.switchServer('s1');
      final ack = Completer<Map<String, dynamic>>();
      transport.routes['POST /v2/messages'] = (_) => ack.future;
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Scaffold(body: RaftChatView(controller: w)),
        ),
      );
      await t.pumpAndSettle();
      final composer = find.byType(RaftComposer);
      final editor = find.descendant(
        of: composer,
        matching: find.byType(TextField),
      );
      await t.enterText(editor, 'Public ordinary send');
      await t.pump();
      await t.tap(
        find.byWidgetPredicate(
          (widget) =>
              widget is RaftComposerAction && widget.glyph == RaftGlyph.send,
        ),
      );
      for (
        var i = 0;
        i < 20 && !transport.calls.any((r) => r.path == '/v2/messages');
        i++
      ) {
        await t.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        });
        await t.pump(const Duration(milliseconds: 10));
      }
      expect(
        transport.calls
            .singleWhere((r) => r.path == '/v2/messages')
            .data
            .containsKey('asTask'),
        false,
      );
      final task = find.byKey(const Key('composer-as-task'));
      await t.tap(task);
      await t.pump();
      expect(t.widget<RaftComposerTaskToggle>(task).checked, true);
      ack.complete({
        'message': {
          'id': 'late-sent',
          'channelId': 'c1',
          'seq': 1,
          'senderId': 'alice',
          'senderType': 'user',
          'content': 'Public ordinary send',
        },
      });
      await t.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      await t.pumpAndSettle();
      expect(t.widget<RaftComposerTaskToggle>(task).checked, true);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'current IANA day boundaries render once and a forced task send reaches the transport',
    (t) async {
      final (w, transport) = (await t.runAsync(() => fixture('owner')))!;
      addTearDown(w.dispose);
      w.client.user = RaftRecord({
        ...w.client.user!.json,
        'preferredTimezone': 'Asia/Shanghai',
        'preferredTimeFormat': '24h',
      });
      w.ledger.switchServer('s1');
      w.ledger.ingest([
        for (final entry in [
          ('one', '2026-06-21T15:30:00Z'),
          ('two', '2026-06-21T16:30:00Z'),
          ('three', '2026-06-22T02:30:00Z'),
        ])
          {
            'id': entry.$1,
            'channelId': 'c1',
            'seq': entry.$1 == 'one'
                ? 1
                : entry.$1 == 'two'
                ? 2
                : 3,
            'senderId': 'alice',
            'senderType': 'user',
            'content': 'Public ${entry.$1}',
            'createdAt': entry.$2,
          },
      ], expectedGeneration: w.ledger.generation);
      w.visibleIds['c1'] = {'one', 'two', 'three'};
      transport.routes['POST /v2/messages'] = (_) => {
        'message': {
          'id': 'sent',
          'channelId': 'c1',
          'seq': 4,
          'senderId': 'alice',
          'senderType': 'user',
          'content': 'A real task submit',
        },
      };
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Scaffold(body: RaftChatView(controller: w)),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('message-day-one')), findsOneWidget);
      expect(find.byKey(const ValueKey('message-day-two')), findsOneWidget);
      expect(find.byKey(const ValueKey('message-day-three')), findsNothing);
      final editor = find.descendant(
        of: find.byType(RaftComposer),
        matching: find.byType(TextField),
      );
      await t.enterText(editor, 'A real task submit');
      await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await t.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await t.pumpAndSettle();
      final request = transport.calls.lastWhere(
        (r) => r.path == '/v2/messages',
      );
      expect(request.data['asTask'], true);
      expect(request.data['content'], 'A real task submit');
      expect(
        t
            .widget<RaftComposerTaskToggle>(
              find.byKey(const Key('composer-as-task')),
            )
            .checked,
        false,
      );
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
      expect(t.takeException(), isNull);
    },
  );
}
