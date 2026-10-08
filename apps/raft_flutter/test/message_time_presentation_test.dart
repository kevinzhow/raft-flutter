import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_ui/raft_ui.dart';

import 'message_presentation_test.dart' show fixture;

void main() {
  testWidgets(
    'mounted message uses current principal IANA preference and date prefix',
    (t) async {
      final (w, _) = (await t.runAsync(() => fixture('owner')))!;
      addTearDown(w.dispose);
      final user = {
        ...w.client.user!.json,
        'preferredTimezone': 'Asia/Shanghai',
        'preferredTimeFormat': '24h',
      };
      w.client.user = RaftRecord(user);
      w.ledger.switchServer('s1');
      w.ledger.ingest([
        {
          'id': 'time',
          'channelId': 'c1',
          'seq': '1',
          'senderId': 'alice',
          'senderType': 'user',
          'content': 'Public time fixture',
          'createdAt': '2026-06-22T02:30:00Z',
        },
      ], expectedGeneration: w.ledger.generation);
      w.visibleIds['c1'] = {'time'};
      await t.pumpWidget(
        MaterialApp(
          theme: raftTheme(RaftFamily.elegant),
          home: Scaffold(body: RaftChatView(controller: w)),
        ),
      );
      await t.pumpAndSettle();
      expect(
        t
            .widget<RaftMessageTile>(find.byKey(const ValueKey('message-time')))
            .timestamp,
        '06/22 10:30',
      );
      w.client.user = RaftRecord({
        ...user,
        'preferredTimezone': 'America/New_York',
      });
      w.setError(null);
      await t.pumpAndSettle();
      expect(
        t
            .widget<RaftMessageTile>(find.byKey(const ValueKey('message-time')))
            .timestamp,
        '06/21 22:30',
      );
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
      expect(t.takeException(), isNull);
    },
  );
}
