import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/platform/workspace_cache.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'history_gaps_test.dart' show GapClient;
import 'history_memory_test.dart' show receiver;
import 'history_memory_viewport_test.dart' show drainIo;
import 'support/history_gap_view_cleanup.dart';

void main() {
  testWidgets(
    'a failed flush still closes the view, controller, stream and database',
    (t) async {
      SharedPreferences.setMockInitialValues({});
      final (db, client, w) = (await t.runAsync(() async {
        final db = DriftWorkspaceCache(
          NativeDatabase.memory(),
          automaticHistoryMaintenance: false,
        );
        final client = GapClient(), w = receiver(client, db);
        await w.selectChannel(w.channels.single, autoRead: false);
        return (db, client, w);
      }))!;
      try {
        await t.pumpWidget(
          MaterialApp(
            theme: raftTheme(),
            home: Scaffold(body: RaftChatView(controller: w)),
          ),
        );
        await t.pumpAndSettle();
        Object? failure;
        try {
          await closeGapView(
            t,
            w,
            client,
            db,
            flush: () async =>
                throw TimeoutException('Controlled flush failure'),
          );
        } catch (error) {
          failure = error;
        }
        expect(
          failure,
          isA<TimeoutException>().having(
            (e) => e.message,
            'original failure',
            'Controlled flush failure',
          ),
        );
        expect(find.byType(RaftChatView), findsNothing);
        expect(w.deviceStore.writable, isFalse);
        expect(client.arrivals.isClosed, isTrue);
        expect(db.messageHistory.reads.closed, isTrue);
      } finally {
        // The red comparison must clean its own deliberately failed old cleanup.
        await t.pumpWidget(const SizedBox.shrink());
        w.dispose();
        await drainIo(t, client.arrivals.close());
        await drainIo(t, client.dispose());
        await drainIo(t, db.close());
      }
    },
  );
}
