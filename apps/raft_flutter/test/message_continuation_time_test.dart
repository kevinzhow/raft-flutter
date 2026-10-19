import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/source_time_formatter.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:raft_ui/test_themes.dart';

import 'message_presentation_test.dart' show fixture;

void main() {
  for (final (family, dark) in raftThemeMatrix([
    (RaftFamily.brutal, false),
    (RaftFamily.elegant, false),
    (RaftFamily.elegant, true),
  ], full: true)) {
    for (final format in ['24h', '12h']) {
      testWidgets(
        '$family/$dark $format historical continuation shows only its clock on hover',
        (t) async {
          final oldNow = sourceTimeNow;
          sourceTimeNow = () => DateTime.utc(2026, 10, 16);
          addTearDown(() => sourceTimeNow = oldNow);
          final (w, _) = (await t.runAsync(() => fixture('owner')))!;
          addTearDown(w.dispose);
          w.client.user = RaftRecord({
            ...w.client.user!.json,
            'preferredTimezone': 'Asia/Shanghai',
            'preferredTimeFormat': format,
          });
          w.messageDomain.ledger.switchServer('s1');
          w.messageDomain.ledger.ingest([
            for (var i = 0; i < 2; i++)
              {
                'id': 'old-$i',
                'channelId': 'c1',
                'seq': '${i + 1}',
                'senderId': 'alice',
                'senderType': 'user',
                'content': 'Historical public message $i',
                'createdAt': '2026-06-22T02:3${i}Z',
              },
          ], expectedGeneration: w.messageDomain.ledger.generation);
          w.messageDomain.visibleIds['c1'] = {'old-0', 'old-1'};

          Future<void> frame() async {
            await t.pumpWidget(
              MaterialApp(
                theme: raftTheme(family, dark: dark),
                home: Scaffold(body: RaftChatView(controller: w)),
              ),
            );
            await t.pumpAndSettle();
          }

          try {
            await frame();
            final row = find.byKey(const ValueKey('message-old-1'));
            expect(t.widget<RaftMessageTile>(row).continuation, isTrue);
            final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
            await mouse.addPointer(location: const Offset(2, 2));
            addTearDown(mouse.removePointer);
            await mouse.moveTo(t.getCenter(row));
            await t.pump();
            final bodyBefore = t.getRect(
              find.text('Historical public message 1'),
            );
            final shortClock = format == '24h' ? '10:31' : '10:31 AM';
            expect(
              find.descendant(of: row, matching: find.text(shortClock)),
              findsOneWidget,
            );
            // Full date and preferred-zone time remain in the row's accessible
            // label; only the small visual gutter uses the clock.
            expect(
              t.widget<RaftMessageTile>(row).timestamp,
              '06/22 $shortClock',
            );
            await mouse.moveTo(const Offset(2, 2));
            await t.pump();
            expect(
              t.getRect(find.text('Historical public message 1')),
              bodyBefore,
            );

            w.client.user = RaftRecord({
              ...w.client.user!.json,
              'preferredTimezone': 'America/New_York',
            });
            w.setError(null);
            await t.pumpAndSettle();
            final changedClock = format == '24h' ? '22:31' : '10:31 PM';
            expect(
              find.descendant(of: row, matching: find.text(changedClock)),
              findsOneWidget,
            );
            expect(
              t.widget<RaftMessageTile>(row).timestamp,
              '06/21 $changedClock',
            );
          } finally {
            await t.pumpWidget(const SizedBox());
            await t.pump(const Duration(seconds: 1));
            expect(t.takeException(), isNull);
          }
        },
      );
    }
  }
}
