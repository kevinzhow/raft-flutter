@Tags(['slow'])
library;

import 'package:raft_flutter/data/history_capacity.dart';

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raft_client/raft_client.dart';
import 'package:raft_flutter/data/message_history_pages.dart';
import 'package:raft_flutter/features/chat_view.dart';
import 'package:raft_flutter/features/message_timeline.dart';
import 'package:raft_flutter/platform/workspace_cache.dart';
import 'package:raft_ui/raft_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'history_gaps_test.dart' show GapClient, seedGap;
import 'history_memory_test.dart' show receiver, row;
import 'history_memory_viewport_test.dart' show drainIo;
import 'support/history_gap_view_cleanup.dart';

class _Client extends GapClient {
  @override
  Future<List<RaftChannel>> channels({bool dm = false}) async => dm
      ? []
      : [
          RaftChannel({'id': 'chat', 'type': 'private', 'joined': true}),
        ];
  bool disconnected = false;
  @override
  Future<Map<String, dynamic>> messagePage(
    String id, {
    int limit = 50,
    BigInt? before,
    BigInt? after,
  }) async {
    if (disconnected && before != null) {
      beforeReads.add(before);
      if (!beforeArrived.isCompleted) beforeArrived.complete();
      throw StateError('Offline');
    }
    // Two complete pages exercise continued repair without rendering 800
    // extra rows. The large-range/frontier-release contract has a non-UI test.
    if (before == null) {
      return {
        'messages': [for (var n = 201; n <= 250; n++) row(id, n)],
        'historyLimited': false,
      };
    }
    return super.messagePage(id, limit: limit, before: before, after: after);
  }
}

void main() {
  for (final mode in ['open', 'reconnect', 'hard limit']) {
    final offline = mode == 'reconnect', limited = mode == 'hard limit';
    testWidgets(
      'gap fills automatically $mode with an inline placeholder and stable reading row',
      (t) async {
        // Initial: older saved island 1–100 and tail 201–250, with an unverified interval.
        // Event: open/scroll to that interval; when offline reconnect without tapping.
        // Expected: inline placeholder then complete coverage, no button, stable anchor.
        SharedPreferences.setMockInitialValues({});
        t.view.physicalSize = const Size(900, 800);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final (db, client, w, scope) = (await t.runAsync(() async {
          var free = 2 << 30;
          final db = DriftWorkspaceCache(
            NativeDatabase.memory(),
            historyAvailableSpace: (_) async => free,
          );
          final client = _Client()..gate = Completer<void>();
          final w = receiver(client, db);
          final scope = MessageHistoryPages.scope(w, 'chat')!;
          await seedGap(db, scope);
          await w.selectChannel(w.channels.single, autoRead: false);
          await w.messageDomain.older();
          client.disconnected = offline;
          if (limited) free = 512 << 20;
          return (db, client, w, scope);
        }))!;
        try {
          await t.pumpWidget(
            MaterialApp(
              theme: raftTheme(),
              home: Scaffold(body: RaftChatView(controller: w)),
            ),
          );
          await drainIo(
            t,
            db.messageHistory.gaps.read(scope, [
              for (final row in w.messageDomain.messages) (row.id, row.seq),
            ]),
          );
          await t.pumpAndSettle();
          expect(find.text('Load this gap'), findsNothing);
          // This assertion gives an immediate old-code failure without timing out.
          await drainIo(t, client.beforeArrived.future);
          expect(client.beforeReads, isNotEmpty);
          final dynamic state = t.state(find.byType(RaftChatView));
          state.recenter(
            first: 'chat-201',
            alignment: RaftTimelineAlignment.start,
          );
          await t.pumpAndSettle();
          state.viewport.jumpTo(200.0);
          await t.pumpAndSettle();
          if (offline) {
            expect(
              find.text('Messages will fill in automatically when connected.'),
              findsNothing,
            );
            client.disconnected = false;
            client.arrivals.add(const RaftEvent('rooms:joined', null));
            await t.pump();
          }
          expect(
            find.byKey(const ValueKey('history-gap-placeholder-chat-201')),
            findsOneWidget,
          );
          state.saveReadingAnchor();
          final anchor = w.messageWindows.readingAnchor('chat')!;
          final reading = find.byKey(
            ValueKey('message-wrapper-${anchor.messageKey}'),
          );
          final top = t.getRect(reading).top;
          client.gate!.complete();
          await drainIo(t, w.flushCache());
          // Drain actual background IO until its own coverage proof completes.
          await drainIo(t, db.messageHistory.reads.settled);
          await t.pumpAndSettle();
          final gaps = (await t.runAsync(
            () => db.messageHistory.gaps.read(scope, [
              for (final row in w.messageDomain.messages) (row.id, row.seq),
            ]),
          ))!;
          if (!limited) expect(gaps, isEmpty);
          if (!limited) {
            expect(
              await drainIo(
                t,
                db.messageHistory.gaps.read(scope, [
                  ('chat-100', BigInt.from(100)),
                  ('chat-201', BigInt.from(201)),
                ]),
              ),
              isEmpty,
            );
          }
          expect(
            find.byKey(const ValueKey('history-gap-placeholder-chat-201')),
            findsNothing,
          );
          if (!limited) {
            expect(
              await drainIo(
                t,
                db.messageHistory.readContext(scope, 'chat-151', radius: 0),
              ),
              isNotNull,
            );
          }
          for (var i = 0; i < 6; i++) {
            await t.pump(const Duration(milliseconds: 16));
            expect(t.getRect(reading).top, closeTo(top, 1));
          }
          expect(
            client.beforeReads.toSet(),
            contains(BigInt.from(151)),
            reason: 'The second page must load automatically.',
          );
          if (!offline) {
            expect(client.beforeReads, [BigInt.from(201), BigInt.from(151)]);
          }
          if (limited) {
            expect(
              await drainIo(
                t,
                db.messageHistory.readContext(scope, 'chat-151', radius: 0),
              ),
              isNull,
            );
          }
          expect(w.error, isNull);
          if (limited) {
            expect(
              (await drainIo(
                t,
                db.messageHistory.capacity.usage(
                  HistoryAccount(w.client.origin, w.client.user!.id),
                ),
              )).hardFull,
              isTrue,
            );
          }
        } finally {
          if (!client.gate!.isCompleted) client.gate!.complete();
          await closeGapView(t, w, client, db);
        }
      },
    );
  }
}
